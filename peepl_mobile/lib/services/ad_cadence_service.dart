import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'debug_log_service.dart';

/// Session-level ad cadence engine with frequency caps and deduplication.
///
/// ─── Cadence ────────────────────────────────────────────────────────────────
/// Pattern [3, 2, 3]: show post×3 → AD, post×2 → AD, post×3 → AD …
/// With the min-3 hard floor, effective average ≈ 1 ad per 3.5 posts.
///
/// ─── Frequency caps ─────────────────────────────────────────────────────────
/// Rule 1  No repeat ads — each ad ID shown at most once per session.
///         Tracked via [_seenAdIds]; caller passes [candidateAdId] to
///         [shouldShowAd] so the engine can skip already-seen candidates.
///
/// Rule 2  Max [maxAdsPerSession] ad slots per session. Heavy scrollers
///         stop seeing ads after the 5th slot regardless of post count.
///
/// Rule 3  Hard floor of [minPostsBetweenAds] posts between every two ads,
///         even when the pattern threshold is smaller.
///
/// ─── VIPeeps ────────────────────────────────────────────────────────────────
/// [shouldShowAd] returns false immediately for VIPeeps subscribers.
///
/// ─── Lifecycle ──────────────────────────────────────────────────────────────
/// Call [init] once in initState, [resetForMerge] at the top of every feed
/// merge. [_seenAdIds] and [_adsShownThisSession] survive merges/rebuilds.
class AdCadenceService {
  /// How many posts to show before each successive ad (regular sessions).
  static const List<int> adPattern = [3, 2, 3];

  /// More conservative cadence for brand-new users.
  static const List<int> firstSessionPattern = [3, 3, 3, 3];

  /// Maximum ad slots shown per session (Rule 2).
  static const int maxAdsPerSession = 5;

  /// Minimum posts required between any two ads (Rule 3 hard floor).
  static const int minPostsBetweenAds = 3;

  // ── Pattern state (reset on each merge walk) ───────────────────────────────
  int _patternIndex = 0;
  int _postsSinceAd = 0;
  int _postsSinceLastAd = 0;

  bool _isFirstSession = false;
  bool _isVIPeep = false;
  List<int>? _overridePattern;

  // ── Session state (survives merge rebuilds) ────────────────────────────────
  final Set<String> _seenAdIds = {};
  int _adsShownThisSession = 0;
  bool _sessionMaxLogged = false;

  // ── Per-merge diagnostics (reset each merge walk) ──────────────────────────
  bool _mergeWalkStarted = false;
  int _mergePostCount = 0;
  int _mergeAdsInjected = 0;
  int _mergeAdsSuppressed = 0;

  List<int> get _activePattern =>
      _overridePattern ??
      (_isFirstSession ? firstSessionPattern : adPattern);

  /// True for VIPeeps subscribers — feed row ads should be suppressed entirely.
  bool get suppressesAds => _isVIPeep;

  /// True when a slot is open at the current position — pattern threshold,
  /// hard floor, session cap, and VIPeeps guard all agree an ad can appear.
  bool get isSlotPending {
    if (_isVIPeep) return false;
    if (_adsShownThisSession >= maxAdsPerSession) return false;
    if (_postsSinceLastAd < minPostsBetweenAds) return false;
    return _postsSinceAd >= _activePattern[_patternIndex];
  }

  /// Must be awaited once when the owning screen initialises.
  Future<void> init({List<int>? pattern, bool? isFirstSession}) async {
    _overridePattern = pattern;
    if (isFirstSession != null) {
      _isFirstSession = isFirstSession;
    } else {
      final prefs = await SharedPreferences.getInstance();
      _isFirstSession = !(prefs.getBool('has_seen_feed') ?? false);
    }
    _patternIndex = 0;
    _postsSinceAd = 0;
    _postsSinceLastAd = 0;
    _sessionMaxLogged = false;
    await refreshVIPeepsStatus();
  }

  /// Alias for [init] — resets all session and merge state.
  /// Prefer calling [init] directly for clarity.
  Future<void> reset() async {
    await init();
  }

  /// Sync VIP flag from the feed screen without an extra Firestore read.
  void setVipSubscriber(bool isVip) {
    _isVIPeep = isVip;
  }

  /// Re-reads the user's VIPeeps flag from Firestore.
  Future<void> refreshVIPeepsStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _isVIPeep = false;
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3')
          .doc(uid)
          .get();
      _isVIPeep = (doc.data()?['isVIPeep'] as bool?) ?? false;
    } catch (_) {
      _isVIPeep = false;
    }
  }

  void _logSuppressed(String reason, {String? adId}) {
    _mergeAdsSuppressed++;
    DebugLogService.log('ADS', 'suppressed', data: {
      'reason': reason,
      if (adId != null) 'adId': adId,
    });
  }

  void _logMergeComplete() {
    DebugLogService.log('ADS', 'merge_complete', data: {
      'postCount': _mergePostCount,
      'adsInjected': _mergeAdsInjected,
      'adsSuppressed': _mergeAdsSuppressed,
      'firstSession': _isFirstSession,
      'isVip': _isVIPeep,
    });
  }

  /// Returns true when an ad should be inserted before the current post.
  ///
  /// Precedence: VIP > session max > min-3 floor > gap pattern > dedup.
  bool shouldShowAd({String? candidateAdId}) {
    if (_isVIPeep) {
      _logSuppressed('vip', adId: candidateAdId);
      return false;
    }

    if (_adsShownThisSession >= maxAdsPerSession) {
      if (!_sessionMaxLogged) {
        _logSuppressed('session_max', adId: candidateAdId);
        _sessionMaxLogged = true;
      }
      _postsSinceAd++;
      _postsSinceLastAd++;
      return false;
    }

    final threshold = _activePattern[_patternIndex];
    final patternDue = _postsSinceAd >= threshold;

    if (_postsSinceLastAd < minPostsBetweenAds) {
      if (patternDue) {
        _logSuppressed('min_gap', adId: candidateAdId);
      }
      _postsSinceAd++;
      _postsSinceLastAd++;
      return false;
    }

    if (!patternDue) {
      _postsSinceAd++;
      _postsSinceLastAd++;
      return false;
    }

    if (candidateAdId != null && _seenAdIds.contains(candidateAdId)) {
      _logSuppressed('dedup', adId: candidateAdId);
      return false;
    }

    _patternIndex = (_patternIndex + 1) % _activePattern.length;
    _postsSinceAd = 0;
    _postsSinceLastAd = 0;
    _adsShownThisSession++;
    _mergeAdsInjected++;
    if (candidateAdId != null) _seenAdIds.add(candidateAdId);
    return true;
  }

  /// Row-based feed slots (every 3rd grid row): VIP, session cap, dedup only.
  bool tryConsumeRowAdSlot({String? candidateAdId}) {
    if (_isVIPeep) {
      _logSuppressed('vip', adId: candidateAdId);
      return false;
    }

    if (_adsShownThisSession >= maxAdsPerSession) {
      if (!_sessionMaxLogged) {
        _logSuppressed('session_max', adId: candidateAdId);
        _sessionMaxLogged = true;
      }
      return false;
    }

    if (candidateAdId != null && _seenAdIds.contains(candidateAdId)) {
      _logSuppressed('dedup', adId: candidateAdId);
      return false;
    }

    _adsShownThisSession++;
    _mergeAdsInjected++;
    if (candidateAdId != null) _seenAdIds.add(candidateAdId);
    return true;
  }

  /// Advance the pattern when every candidate for a pending slot was deduped.
  void skipSlot() {
    if (!isSlotPending) return;
    _patternIndex = (_patternIndex + 1) % _activePattern.length;
    _postsSinceAd = 0;
  }

  /// Call this immediately after the merge loop completes.
  /// Emits ADS/merge_complete for the current session to Firestore
  /// so it is readable from the Firebase console during TestFlight QA.
  void finalizeMerge() {
    if (!_mergeWalkStarted) return;
    _logMergeComplete();
    _mergeWalkStarted = false; // guard: resetForMerge() skips log when false
  }

  /// Resets merge-walk counters only. Session dedup + cap tallies survive
  /// setState/rebuild so impressions are not re-counted for the same ad IDs.
  ///
  /// [postCount] is the number of posts in the current merge walk (pass from
  /// the caller when available). Logs a summary for the previous merge walk
  /// only if [finalizeMerge] was not called (safety net).
  void resetForMerge({int postCount = 0}) {
    // Safety net: log only when prior walk started but finalizeMerge() never ran.
    if (_mergeWalkStarted) {
      _logMergeComplete();
    }
    _mergeWalkStarted = true;
    _mergePostCount = postCount;
    _mergeAdsInjected = 0;
    _mergeAdsSuppressed = 0;
    _patternIndex = 0;
    _postsSinceAd = 0;
    _postsSinceLastAd = 0;
  }
}
