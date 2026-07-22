import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../services/ad_cadence_service.dart';
import '../services/feed_service.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';
import '../services/presence_service.dart';
import '../utils/post_crowd_format.dart';
import '../widgets/crowd_meter.dart';

enum _SortMode { rating, date, distance, local, region }

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
  bool _cadenceReady = false;

  _SortMode _sortMode = _SortMode.date;
  double? _userLat;
  double? _userLng;

  /// Current ad context — updated to 'travel' when vicarious peepling is
  /// detected. Changes trigger a targeted ad reload via [_reloadAds].
  String _adContext = 'feed';

  static const TextStyle _overlayShadow = TextStyle(
    color: Colors.white,
    shadows: [
      Shadow(offset: Offset(0, 1), blurRadius: 6, color: Colors.black87),
    ],
  );

  static const Color _kPostCtaTeal = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    _loadFeedData();
    _initAds();
    _initUserLocation();
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
    await _cadence.init();
    if (mounted) setState(() => _cadenceReady = true);
    // Pre-warm the location cache alongside cadence init. LocationService
    // deduplicates the Geolocator call if _initUserLocation already fired it.
    final pos = await LocationService.getCurrentLocation();
    if (pos != null) {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
    }
    await _reloadAds();
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
    _cadence.reset();
    final items = <Map<String, dynamic>>[];
    var adIndex = 0;

    for (final post in posts) {
      if (_availableAds.isNotEmpty) {
        bool adAdded = false;
        // Cycle through candidates to find the first unseen one the cadence
        // approves. shouldShowAd advances counters when the slot is not yet
        // due; it skips counter advancement when a slot IS due but the
        // candidate was already seen, keeping the slot open for the next try.
        for (var i = 0; i < _availableAds.length; i++) {
          final candidate = _availableAds[(adIndex + i) % _availableAds.length];
          if (_cadence.shouldShowAd(candidateAdId: candidate['id'] as String?)) {
            items.add({'type': 'ad', ...candidate});
            adIndex += i + 1;
            adAdded = true;
            break;
          }
          // If the slot is no longer pending (cap / floor / pattern declined),
          // no point trying further candidates for this post position.
          if (!_cadence.isSlotPending) break;
        }
        // Slot was due but every candidate had already been seen — advance
        // the pattern cleanly without counting an impression.
        if (!adAdded && _cadence.isSlotPending) _cadence.skipSlot();
      }

      items.add(post);
    }
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

    final feedItems = _cadenceReady ? _mergeAdsIntoFeed(posts) : posts;
    if (mounted) {
      setState(() {
        _locationPosts = posts;
        _feedItems = feedItems;
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            _buildDealsPill(),
            _buildSortBar(),
            Expanded(child: _buildFeedContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? bgColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor ?? Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centered logo — Syne 800 to match updated brand font
          Text(
            'peepl',
            style: GoogleFonts.syne(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          // Left side: POST + SEARCH flush together
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              _buildHeaderButton(
                icon: Icons.add,
                label: 'POST',
                onTap: () => Navigator.pushNamed(context, '/post'),
              ),
              const SizedBox(width: 10),
              _buildHeaderButton(
                icon: Icons.search,
                label: 'SEARCH',
                onTap: () => Navigator.pushNamed(context, '/search'),
              ),
              const SizedBox(width: 8),
              _buildHeaderIconButton(
                icon: Icons.whatshot,
                onTap: () => Navigator.pushNamed(context, '/heat_map'),
              ),
              const SizedBox(width: 6),
              _buildHeaderIconButton(
                icon: Icons.map,
                onTap: () => Navigator.pushNamed(context, '/map'),
              ),
            ],
          ),
          // Right side: DEALS + MENU
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: [
              _buildHeaderButton(
                icon: Icons.local_offer,
                label: 'DEALS',
                onTap: () => Navigator.pushNamed(context, '/deals'),
                bgColor: const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 10),
              _buildHeaderButton(
                icon: Icons.menu,
                label: 'MENU',
                onTap: () => Navigator.pushNamed(context, '/menu'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDealsPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/deals'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '3 deals near you',
                style: TextStyle(
                  color: Color(0xFF2E7D32),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Color(0xFF2E7D32), size: 16),
            ],
          ),
        ),
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

    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: _feedItems.length,
      separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0x33FFFFFF)),
      itemBuilder: (context, index) {
        final item = _feedItems[index];
        return item['type'] == 'ad' ? _buildAdCard(item) : _buildLocationCard(item);
      },
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> post) {
    final crowdingLevel = _crowdLevel(post);
    final w = MediaQuery.sizeOf(context).width;
    final cardHeight = w * 0.19;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/peep_detail', arguments: post),
      child: SizedBox(
        width: double.infinity,
        height: cardHeight,
        child: Stack(
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
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0, 0.35, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post['locationName']?.toString() ?? 'Unknown',
                              style: _overlayShadow.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              post['username']?.toString() ?? 'Unknown',
                              style: _overlayShadow.copyWith(fontSize: 9, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDate(post['timestamp'])} · ${_formatDistance(post)}',
                              style: _overlayShadow.copyWith(fontSize: 8, color: Colors.white.withValues(alpha: 0.95)),
                            ),
                            if (_overlayCrowdDetailLine(post).isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                _overlayCrowdDetailLine(post),
                                style: _overlayShadow.copyWith(
                                  fontSize: 7,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      CrowdMeter(level: crowdingLevel, size: 60),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              'Ask',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
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
    final adId = ad['id'] as String? ?? '';
    if (adId.isEmpty) return const SizedBox.shrink();

    final headline = ad['headline'] as String? ?? '';
    final bodyText =
        ad['bodyText'] as String? ?? ad['subline'] as String? ?? '';
    if (headline.isEmpty && bodyText.isEmpty) {
      return const SizedBox.shrink();
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final cardHeight = MediaQuery.sizeOf(context).width * 0.19;

    return _FeedNativeAdCard(
      ad: ad,
      height: cardHeight,
      onImpression: () => _adsService.recordAdImpression(adId, uid),
      onCtaTap: () async {
        await _adsService.recordAdClick(adId, uid);
        final ctaUrl = ad['ctaUrl'] as String? ?? '';
        if (ctaUrl.isEmpty) return;
        final uri = Uri.tryParse(ctaUrl);
        if (uri == null) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitDeps) return;
    _didInitDeps = true;
    // Re-check VIPeeps status once after the first dependency resolution so a
    // user who just subscribed stops seeing ads without needing to restart.
    _cadence.refreshVIPeepsStatus().then((_) {
      if (mounted && _locationPosts.isNotEmpty) {
        setState(() => _feedItems = _mergeAdsIntoFeed(_locationPosts));
      }
    });
  }

  @override
  void dispose() {
    _feedSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}

class _FeedNativeAdCard extends StatefulWidget {
  const _FeedNativeAdCard({
    required this.ad,
    required this.height,
    required this.onImpression,
    required this.onCtaTap,
  });

  final Map<String, dynamic> ad;
  final double height;
  final VoidCallback onImpression;
  final Future<void> Function() onCtaTap;

  @override
  State<_FeedNativeAdCard> createState() => _FeedNativeAdCardState();
}

class _FeedNativeAdCardState extends State<_FeedNativeAdCard> {
  bool _impressionFired = false;

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.ad['imageUrl'] as String? ?? '';
    final advertiserName = widget.ad['advertiserName'] as String? ?? '';
    final headline = widget.ad['headline'] as String? ?? '';
    final bodyText =
        widget.ad['bodyText'] as String? ?? widget.ad['subline'] as String? ?? '';
    final ctaText = widget.ad['ctaText'] as String? ?? 'Learn More';
    final adId = widget.ad['id'] as String? ?? 'ad';
    final imageSize = math.min(80.0, widget.height - 16);

    return VisibilityDetector(
      key: Key('feed_native_ad_$adId'),
      onVisibilityChanged: (info) {
        if (!_impressionFired && info.visibleFraction >= 0.5 && mounted) {
          _impressionFired = true;
          widget.onImpression();
        }
      },
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: Material(
          color: Colors.white,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: imageSize,
                        height: imageSize,
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    ColoredBox(
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.campaign_outlined,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : ColoredBox(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.campaign_outlined,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (advertiserName.isNotEmpty)
                            Text(
                              advertiserName,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (advertiserName.isNotEmpty) const SizedBox(height: 2),
                          Text(
                            headline,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (bodyText.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              bodyText,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => widget.onCtaTap(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        ctaText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 8,
                child: Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
