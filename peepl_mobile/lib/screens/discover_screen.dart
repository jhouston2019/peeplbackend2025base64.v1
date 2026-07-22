import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../utils/post_crowd_format.dart';
import '../widgets/crowd_meter.dart';
import 'location_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const _kNearRadiusM = 10000.0;
  static const TextStyle _overlayShadow = TextStyle(
    color: Colors.white,
    shadows: [
      Shadow(offset: Offset(0, 1), blurRadius: 6, color: Colors.black87),
    ],
  );

  bool _isLoading = true;
  bool _hasLocation = false;
  double? _userLat;
  double? _userLng;

  List<Map<String, dynamic>> _trending = [];
  List<Map<String, dynamic>> _mostCrowded = [];
  List<Map<String, dynamic>> _leastCrowded = [];

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  String _searchTerm = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _searchLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDiscoverData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadDiscoverData() async {
    setState(() => _isLoading = true);

    final pos = await LocationService.getCurrentLocation();
    if (pos != null) {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      _hasLocation = true;
    }

    await _loadTrending();
    if (_hasLocation) {
      await _loadNearbyPosts();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadTrending() async {
    try {
      final dayAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)),
      );
      final snap = await FirebaseFirestore.instance
          .collection('location_posts')
          .where('timestamp', isGreaterThan: dayAgo)
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();

      final posts = snap.docs
          .map(
            (doc) => <String, dynamic>{
              'id': doc.id,
              ...doc.data(),
            },
          )
          .toList();

      posts.sort((a, b) {
        final la = (a['likesCount'] as num?)?.toInt() ?? 0;
        final lb = (b['likesCount'] as num?)?.toInt() ?? 0;
        return lb.compareTo(la);
      });

      if (mounted) setState(() => _trending = posts.take(5).toList());
    } catch (e) {
      debugPrint('DiscoverScreen trending: $e');
      if (mounted) setState(() => _trending = []);
    }
  }

  Future<void> _loadNearbyPosts() async {
    if (_userLat == null || _userLng == null) return;

    try {
      final dayAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)),
      );
      final snap = await FirebaseFirestore.instance
          .collection('location_posts')
          .where('timestamp', isGreaterThan: dayAgo)
          .orderBy('timestamp', descending: true)
          .limit(300)
          .get();

      final nearby = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = <String, dynamic>{'id': doc.id, ...doc.data()};
        final dist = _distanceMeters(data);
        if (dist != null && dist <= _kNearRadiusM) {
          nearby.add(data);
        }
      }

      final most = List<Map<String, dynamic>>.from(nearby)
        ..sort(
          (a, b) => _crowdLevel(b).compareTo(_crowdLevel(a)),
        );

      final least = List<Map<String, dynamic>>.from(nearby)
        ..sort(
          (a, b) => _crowdLevel(a).compareTo(_crowdLevel(b)),
        );

      if (mounted) {
        setState(() {
          _mostCrowded = most.take(5).toList();
          _leastCrowded = least.take(5).toList();
        });
      }
    } catch (e) {
      debugPrint('DiscoverScreen nearby: $e');
      if (mounted) {
        setState(() {
          _mostCrowded = [];
          _leastCrowded = [];
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final term = value.trim();
    setState(() => _searchTerm = term);
    if (term.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 350), () => _doSearch(term));
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

      final results = snap.docs
          .map(
            (doc) => <String, dynamic>{
              'id': doc.id,
              ...doc.data(),
            },
          )
          .toList();

      if (mounted) {
        setState(() {
          _searchResults = results;
          _searchLoading = false;
        });
      }
    } catch (e) {
      debugPrint('DiscoverScreen search: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searchLoading = false;
        });
      }
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

  int _crowdLevel(Map<String, dynamic> post) {
    return (post['crowdingLevel'] as num?)?.toInt() ?? 0;
  }

  double? _distanceMeters(Map<String, dynamic> post) {
    if (_userLat == null || _userLng == null) return null;
    final lat = (post['latitude'] as num?)?.toDouble();
    final lng = (post['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return _haversineMeters(_userLat!, _userLng!, lat, lng);
  }

  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
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

  void _openDetail(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => LocationDetailScreen(postData: post),
      ),
    );
  }

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
    return TextField(
      controller: _searchCtrl,
      focusNode: _searchFocus,
      onChanged: _onSearchChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: 'Search venues...',
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.search,
          color: Colors.white.withValues(alpha: 0.8),
          size: 18,
        ),
        suffixIcon: _searchTerm.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.close,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 18,
                ),
                onPressed: _clearSearch,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(21),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(21),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(21),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
      ),
    );
  }

  Widget _buildBody() {
    if (_searchTerm.isNotEmpty) return _buildSearchBody();
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    return _buildDiscoverSections();
  }

  Widget _buildDiscoverSections() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildBrowseVenuesButton(),
        _buildDealsButton(),
        _buildLeaderboardButton(),
        _buildGetPeepsButton(),
        _buildTrendingButton(),
        _buildSection('Trending Now', _trending),
        if (_hasLocation) ...[
          _buildSection('Most Crowded Near You', _mostCrowded),
          _buildSection('Least Crowded Near You', _leastCrowded),
        ],
      ],
    );
  }

  Widget _buildBrowseVenuesButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/venue_list'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: Color(0xFF1565C0),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Browse Venues',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Filter by type, search, and find spots near you',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDealsButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/deals'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_offer_outlined,
                    color: Color(0xFF2E7D32),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deals',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Claim exclusive offers from local merchants',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/leaderboard'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    color: Color(0xFF1565C0),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leaderboard',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'See top Peepl contributors this week',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGetPeepsButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/get_peeps'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.groups_2_outlined,
                    color: Color(0xFF1565C0),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Get Peeps',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ask people nearby for a live crowd update',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/trending'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.whatshot_outlined,
                    color: Color(0xFFFF5722),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trending',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'See the hottest spots right now',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> posts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (posts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No posts in this section yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
              ),
            ),
          )
        else
          ...posts.map(
            (post) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildLocationCard(post),
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
      onTap: () => _openDetail(post),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: cardHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              post['imageUrl']?.toString() ??
                  'https://via.placeholder.com/400x400',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: Colors.grey.shade800,
                child: const Icon(Icons.image, color: Colors.white54, size: 40),
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
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['locationName']?.toString() ?? 'Unknown',
                          style: _overlayShadow.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          post['username']?.toString() ?? 'Unknown',
                          style: _overlayShadow.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatDate(post['timestamp'])} · ${_formatDistance(post)}',
                          style: _overlayShadow.copyWith(
                            fontSize: 8,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
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
            ),
          ],
        ),
      ),
    );
  }

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
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) =>
          _buildLocationCard(_searchResults[index]),
    );
  }
}
