import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Session-level ad cadence engine with frequency caps and deduplication.
///
/// ─── Cadence ────────────────────────────────────────────────────────────────
/// Pattern [2, 3, 2, 3]: show post×2 → AD, post×3 → AD, post×2 → AD …
/// Average density: 1 ad per 2.5 posts (regular), 1 per 3 posts (first session).
///
/// ─── Frequency caps ─────────────────────────────────────────────────────────
/// Rule 1  No repeat ads — each ad ID shown at most once per feed render.
///         Tracked via [_seenAdIds]; caller passes [candidateAdId] to
///         [shouldShowAd] so the engine can skip already-seen candidates.
///
/// Rule 2  Max [maxAdsPerSession] ad slots per feed render. Heavy scrollers
///         stop seeing ads after the 5th slot regardless of post count.
///
/// Rule 3  Hard floor of [minPostsBetweenAds] posts between every two ads,
///         even when the pattern threshold is smaller (prevents boundary bursts
///         when the feed reloads mid-session).
///
/// ─── VIPeeps ────────────────────────────────────────────────────────────────
/// [shouldShowAd] returns false immediately for VIPeeps subscribers.
///
/// ─── Lifecycle ──────────────────────────────────────────────────────────────
/// Call [init] once in initState, [reset] at the top of every feed merge.
class AdCadenceService {
  /// How many posts to show before each successive ad (regular sessions).
  static const List<int> adPattern = [2, 3, 2, 3];

  /// More conservative cadence for brand-new users.
  static const List<int> firstSessionPattern = [3, 3, 3, 3];

  /// Maximum ad slots shown per feed render (Rule 2).
  static const int maxAdsPerSession = 5;

  /// Minimum posts required between any two ads (Rule 3 hard floor).
  static const int minPostsBetweenAds = 3;

  // ── Pattern state ──────────────────────────────────────────────────────────
  int _patternIndex = 0;

  /// Posts counted toward the current pattern threshold.
  int _postsSinceAd = 0;

  /// Posts since the last *shown* ad — enforces the hard floor independently
  /// of the pattern so the floor survives pattern resets (e.g. [skipSlot]).
  int _postsSinceLastAd = 0;

  bool _isFirstSession = false;
  bool _isVIPeep = false;
  List<int>? _overridePattern;

  // ── Frequency cap state ────────────────────────────────────────────────────
  final Set<String> _seenAdIds = {};
  int _adsShownThisSession = 0;

  List<int> get _activePattern =>
      _overridePattern ??
      (_isFirstSession ? firstSessionPattern : adPattern);

  // ── Public read-only probe ─────────────────────────────────────────────────

  /// True when a slot is open at the current position — pattern threshold,
  /// hard floor, session cap, and VIPeeps guard all agree an ad can appear.
  ///
  /// Safe to call repeatedly; does NOT advance any internal state.
  /// Use this in the candidate loop to distinguish "slot open but candidate
  /// already seen" from "no slot due at all".
  bool get isSlotPending {
    if (_isVIPeep) return false;
    if (_adsShownThisSession >= maxAdsPerSession) return false;
    if (_postsSinceLastAd < minPostsBetweenAds) return false;
    return _postsSinceAd >= _activePattern[_patternIndex];
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Must be awaited once when the owning screen initialises.
  ///
  /// [pattern] — optional override; pass `[3, 3, 3, 3]` for venue pages.
  Future<void> init({List<int>? pattern}) async {
    _overridePattern = pattern;
    final prefs = await SharedPreferences.getInstance();
    _isFirstSession = !(prefs.getBool('hasOpenedFeedBefore') ?? false);
    _patternIndex = 0;
    _postsSinceAd = 0;
    _postsSinceLastAd = 0;
    if (_isFirstSession) {
      await prefs.setBool('hasOpenedFeedBefore', true);
    }
    await refreshVIPeepsStatus();
  }

  /// Re-reads the user's VIPeeps flag from Firestore.
  /// Call from [didChangeDependencies] to pick up mid-session upgrades.
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

  // ── Core API ───────────────────────────────────────────────────────────────

  /// Returns true when an ad should be inserted before the current post.
  ///
  /// Evaluation order:
  ///   1. VIPeeps → false (no counters advanced)
  ///   2. Session cap → false (counters advanced — slot not reusable)
  ///   3. Hard floor → false (counters advanced)
  ///   4. Pattern threshold → false (counters advanced)
  ///   5. Seen check — if [candidateAdId] is in [_seenAdIds], returns false
  ///      WITHOUT advancing counters so the caller can retry with the next
  ///      candidate in the same post slot.
  ///   6. All pass → advance counters, mark candidate seen, return true.
  ///
  /// **Caller contract for deduplication:**
  /// ```dart
  /// for (var i = 0; i < availableAds.length; i++) {
  ///   final candidate = availableAds[(adIndex + i) % availableAds.length];
  ///   if (cadence.shouldShowAd(candidateAdId: candidate['id'])) {
  ///     // show candidate; advance adIndex by i + 1
  ///     break;
  ///   }
  ///   if (!cadence.isSlotPending) break; // pattern/cap/floor said no — stop
  ///   // else: candidate was seen — try next
  /// }
  /// if (noAdAdded && cadence.isSlotPending) cadence.skipSlot();
  /// ```
  bool shouldShowAd({String? candidateAdId}) {
    if (_isVIPeep) return false;

    if (_adsShownThisSession >= maxAdsPerSession) {
      _postsSinceAd++;
      _postsSinceLastAd++;
      return false;
    }

    if (_postsSinceLastAd < minPostsBetweenAds) {
      _postsSinceAd++;
      _postsSinceLastAd++;
      return false;
    }

    final threshold = _activePattern[_patternIndex];
    if (_postsSinceAd < threshold) {
      _postsSinceAd++;
      _postsSinceLastAd++;
      return false;
    }

    // Slot is pattern-due. Check per-session deduplication.
    if (candidateAdId != null && _seenAdIds.contains(candidateAdId)) {
      // Do NOT advance counters — slot stays open for the next candidate.
      return false;
    }

    // Commit the slot.
    _patternIndex = (_patternIndex + 1) % _activePattern.length;
    _postsSinceAd = 0;
    _postsSinceLastAd = 0;
    _adsShownThisSession++;
    if (candidateAdId != null) _seenAdIds.add(candidateAdId);
    return true;
  }

  /// Advance the pattern past a slot where every available candidate has
  /// already been seen this session (all-seen suppression).
  ///
  /// Does NOT increment [_adsShownThisSession] (no ad was shown).
  /// Does NOT reset [_postsSinceLastAd] (hard floor keeps running from the
  /// last actually-shown ad, not from skipped slots).
  void skipSlot() {
    if (!isSlotPending) return;
    _patternIndex = (_patternIndex + 1) % _activePattern.length;
    _postsSinceAd = 0;
    // _postsSinceLastAd preserved intentionally.
  }

  /// Reset all per-feed-render state. Call at the top of every merge so the
  /// cadence and frequency caps are consistent across feed refreshes.
  void reset() {
    _patternIndex = 0;
    _postsSinceAd = 0;
    _postsSinceLastAd = 0;
    _seenAdIds.clear();
    _adsShownThisSession = 0;
  }
}
