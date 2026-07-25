import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ad_cadence_service.dart';
import '../services/debug_log_service.dart';
import '../services/feed_service.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';
import '../services/presence_service.dart';
import '../utils/post_crowd_format.dart';
import '../widgets/crowd_meter.dart';

enum _SortMode { rating, date, distance, local, region }

/// Matches the users-collection key used across settings/profile/VIP screens.
const _kUsersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FeedService _feedService = FeedService();
  final NativeAdsService _adsService = NativeAdsService();
  final AdCadenceService _cadence = AdCadenceService();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<QuerySnapshot>? _feedSub;
  bool _didInitDeps = false;

  List<Map<String, dynamic>> _locationPosts = [];
  List<Map<String, dynamic>> _feedItems = [];
  List<Map<String, dynamic>> _availableAds = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _adsReady = false;

  _SortMode _sortMode = _SortMode.date;
  double? _userLat;
  double? _userLng;

  /// Current ad context — updated to 'travel' when vicarious peepling is
  /// detected. Changes trigger a targeted ad reload via [_reloadAds].
  String _adContext = 'feed';

  Timer? _dealsTimer;
  int _dealIndex = 0;
  // DUMMY DATA — placeholder until live merchant deals are wired.
  // TODO: replace with a Firestore query sorted by proximity, capped at 5
  // entries. Index 0 must be a computed count ('N deals near you') derived
  // from the actual result length, not a hardcoded string.
  List<String> _dealMessages = [
    '3 deals near you',
    '20% off entrees — Cotto, Gainesville · 0.4 mi',
    'Happy hour til 7pm — NaiThai Dunwoody · 2.8 mi',
    'Free appetizer with 2 entrees — Johnson Ferry Rd · 0.9 mi',
    'Kids eat free Tuesdays — 434 High St SW · 39 mi',
    '\$5 draft pints all night — Brookhaven · 1.1 mi',
    'Half-price bottles Wednesdays — Foundry Grill',
    'Early bird 15% off before 5pm — Hidden Branches · 2.8 mi',
  ];

  final Set<String> _recordedImpressions = {};

  /// VIPeeps subscribers see zero ads.
  bool _isVip = false;

  bool _isFirstSession = false;

  static final List<Shadow> _textShadow = [
    Shadow(
      offset: const Offset(0, 1),
      blurRadius: 3,
      color: Colors.black.withOpacity(0.7),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadFeedData();
    _initAds();
    _initUserLocation();
    _dealsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _dealIndex = (_dealIndex + 1) % _dealMessages.length);
    });
  }

  Future<void> _initUserLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (pos == null || !mounted) return;

    _userLat = pos.latitude;
    _userLng = pos.longitude;

    // Detect vicarious peepling now that we have the user's position.
    // If the feed content is far away (>80 km), switch to travel ads.
    final newContext = _computeAdContext(_locationPosts);
    if (newContext != _adContext) {
      _adContext = newContext;
      _reloadAds();
    }

    // Re-sort distance-based modes and rebuild the distance display.
    final resort = _locationPosts.isNotEmpty &&
        (_sortMode == _SortMode.distance || _sortMode == _SortMode.local);
    if (resort) {
      final copy = List<Map<String, dynamic>>.from(_locationPosts);
      _sortLocationPosts(copy);
      final items = _mergeAdsIntoFeed(copy);
      if (mounted) {
        setState(() {
          _locationPosts = copy;
          _feedItems = items;
        });
      }
    } else if (mounted) {
      setState(() {}); // refresh distance labels
    }
  }

  bool _isNetworkError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('network') ||
        msg.contains('unavailable') ||
        msg.contains('failed-precondition');
  }

  Future<void> _loadFeedData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
      await _feedSub?.cancel();
      _feedSub = _feedService.getLocationFeedStream().listen(
        (snapshot) => _processFeedData(snapshot.docs),
        onError: (error) {
          if (!mounted) return;
          if (_isNetworkError(error)) {
            Navigator.pushNamed(context, '/no_connection')
                .then((_) { if (mounted) _loadFeedData(); });
            return;
          }
          setState(() {
            _hasError = true;
            _errorMessage = 'Failed to load feed: $error';
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      if (_isNetworkError(e)) {
        Navigator.pushNamed(context, '/no_connection')
            .then((_) { if (mounted) _loadFeedData(); });
        return;
      }
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load feed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _initAds() async {
    await _loadSessionAndVipFlags();
    DebugLogService.log('ADS', 'vip_check', data: {'isVIPeep': _isVip});
    await _cadence.init(isFirstSession: _isFirstSession);
    _cadence.setVipSubscriber(_isVip);
    if (mounted) setState(() => _adsReady = true);
    // Pre-warm the location cache alongside cadence init. LocationService
    // deduplicates the Geolocator call if _initUserLocation already fired it.
    final pos = await LocationService.getCurrentLocation();
    if (pos != null) {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
    }
    await _reloadAds();
  }

  Future<void> _loadSessionAndVipFlags() async {
    final prefs = await SharedPreferences.getInstance();
    _isFirstSession = !(prefs.getBool('has_seen_feed') ?? false);
    await _loadVipStatus();
  }

  Future<void> _loadVipStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _isVip = false;
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_kUsersCollection)
          .doc(uid)
          .get();
      _isVip = (doc.data()?['isVIPeep'] as bool?) ?? false;
    } catch (_) {
      _isVip = false;
    }
  }

  Future<void> _markFeedSeen() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('has_seen_feed') ?? false) return;
    await prefs.setBool('has_seen_feed', true);
  }

  /// Fetches ads for the current [_adContext] + user coordinates and rebuilds
  /// the feed. Safe to call any time context or location changes.
  Future<void> _reloadAds() async {
    try {
      final ads = await _adsService.getAdsForFeed(
        context: _adContext,
        userLat: _userLat,
        userLng: _userLng,
        limit: 10,
      );
      DebugLogService.log('ADS', 'fetched', data: {'count': ads.length});
      if (mounted) {
        setState(() {
          _availableAds = ads;
          if (_locationPosts.isNotEmpty) {
            _feedItems = _mergeAdsIntoFeed(_locationPosts);
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load ads: $e');
    }
  }

  /// Inspects the first geotagged post to decide if the user is vicariously
  /// peepling (browsing venues >80 km away). Returns 'travel' or 'feed'.
  String _computeAdContext(List<Map<String, dynamic>> posts) {
    if (_userLat == null || _userLng == null) return 'feed';
    for (final post in posts) {
      final lat = (post['latitude'] as num?)?.toDouble();
      final lng = (post['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;
      return NativeAdsService.detectVicariousPeepling(
        userLat: _userLat!,
        userLng: _userLng!,
        venueLat: lat,
        venueLng: lng,
      )
          ? 'travel'
          : 'feed';
    }
    return 'feed';
  }

  List<Map<String, dynamic>> _mergeAdsIntoFeed(List<Map<String, dynamic>> posts) {
    if (_isVip) {
      DebugLogService.log('ADS', 'suppressed', data: {'reason': 'vip'});
      return List<Map<String, dynamic>>.from(posts);
    }
    if (_availableAds.isEmpty) {
      return List<Map<String, dynamic>>.from(posts);
    }

    // Precedence: VIP suppression > session max of 5 > min-3-post floor >
    // gap pattern [2,3,2,3] (first session [3,3,3,3]) > per-session dedup.
    _cadence.resetForMerge(postCount: posts.length);
    final items = <Map<String, dynamic>>[];
    var adIndex = 0;

    for (final post in posts) {
      if (_availableAds.isNotEmpty) {
        var adAdded = false;
        for (var i = 0; i < _availableAds.length; i++) {
          final candidate =
              _availableAds[(adIndex + i) % _availableAds.length];
          if (_cadence.shouldShowAd(candidateAdId: candidate['id'] as String?)) {
            items.add({'type': 'ad', ...candidate});
            DebugLogService.log('ADS', 'injected', data: {
              'feedIndex': items.length - 1,
              'adId': candidate['id']?.toString(),
            });
            adIndex += i + 1;
            adAdded = true;
            break;
          }
          if (!_cadence.isSlotPending) break;
        }
        if (!adAdded && _cadence.isSlotPending) _cadence.skipSlot();
      }

      items.add(post);
    }
    _cadence.finalizeMerge();
    return items;
  }

  void _processFeedData(List<QueryDocumentSnapshot> postDocs) {
    final posts = postDocs
        .map((doc) => <String, dynamic>{'id': doc.id, 'type': 'post', ...doc.data() as Map<String, dynamic>})
        .where((post) {
          final raw = post['imageUrl'];
          if (raw == null) return false;
          final s = raw.toString().trim();
          if (s.isEmpty) return false;
          final lower = s.toLowerCase();
          if (lower.contains('mock_image_path')) return false;
          if (lower.contains('placeholder')) return false;
          return true;
        })
        .toList();
    _sortLocationPosts(posts);

    // Recompute ad context whenever the post list changes.
    final newContext = _computeAdContext(posts);
    if (newContext != _adContext) {
      _adContext = newContext;
      _reloadAds(); // async — will rebuild feed when ads arrive
    }

    final feedItems = _adsReady ? _mergeAdsIntoFeed(posts) : posts;
    if (mounted) {
      setState(() {
        _locationPosts = posts;
        _feedItems = feedItems;
        _isLoading = false;
      });
      _markFeedSeen();
    }
  }

  void _sortLocationPosts(List<Map<String, dynamic>> posts) {
    int compareDateDescending(Map<String, dynamic> a, Map<String, dynamic> b) {
      final ta = _timestampMs(a['timestamp']);
      final tb = _timestampMs(b['timestamp']);
      return tb.compareTo(ta);
    }

    int compareDistance(Map<String, dynamic> a, Map<String, dynamic> b) {
      final da = _distanceMeters(a);
      final db = _distanceMeters(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    }

    switch (_sortMode) {
      case _SortMode.rating:
        posts.sort((a, b) {
          final la = (a['likesCount'] as num?)?.toInt() ?? 0;
          final lb = (b['likesCount'] as num?)?.toInt() ?? 0;
          final c = lb.compareTo(la);
          return c != 0 ? c : compareDateDescending(a, b);
        });
        break;
      case _SortMode.date:
        posts.sort(compareDateDescending);
        break;
      case _SortMode.distance:
        posts.sort(compareDistance);
        break;
      case _SortMode.local:
        posts.sort((a, b) {
          final c = compareDistance(a, b);
          if (c != 0) return c;
          final ca = (a['commentsCount'] as num?)?.toInt() ?? 0;
          final cb = (b['commentsCount'] as num?)?.toInt() ?? 0;
          final cc = cb.compareTo(ca);
          return cc != 0 ? cc : compareDateDescending(a, b);
        });
        break;
      case _SortMode.region:
        posts.sort((a, b) {
          final na = (a['locationName'] ?? '').toString().toLowerCase();
          final nb = (b['locationName'] ?? '').toString().toLowerCase();
          final c = na.compareTo(nb);
          return c != 0 ? c : compareDateDescending(a, b);
        });
        break;
    }
  }

  void _onSortChanged(_SortMode mode) {
    if (_sortMode == mode) return;
    final copy = List<Map<String, dynamic>>.from(_locationPosts);
    _sortMode = mode;
    _sortLocationPosts(copy);
    final feedItems = _mergeAdsIntoFeed(copy);
    setState(() {
      _locationPosts = copy;
      _feedItems = feedItems;
    });
  }

  static int _timestampMs(dynamic ts) {
    if (ts is Timestamp) return ts.millisecondsSinceEpoch;
    if (ts is DateTime) return ts.millisecondsSinceEpoch;
    return 0;
  }

  double? _distanceMeters(Map<String, dynamic> post) {
    if (_userLat == null || _userLng == null) return null;
    final lat = (post['latitude'] as num?)?.toDouble();
    final lng = (post['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    if (lat == 0 && lng == 0) return null;
    return _haversineMeters(_userLat!, _userLng!, lat, lng);
  }

  static double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  String _formatDistance(Map<String, dynamic> post) {
    final m = _distanceMeters(post);
    if (m == null) return '—';
    final mi = m * 0.000621371;
    if (mi < 0.1) {
      final ft = (m * 3.28084).round();
      return '$ft ft';
    }
    if (mi < 10) return '${mi.toStringAsFixed(1)} mi';
    return '${mi.round()} mi';
  }

  String _overlayCrowdDetailLine(Map<String, dynamic> post) {
    final parts = <String>[];
    final mf = PostCrowdFormat.maleFemaleLine(post['maleFemaleRatio']);
    if (mf != null) parts.add(mf);
    final ak = PostCrowdFormat.adultKidLine(post['adultKidRatio']);
    if (ak != null) parts.add(ak);
    final age = post['ageRange']?.toString().trim();
    if (age != null && age.isNotEmpty) parts.add(age);
    return parts.join(' · ');
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.month}/${d.day}/${d.year}';
    }
    if (ts is DateTime) {
      return '${ts.month}/${ts.day}/${ts.year}';
    }
    return '—';
  }

  int _crowdLevel(Map<String, dynamic> post) {
    return (post['crowdingLevel'] as num?)?.toInt() ?? 0;
  }

  void _onSearchTapped() {
    Navigator.pushNamed(context, '/search');
  }

  void _onPeepTapped() {
    Navigator.pushNamed(context, '/post');
  }

  void _onMenuTapped() {
    Navigator.pushNamed(context, '/menu');
  }

  void _onDealsTapped() {
    Navigator.pushNamed(context, '/deals');
  }

  void _onExploreTapped() {
    // TODO: wire to onCrowdsourceRequest Cloud Function
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ask others to peep a spot — coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            _buildHeader(),
            _buildSortBar(),
            Expanded(child: _buildFeedContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // No horizontal padding on this Column — ticker must be edge-to-edge.
    // Wordmark and action bar pad themselves.
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8, left: 16, right: 16),
          child: Center(
            child: Text(
              'peepl',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
        _buildDealsTicker(),
        _buildActionBar(),
      ],
    );
  }

  Widget _buildDealsTicker() {
    return GestureDetector(
      onTap: _onDealsTapped,
      child: Container(
        width: double.infinity,
        height: 34,
        color: const Color(0xFFE8F5E9),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 12),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.6),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Text(
                  _dealMessages[_dealIndex],
                  key: ValueKey<int>(_dealIndex),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1B5E20),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF2E7D32)),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildActionButton(
            icon: Icons.search,
            label: 'SEARCH',
            bgColor: Colors.white.withOpacity(0.2),
            iconColor: Colors.white,
            onTap: _onSearchTapped,
          ),
          const SizedBox(width: 14),
          _buildActionButton(
            icon: Icons.campaign_outlined,
            label: 'EXPLORE',
            bgColor: const Color(0xFFD1C4E9),
            iconColor: const Color(0xFF4527A0),
            onTap: _onExploreTapped,
          ),
          const SizedBox(width: 14),
          _buildActionButton(
            icon: Icons.add,
            label: 'PEEP',
            bgColor: const Color(0xFFFFF59D),
            iconColor: const Color(0xFF5D4037),
            isPrimary: true,
            onTap: _onPeepTapped,
          ),
          const SizedBox(width: 14),
          _buildActionButton(
            icon: Icons.local_offer,
            label: 'DEALS',
            bgColor: const Color(0xFF43A047),
            iconColor: Colors.white,
            onTap: _onDealsTapped,
          ),
          const SizedBox(width: 14),
          _buildActionButton(
            icon: Icons.menu,
            label: 'MENU',
            bgColor: Colors.white.withOpacity(0.2),
            iconColor: Colors.white,
            onTap: _onMenuTapped,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final double size = isPrimary ? 56 : 44;
    final double iconSize = isPrimary ? 30 : 22;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    Widget pill(String label, _SortMode mode) {
      final selected = _sortMode == mode;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onSortChanged(mode),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: selected ? 0 : 0.35)),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? const Color(0xFF1565C0) : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: pill('Rating', _SortMode.rating)),
          Expanded(child: pill('Date', _SortMode.date)),
          Expanded(child: pill('Distance', _SortMode.distance)),
          Expanded(child: pill('Local', _SortMode.local)),
          Expanded(child: pill('Region', _SortMode.region)),
        ],
      ),
    );
  }

  Widget _buildFeedContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)));
    }
    if (_hasError) {
      return Center(child: Text(_errorMessage ?? 'Something went wrong', style: const TextStyle(color: Colors.white)));
    }
    if (_feedItems.isEmpty) {
      return const Center(child: Text('No posts yet!', style: TextStyle(color: Colors.white, fontSize: 18)));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: _feedItems.length,
      itemBuilder: (context, index) {
        final item = _feedItems[index];
        if (item['type'] == 'ad') {
          final adId = item['id']?.toString();
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (adId != null &&
              uid != null &&
              !_recordedImpressions.contains(adId)) {
            _recordedImpressions.add(adId);
            DebugLogService.log('ADS', 'impression', data: {'adId': adId});
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _adsService.recordAdImpression(adId, uid);
            });
          }
          return _buildAdCard(item);
        }
        return _buildLocationCard(item);
      },
    );
  }

  Widget _buildCrowdRing(int crowdingLevel) {
    final value = CrowdMeter.clampLevel(crowdingLevel);
    final color = CrowdMeter.levelColor(value);
    final label = CrowdMeter.wordLabel(value);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(44),
                painter: _FeedCrowdRingPainter(
                  progress: value / 10,
                  fillColor: color,
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  height: 1,
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Colors.black,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> post) {
    final crowdingLevel = _crowdLevel(post);
    final w = MediaQuery.sizeOf(context).width;
    final cardHeight = w * 0.19;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/peep_detail', arguments: post),
      child: Container(
        width: double.infinity,
        height: cardHeight,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white, width: 2)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Image.network(
              post['imageUrl']?.toString() ?? 'https://via.placeholder.com/400x400',
              fit: BoxFit.cover,
              width: double.infinity,
              height: cardHeight,
              errorBuilder: (context, error, stackTrace) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _feedItems.removeWhere((item) => item['imageUrl'] == post['imageUrl']);
                    });
                  }
                });
                return const SizedBox();
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.75),
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.10),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 68, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post['locationName']?.toString() ?? 'Unknown',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      shadows: _textShadow,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    post['username']?.toString() ?? 'Unknown',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      shadows: _textShadow,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(post['timestamp'])} · ${_formatDistance(post)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                      shadows: _textShadow,
                    ),
                  ),
                  if (_overlayCrowdDetailLine(post).isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      _overlayCrowdDetailLine(post),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        height: 1.2,
                        shadows: _textShadow,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 12,
              child: _buildCrowdRing(crowdingLevel),
            ),
            Positioned(
              right: 12,
              bottom: 8,
              child: _buildAskButton(post),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAskButton(Map<String, dynamic> post) {
    final locationName = post['locationName'] as String? ?? '';
    final lat = (post['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (post['longitude'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: () => _sendAskRequest(
        context: context,
        locationName: locationName,
        latitude: lat,
        longitude: lng,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, color: Colors.white, size: 11),
            SizedBox(width: 4),
            Text(
              'Ask',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendAskRequest({
    required BuildContext context,
    required String locationName,
    required double latitude,
    required double longitude,
  }) async {
    if (locationName.isEmpty) return;
    try {
      await PresenceService.instance.sendCrowdsourceRequest(
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Asked everyone at $locationName to report crowd levels!',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFF1565C0),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send request. Try again.')),
        );
      }
    }
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    return GestureDetector(
      onTap: () {
        final adId = ad['id']?.toString();
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (adId != null && uid != null) {
          DebugLogService.log('ADS', 'click', data: {'adId': adId});
          _adsService.recordAdClick(adId, uid);
        }
        // TODO: launch ad['destinationUrl'] via url_launcher
      },
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: const BoxDecoration(
          color: Color(0xFF0D47A1),
          border: Border(bottom: BorderSide(color: Colors.white, width: 2)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if ((ad['imageUrl'] ?? '').toString().isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  ad['imageUrl'],
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) =>
                      Container(color: const Color(0xFF0D47A1)),
                ),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.75),
                      Colors.black.withOpacity(0.35),
                      Colors.black.withOpacity(0.10),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'SPONSORED',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 34,
              right: 100,
              child: Text(
                ad['title'] ?? ad['headline'] ?? 'Advertisement',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 14,
              right: 100,
              child: Text(
                ad['body'] ?? ad['subtitle'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 3,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Learn More',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitDeps) return;
    _didInitDeps = true;
    // Re-check VIPeeps status once after the first dependency resolution so a
    // user who just subscribed stops seeing ads without needing to restart.
    _loadVipStatus().then((_) {
      _cadence.setVipSubscriber(_isVip);
      if (mounted && _locationPosts.isNotEmpty) {
        setState(() => _feedItems = _mergeAdsIntoFeed(_locationPosts));
      }
    });
  }

  @override
  void dispose() {
    _dealsTimer?.cancel();
    _feedSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}

class _FeedCrowdRingPainter extends CustomPainter {
  _FeedCrowdRingPainter({
    required this.progress,
    required this.fillColor,
  });

  final double progress;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 4.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    const startAngle = -math.pi / 2;
    const fullSweep = 2 * math.pi;

    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, startAngle, fullSweep, false, backgroundPaint);

    if (progress > 0) {
      canvas.drawArc(
        arcRect,
        startAngle,
        fullSweep * progress.clamp(0.0, 1.0),
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FeedCrowdRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.fillColor != fillColor;
  }
}
