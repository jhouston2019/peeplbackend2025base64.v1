import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  // ── Default feed state ────────────────────────────────────────────────────────
  StreamSubscription<QuerySnapshot>? _feedSub;
  bool _didInitDeps = false;

  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _availableAds = [];
  List<Map<String, dynamic>> _feedItems = [];
  bool _isLoading = true;
  String _adContext = 'discover';
  double? _userLat;
  double? _userLng;

  // ── Search state ──────────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  String _searchTerm = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _searchLoading = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initAds();
    });
    _feedSub = _feedService.getLocationFeedStream().listen((snapshot) {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitDeps) return;
    _didInitDeps = true;
    _cadence.refreshVIPeepsStatus().then((_) {
      if (mounted && _posts.isNotEmpty) {
        setState(() => _feedItems = _mergeAdsIntoFeed(_posts));
      }
    });
  }

  @override
  void dispose() {
    _feedSub?.cancel();
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Search logic ──────────────────────────────────────────────────────────────
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final term = value.trim();
    setState(() => _searchTerm = term);
    if (term.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 420), () => _doSearch(term));
  }

  Future<void> _doSearch(String term) async {
    setState(() => _searchLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('location_posts')
          .where('locationName', isGreaterThanOrEqualTo: term)
          .where('locationName', isLessThanOrEqualTo: '$term\uf8ff')
          .orderBy('locationName')
          .limit(30)
          .get();

      final seen = <String>{};
      final results = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};
        final name = data['locationName'] as String? ?? '';
        if (name.isEmpty || seen.contains(name)) continue;
        seen.add(name);
        results.add(data);
      }

      if (mounted) setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      debugPrint('DiscoverScreen search: $e');
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    _searchFocus.unfocus();
    setState(() {
      _searchTerm = '';
      _searchResults = [];
      _searchLoading = false;
    });
  }

  // ── Ad / feed helpers ─────────────────────────────────────────────────────────
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
      if (mounted) setState(() {
        _availableAds = ads;
        if (_posts.isNotEmpty) _feedItems = _mergeAdsIntoFeed(_posts);
      });
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

  List<Map<String, dynamic>> _mergeAdsIntoFeed(
      List<Map<String, dynamic>> posts) {
    _cadence.reset();
    final items = <Map<String, dynamic>>[];
    var adIndex = 0;

    for (final post in posts) {
      if (_availableAds.isNotEmpty) {
        bool adAdded = false;
        for (var i = 0; i < _availableAds.length; i++) {
          final candidate =
              _availableAds[(adIndex + i) % _availableAds.length];
          if (_cadence.shouldShowAd(
              candidateAdId: candidate['id'] as String?)) {
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

  // ── Widget builders ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
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
          const SizedBox(height: 10),
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3), width: 1),
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (q) {
                final trimmed = q.trim();
                if (trimmed.isNotEmpty) {
                  Navigator.pushNamed(
                    context,
                    '/search_results',
                    arguments: trimmed,
                  );
                }
              },
              style:
                  const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Search venues...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14),
                prefixIcon: Icon(Icons.search,
                    color: Colors.white.withValues(alpha: 0.8), size: 18),
                suffixIcon: _searchTerm.isNotEmpty
                    ? GestureDetector(
                        onTap: _clearSearch,
                        child: Icon(Icons.close,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 18),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_searchTerm.isNotEmpty) return _buildSearchBody();
    return _buildDefaultFeed();
  }

  // ── Default feed ──────────────────────────────────────────────────────────────
  Widget _buildDefaultFeed() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    if (_feedItems.isEmpty) {
      return const Center(
        child: Text('No posts yet', style: TextStyle(color: Colors.white)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _feedItems.length,
      itemBuilder: (context, index) {
        final item = _feedItems[index];
        return item['type'] == 'ad'
            ? _buildAdCard(item)
            : _buildLocationCard(item);
      },
    );
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

  Widget _buildLocationCard(Map<String, dynamic> post) {
    final crowdingLevel = (post['crowdingLevel'] ?? 0) as int;
    final locationName =
        post['locationName'] as String? ?? 'Unknown Location';
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
              post['imageUrl'] as String? ??
                  'https://via.placeholder.com/400x120',
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
                    color: _crowdColor(crowdingLevel),
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

  static Color _crowdColor(int level) {
    if (level <= 4) return const Color(0xFF4CAF50);
    if (level <= 6) return const Color(0xFFFFA726);
    return const Color(0xFFFF5722);
  }

  // ── Search results (inline) ───────────────────────────────────────────────────
  Widget _buildSearchBody() {
    if (_searchLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔍', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 10),
              Text(
                'No venues found for "$_searchTerm"',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) =>
          _buildSearchResultCard(_searchResults[index]),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> venue) {
    final name = venue['locationName'] as String? ?? 'Unknown';
    final imageUrl = venue['imageUrl'] as String? ?? '';
    final crowdLevel = (venue['crowdingLevel'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/venue', arguments: venue),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 60,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF0D47A1)),
                )
              else
                const ColoredBox(color: Color(0xFF0D47A1)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xCC000000), Color(0x44000000)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(blurRadius: 4, color: Colors.black54),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _crowdColor(crowdLevel),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          crowdLevel.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
