import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/ad_cadence_service.dart';
import '../services/crowdsource_service.dart';
import '../services/feed_service.dart';
import '../services/geofence_service.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';
import '../utils/post_crowd_format.dart';
import 'location_detail_screen.dart';

/// Design tokens for the redesigned home screen.
class _T {
  static const blue = Color(0xFF1565C0);
  static const yellow = Color(0xFFFFC93C);

  static const ringGreen = Color(0xFF34C759);
  static const ringAmber = Color(0xFFFF9F0A);
  static const ringOrange = Color(0xFFFF6B35);
  static const ringRed = Color(0xFFFF3B30);
}

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

  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _feedItems = [];
  List<Map<String, dynamic>> _availableAds = [];

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  // Filter state
  String _activeFilter = 'Newest';

  // Area label shown under the wordmark.
  final String _areaLabel = 'Near you';

  // User position used for distance labels. Null = distance is hidden.
  double? _userLat;
  double? _userLng;

  /// Miles cutoffs for the radius-based filters.
  static const double _localRadiusMiles = 25.0;
  static const double _regionRadiusMiles = 100.0;

  final List<Map<String, String>> _deals = const [
    {'offer': '20% OFF ENTREES', 'merchant': 'Cotto Italian Grill', 'distance': '0.4 mi'},
    {'offer': 'FREE APPETIZER', 'merchant': 'NaiThai Dunwoody', 'distance': '1.2 mi'},
    {'offer': 'HAPPY HOUR 4–7PM', 'merchant': 'Lamont\'s Lounge', 'distance': '0.8 mi'},
  ];
  int _dealIndex = 0;
  Timer? _dealTimer;

  @override
  void initState() {
    super.initState();
    _cadence.init();
    _initLocation();
    _loadFeedData();
    _loadAds();
    _dealTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _dealIndex = (_dealIndex + 1) % _deals.length);
    });
  }

  @override
  void dispose() {
    _feedSub?.cancel();
    _dealTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (!mounted || pos == null) return;
    setState(() {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      _feedItems = _rebuildFeedItems();
    });
    if (!kIsWeb) {
      unawaited(_startGeofencingIfPermitted());
    }
  }

  /// Activates geofencing once location is already working. Never called on
  /// web, never called before the user has a location-dependent surface open.
  /// Failures degrade the feature silently — the feed must not be affected.
  Future<void> _startGeofencingIfPermitted() async {
    try {
      if (PeeplGeofenceService.instance.isActive) return;
      await PeeplGeofenceService.instance.start();
      if (PeeplGeofenceService.instance.isActive) {
        await PeeplGeofenceService.instance.loadGeofencesFromFirestore();
      }
    } catch (e) {
      debugPrint('[feed] geofence start skipped: $e');
    }
  }

  // ---------------------------------------------------------------- data

  void _loadFeedData() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    _feedSub?.cancel();
    _feedSub = _feedService.getLocationFeedStream().listen(
      (snapshot) => _processFeedData(snapshot.docs),
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load feed: $error';
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _loadAds() async {
    try {
      final ads = await _adsService.getAdsForFeed(
        limit: 10,
        userLat: _userLat,
        userLng: _userLng,
      );
      if (!mounted) return;
      setState(() {
        _availableAds = ads;
        _feedItems = _rebuildFeedItems();
      });
    } catch (e) {
      debugPrint('Failed to load ads: $e');
    }
  }

  void _processFeedData(List<QueryDocumentSnapshot> docs) {
    final posts = docs.map((doc) {
      return <String, dynamic>{
        'id': doc.id,
        'type': 'post',
        ...(doc.data() as Map<String, dynamic>),
      };
    }).toList();

    if (!mounted) return;
    setState(() {
      _posts = posts;
      _feedItems = _rebuildFeedItems();
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _rebuildFeedItems() {
    return _mergeAdsIntoFeed(_applyFilter(_posts));
  }

  List<Map<String, dynamic>> _mergeAdsIntoFeed(
    List<Map<String, dynamic>> posts,
  ) {
    if (_availableAds.isEmpty) {
      return List<Map<String, dynamic>>.from(posts);
    }

    _cadence.resetForMerge(postCount: posts.length);
    final items = <Map<String, dynamic>>[];
    var adIndex = 0;

    for (final post in posts) {
      var adAdded = false;
      for (var i = 0; i < _availableAds.length; i++) {
        final candidate = _availableAds[(adIndex + i) % _availableAds.length];
        if (_cadence.shouldShowAd(candidateAdId: candidate['id'] as String?)) {
          items.add(<String, dynamic>{'type': 'ad', ...candidate});
          adIndex += i + 1;
          adAdded = true;
          break;
        }
        if (!_cadence.isSlotPending) break;
      }
      if (!adAdded && _cadence.isSlotPending) _cadence.skipSlot();

      items.add(post);
    }
    _cadence.finalizeMerge();
    return items;
  }

  Future<void> _onRefresh() async {
    _loadFeedData();
    await _initLocation();
    await _loadAds();
  }

  // ------------------------------------------------------------- helpers

  Color _ringColor(int level) {
    if (level <= 3) return _T.ringGreen;
    if (level <= 6) return _T.ringAmber;
    if (level <= 8) return _T.ringOrange;
    return _T.ringRed;
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final DateTime d = (timestamp as Timestamp).toDate();
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  double _deg2rad(double deg) => deg * math.pi / 180.0;

  double _haversineMiles(double lat1, double lon1, double lat2, double lon2) {
    const double radiusMiles = 3958.8;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radiusMiles * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Returns the raw miles to a post, or null when it can't be computed.
  double? _milesTo(Map<String, dynamic> post) {
    final pre = post['distanceMiles'];
    if (pre is num) return pre.toDouble();

    final lat = post['latitude'];
    final lng = post['longitude'];
    if (_userLat == null || _userLng == null) return null;
    if (lat is! num || lng is! num) return null;

    return _haversineMiles(
      _userLat!,
      _userLng!,
      lat.toDouble(),
      lng.toDouble(),
    );
  }

  /// Applies the active filter chip to the raw post list.
  /// Posts with unknown distance are never dropped by a radius filter —
  /// they sort to the bottom instead, so a post with missing coordinates
  /// stays reachable rather than silently vanishing.
  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> posts) {
    final out = List<Map<String, dynamic>>.from(posts);

    switch (_activeFilter) {
      case 'Nearby':
        out.sort((a, b) {
          final da = _milesTo(a);
          final db = _milesTo(b);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
        return out;

      case 'Local':
        return _withinRadius(out, _localRadiusMiles);

      case 'Region':
        return _withinRadius(out, _regionRadiusMiles);

      case 'Newest':
      default:
        // Firestore already returns timestamp-descending; preserve that order.
        return out;
    }
  }

  List<Map<String, dynamic>> _withinRadius(
    List<Map<String, dynamic>> posts,
    double radiusMiles,
  ) {
    final known = <Map<String, dynamic>>[];
    final unknown = <Map<String, dynamic>>[];

    for (final post in posts) {
      final miles = _milesTo(post);
      if (miles == null) {
        unknown.add(post);
      } else if (miles <= radiusMiles) {
        known.add(post);
      }
    }

    known.sort((a, b) => _milesTo(a)!.compareTo(_milesTo(b)!));
    return [...known, ...unknown];
  }

  /// Returns null when distance is unknown. Callers must omit the separator
  /// entirely rather than rendering an em dash.
  String? _distanceLabel(Map<String, dynamic> post) {
    final miles = _milesTo(post);
    if (miles == null) return null;
    return '${miles.round()} mi';
  }

  String? _ratioLine(Map<String, dynamic> post) {
    final mf = PostCrowdFormat.maleFemaleShort(post['maleFemaleRatio']);
    final ak = PostCrowdFormat.adultKidShort(post['adultKidRatio']);

    final parts = <String>[];
    if (mf != null) parts.add('M/F  •  $mf');
    if (ak != null) parts.add('A/K  •  $ak');
    return parts.isEmpty ? null : parts.join('  •  ');
  }

  Future<void> _onAskTapped(Map<String, dynamic> post) async {
    final locationName = (post['locationName'] ?? '').toString();
    if (locationName.isEmpty) return;

    final locationId = (post['id'] ?? locationName).toString();
    final lat = (post['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (post['longitude'] as num?)?.toDouble() ?? 0.0;

    try {
      final requestId = await CrowdsourceService.instance.createRequest(
        locationId: locationId,
        locationName: locationName,
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) return;
      if (requestId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Asked everyone at $locationName to report crowd levels!',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: _T.blue,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send request. Try again.')),
      );
    }
  }

  String get _resultsLabel {
    switch (_activeFilter) {
      case 'Nearby':
        return 'Showing nearest first';
      case 'Local':
        return 'Within 25 miles';
      case 'Region':
        return 'Within 100 miles';
      case 'Newest':
      default:
        return 'Showing newest first';
    }
  }

  void _onFilterTapped(String filter) {
    if ((filter == 'Nearby' || filter == 'Local' || filter == 'Region') &&
        _userLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location needed for this filter. Enable location access to sort by distance.',
          ),
        ),
      );
      setState(() {
        _activeFilter = 'Newest';
        _feedItems = _rebuildFeedItems();
      });
      return;
    }

    setState(() {
      _activeFilter = filter;
      _feedItems = _rebuildFeedItems();
    });
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final heroMax = screenH * 0.05;
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _T.blue,
      body: Column(
        children: [
          SizedBox(
            height: heroMax + topInset,
            child: Padding(
              padding: EdgeInsets.only(top: topInset),
              child: SizedBox(
                height: heroMax,
                child: ClipRect(
                  child: _buildHero(),
                ),
              ),
            ),
          ),
          _buildActionRow(),
          _buildFilterRow(),
          _buildResultsRow(),
          Expanded(child: _buildFeedContent()),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      color: _T.blue,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 26),
              const Expanded(
                child: Center(
                  child: Text(
                    'peepl',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: 1,
                    ),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          _buildAreaSelector(),
          const SizedBox(height: 1),
          _buildDealBanner(),
        ],
      ),
    );
  }

  Widget _buildAreaSelector() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Area selector coming soon')),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(
            _areaLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 12),
        ],
      ),
    );
  }

  Widget _buildDealBanner() {
    final deal = _deals[_dealIndex];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(_dealIndex),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const Icon(Icons.star, size: 10, color: _T.yellow),
            const SizedBox(width: 4),
            Text(
              deal['offer']!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${deal['merchant']}  ·  ${deal['distance']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 9,
                ),
              ),
            ),
            Text(
              'View Deal',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _circleAction(Icons.search, 'Search', () {
            Navigator.pushNamed(context, '/search');
          }),
          _circleAction(Icons.explore_outlined, 'Explore', () {
            Navigator.pushNamed(context, '/discover');
          }),
          _peepButton(),
          _circleAction(Icons.local_offer, 'Deals', () {
            Navigator.pushNamed(context, '/deals');
          }),
          _circleAction(Icons.menu, 'Menu', () {
            Navigator.pushNamed(context, '/settings');
          }),
        ],
      ),
    );
  }

  Widget _circleAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _peepButton() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/post'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _T.yellow,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.add, color: _T.blue, size: 20),
                Text(
                  'PEEP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    const filters = <String, IconData>{
      'Newest': Icons.calendar_today,
      'Nearby': Icons.location_on_outlined,
      'Local': Icons.storefront_outlined,
      'Region': Icons.map_outlined,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: filters.entries.map((entry) {
            final isActive = _activeFilter == entry.key;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => _onFilterTapped(entry.key),
                child: SizedBox(
                  height: 28,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entry.value,
                            size: 12,
                            color: isActive ? _T.blue : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            entry.key,
                            style: TextStyle(
                              color: isActive ? _T.blue : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 12,
                              color: _T.blue,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildResultsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            _resultsLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Map view coming soon')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.map_outlined, size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Map View',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.white.withValues(alpha: 0.7)),
              const SizedBox(height: 14),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Please try again later',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFeedData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_feedItems.isEmpty) {
      return Center(
        child: Text(
          'No peeps yet. Be the first.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15),
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: _T.blue,
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        // Bottom padding clears the bottom nav bar so the last card is reachable.
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        itemCount: _feedItems.length,
        itemBuilder: (context, index) {
          final item = _feedItems[index];
          if (item['type'] == 'ad') {
            return _buildAdCard(item);
          }
          return _buildLocationCard(item);
        },
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> post) {
    final int level = (post['crowdingLevel'] is num)
        ? (post['crowdingLevel'] as num).round()
        : 0;
    final String name = (post['locationName'] ?? 'Unknown').toString();
    final String username = (post['username'] ?? '').toString();
    final String imageUrl = (post['imageUrl'] ?? '').toString();
    final String? distance = _distanceLabel(post);
    final String date = _formatDate(post['timestamp']);
    final String? ratios = _ratioLine(post);

    final metaParts = <String>[];
    if (date.isNotEmpty) metaParts.add(date);
    if (distance != null) metaParts.add(distance);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LocationDetailScreen(postData: post),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 1.5),
          image: imageUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                  onError: (_, __) {},
                )
              : null,
          color: const Color(0xFF0D47A1),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [Colors.transparent, Color(0xCC000000)],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 10,
                      ),
                    ),
                    if (metaParts.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        metaParts.join('  •  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 10,
                        ),
                      ),
                    ],
                    if (ratios != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        ratios,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _crowdRing(level),
                  const SizedBox(height: 4),
                  _askButton(post),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _crowdRing(int level) {
    final color = _ringColor(level);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          '$level',
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _askButton(Map<String, dynamic> post) {
    return GestureDetector(
      onTap: () => _onAskTapped(post),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: _T.blue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.chat_bubble_outline, size: 10, color: Colors.white),
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

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final String headline = (ad['headline'] ?? ad['title'] ?? 'Sponsored').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'SPONSORED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            headline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
