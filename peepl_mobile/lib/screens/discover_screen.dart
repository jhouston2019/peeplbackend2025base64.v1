import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/ad_cadence_service.dart';
import '../services/feed_service.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';
import '../widgets/ad_card.dart';
import 'location_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final FeedService _feedService = FeedService();
  final NativeAdsService _adsService = NativeAdsService();
  final AdCadenceService _cadence = AdCadenceService();

  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _availableAds = [];
  List<Map<String, dynamic>> _feedItems = [];
  bool _isLoading = true;

  double? _userLat;
  double? _userLng;
  String _adContext = 'discover';

  @override
  void initState() {
    super.initState();
    _initAds();
    _feedService.getLocationFeedStream().listen((snapshot) {
      final posts = snapshot.docs
          .map((doc) => <String, dynamic>{
                'id': doc.id,
                'type': 'post',
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
      if (!mounted) return;

      final newContext = _computeAdContext(posts);
      if (newContext != _adContext) {
        _adContext = newContext;
        _reloadAds();
      }

      setState(() {
        _posts = posts;
        _feedItems = _mergeAdsIntoFeed(posts);
        _isLoading = false;
      });
    });
  }

  Future<void> _initAds() async {
    await _cadence.init();
    final pos = await LocationService.getCurrentLocation();
    if (pos != null) {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
    }
    await _reloadAds();
  }

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
          if (_posts.isNotEmpty) {
            _feedItems = _mergeAdsIntoFeed(_posts);
          }
        });
      }
    } catch (e) {
      debugPrint('Discover: failed to load ads: $e');
    }
  }

  String _computeAdContext(List<Map<String, dynamic>> posts) {
    if (_userLat == null || _userLng == null) return 'discover';
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
          : 'discover';
    }
    return 'discover';
  }

  List<Map<String, dynamic>> _mergeAdsIntoFeed(List<Map<String, dynamic>> posts) {
    _cadence.reset();
    final items = <Map<String, dynamic>>[];
    var adIndex = 0;

    for (final post in posts) {
      if (_availableAds.isNotEmpty) {
        bool adAdded = false;
        for (var i = 0; i < _availableAds.length; i++) {
          final candidate = _availableAds[(adIndex + i) % _availableAds.length];
          if (_cadence.shouldShowAd(candidateAdId: candidate['id'] as String?)) {
            items.add({'type': 'ad', ...candidate});
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
    return items;
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final adId = ad['id'] as String? ?? '';
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdCard(
        ad: ad,
        onImpression: () => _adsService.recordAdImpression(adId, uid),
        onTap: () => _adsService.recordAdClick(adId, uid),
      ),
    );
  }

  Color _getCrowdingColor(int level) {
    if (level <= 4) return const Color(0xFF4CAF50);
    if (level <= 6) return const Color(0xFFFFA726);
    return const Color(0xFFFF5722);
  }

  Widget _buildLocationCard(Map<String, dynamic> post) {
    final crowdingLevel = (post['crowdingLevel'] ?? 0) as int;
    final locationName = post['locationName'] as String? ?? 'Unknown Location';
    final username = post['username'] as String? ?? 'Unknown User';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => LocationDetailScreen(postData: post),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: NetworkImage(
              post['imageUrl'] as String? ?? 'https://via.placeholder.com/400x120',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.6),
                Colors.transparent,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 10,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locationName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      username,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getCrowdingColor(crowdingLevel),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      crowdingLevel.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cadence.refreshVIPeepsStatus().then((_) {
      if (mounted && _posts.isNotEmpty) {
        setState(() => _feedItems = _mergeAdsIntoFeed(_posts));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Row(
                children: [
                  Icon(Icons.explore, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Discover',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : _feedItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No posts yet',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _feedItems.length,
                          itemBuilder: (context, index) {
                            final item = _feedItems[index];
                            return item['type'] == 'ad'
                                ? _buildAdCard(item)
                                : _buildLocationCard(item);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
