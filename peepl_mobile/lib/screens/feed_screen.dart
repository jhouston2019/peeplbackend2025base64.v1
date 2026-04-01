import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/feed_service.dart';
import '../services/native_ads_service.dart';
import '../widgets/crowd_dot_ring_meter.dart';
import 'location_detail_screen.dart';
import 'post_screen.dart';

enum _SortMode { rating, date, distance, local, region }

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FeedService _feedService = FeedService();
  final NativeAdsService _adsService = NativeAdsService();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<QuerySnapshot>? _feedSub;

  List<Map<String, dynamic>> _locationPosts = [];
  List<Map<String, dynamic>> _feedItems = [];
  List<Map<String, dynamic>> _availableAds = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  _SortMode _sortMode = _SortMode.date;
  double? _userLat;
  double? _userLng;

  static const TextStyle _overlayShadow = TextStyle(
    color: Colors.white,
    shadows: [
      Shadow(offset: Offset(0, 1), blurRadius: 6, color: Colors.black87),
    ],
  );

  @override
  void initState() {
    super.initState();
    _loadFeedData();
    _loadAds();
    _initUserLocation();
  }

  Future<void> _initUserLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled || !mounted) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          !mounted) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      final resort = _locationPosts.isNotEmpty &&
          (_sortMode == _SortMode.distance || _sortMode == _SortMode.local);
      if (resort) {
        final copy = List<Map<String, dynamic>>.from(_locationPosts);
        _sortLocationPosts(copy);
        final items = _mergeAdsIntoFeed(copy);
        setState(() {
          _locationPosts = copy;
          _feedItems = items;
        });
      } else {
        setState(() {});
      }
    } catch (_) {
      // Distance shows "—" when unavailable
    }
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
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Failed to load feed: $error';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load feed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAds() async {
    try {
      final ads = await _adsService.getAdsForFeed(limit: 10);
      if (mounted) setState(() => _availableAds = ads);
    } catch (e) {
      debugPrint('Failed to load ads: $e');
    }
  }

  List<Map<String, dynamic>> _mergeAdsIntoFeed(List<Map<String, dynamic>> posts) {
    final feedItems = <Map<String, dynamic>>[];
    var adIndex = 0;
    for (var i = 0; i < posts.length; i++) {
      feedItems.add(posts[i]);
      if ((i + 1) % 2 == 0 && adIndex < _availableAds.length) {
        feedItems.add({'type': 'ad', ..._availableAds[adIndex]});
        adIndex++;
      }
    }
    return feedItems;
  }

  void _processFeedData(List<QueryDocumentSnapshot> postDocs) {
    final posts = postDocs
        .map((doc) => <String, dynamic>{'id': doc.id, 'type': 'post', ...doc.data() as Map<String, dynamic>})
        .toList();
    _sortLocationPosts(posts);
    final feedItems = _mergeAdsIntoFeed(posts);
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
      case _SortMode.date:
        posts.sort(compareDateDescending);
      case _SortMode.distance:
        posts.sort(compareDistance);
      case _SortMode.local:
        posts.sort((a, b) {
          final c = compareDistance(a, b);
          if (c != 0) return c;
          final ca = (a['commentsCount'] as num?)?.toInt() ?? 0;
          final cb = (b['commentsCount'] as num?)?.toInt() ?? 0;
          final cc = cb.compareTo(ca);
          return cc != 0 ? cc : compareDateDescending(a, b);
        });
      case _SortMode.region:
        posts.sort((a, b) {
          final na = (a['locationName'] ?? '').toString().toLowerCase();
          final nb = (b['locationName'] ?? '').toString().toLowerCase();
          final c = na.compareTo(nb);
          return c != 0 ? c : compareDateDescending(a, b);
        });
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
            _buildAppBar(),
            _buildSortBar(),
            Expanded(child: _buildFeedContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(builder: (_) => const PostScreen()),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text('POST', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Text('Peepl', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/settings'),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.help_outline, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  "WHAT'S\nCROWDED?",
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, height: 1.1),
                  textAlign: TextAlign.center,
                ),
              ],
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
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onSortChanged(mode),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: selected ? 0 : 0.35)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFF1565C0) : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(0, 0, 16, 8),
        children: [
          pill('Rating', _SortMode.rating),
          pill('Date', _SortMode.date),
          pill('Distance', _SortMode.distance),
          pill('Local', _SortMode.local),
          pill('Region', _SortMode.region),
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
        return item['type'] == 'ad' ? _buildAdRow() : _buildLocationCard(item);
      },
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> post) {
    final crowdingLevel = _crowdLevel(post);
    final w = MediaQuery.sizeOf(context).width;
    final cardHeight = w * 0.72;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (context) => LocationDetailScreen(postData: post)),
      ),
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
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.black26,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
              ),
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
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
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
                              style: _overlayShadow.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              post['username']?.toString() ?? 'Unknown',
                              style: _overlayShadow.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_formatDate(post['timestamp'])} · ${_formatDistance(post)}',
                              style: _overlayShadow.copyWith(fontSize: 13, color: Colors.white.withValues(alpha: 0.95)),
                            ),
                          ],
                        ),
                      ),
                      CrowdDotRingMeter(level: crowdingLevel, size: 78),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdRow() {
    return Container(
      width: double.infinity,
      height: 72,
      color: const Color(0xFFE3F2FD),
      alignment: Alignment.center,
      child: const Text(
        'ADVERTISEMENT',
        style: TextStyle(color: Color(0xFF1976D2), fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  void dispose() {
    _feedSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}
