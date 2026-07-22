import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/location_service.dart';
import '../utils/post_crowd_format.dart';
import '../widgets/crowd_meter.dart';
import 'location_detail_screen.dart';
import 'user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  static const _kUsersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';
  static const _kRecentSearchesKey = 'recent_searches';

  static const TextStyle _overlayShadow = TextStyle(
    color: Colors.white,
    shadows: [
      Shadow(offset: Offset(0, 1), blurRadius: 6, color: Colors.black87),
    ],
  );

  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  late final TabController _tabController;

  Timer? _debounce;
  String _query = '';
  List<String> _recentSearches = [];

  List<Map<String, dynamic>> _placeResults = [];
  List<_PeopleResult> _peopleResults = [];
  final Map<String, bool> _followingByUserId = {};
  final Set<String> _followLoading = {};

  bool _loadingPlaces = false;
  bool _loadingPeople = false;
  String? _placesError;
  String? _peopleError;

  double? _userLat;
  double? _userLng;

  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(_onSearchTextChanged);
    _loadRecentSearches();
    _initUserLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchTextChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initUserLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (pos == null || !mounted) return;
    setState(() {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
    });
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_kRecentSearchesKey) ?? [];
    if (!mounted) return;
    setState(() => _recentSearches = stored.take(5).toList());
  }

  Future<void> _saveRecentSearch(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;

    final updated = [
      trimmed,
      ..._recentSearches.where((s) => s.toLowerCase() != trimmed.toLowerCase()),
    ].take(5).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentSearchesKey, updated);
    if (mounted) setState(() => _recentSearches = updated);
  }

  void _onSearchTextChanged() {
    final text = _searchCtrl.text;
    if (text == _query) return;
    setState(() => _query = text);

    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _placeResults = [];
        _peopleResults = [];
        _loadingPlaces = false;
        _loadingPeople = false;
        _placesError = null;
        _peopleError = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(text.trim());
    });
  }

  void _applyRecentSearch(String term) {
    _searchCtrl.text = term;
    _searchCtrl.selection = TextSelection.collapsed(offset: term.length);
    _runSearch(term.trim());
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _placeResults = [];
      _peopleResults = [];
      _loadingPlaces = false;
      _loadingPeople = false;
      _placesError = null;
      _peopleError = null;
    });
  }

  Future<void> _runSearch(String term) async {
    if (term.isEmpty) return;

    final generation = ++_searchGeneration;
    setState(() {
      _loadingPlaces = true;
      _loadingPeople = true;
      _placesError = null;
      _peopleError = null;
    });

    await Future.wait([
      _searchPlaces(term, generation),
      _searchPeople(term, generation),
    ]);

    if (generation == _searchGeneration) {
      await _saveRecentSearch(term);
    }
  }

  Future<void> _searchPlaces(String term, int generation) async {
    try {
      final snap = await _db
          .collection('location_posts')
          .where('locationName', isGreaterThanOrEqualTo: term)
          .where('locationName', isLessThan: '${term}z')
          .orderBy('locationName')
          .limit(40)
          .get();

      if (!mounted || generation != _searchGeneration) return;

      final grouped = _groupPlacesByLocation(snap.docs);
      setState(() {
        _placeResults = grouped;
        _loadingPlaces = false;
      });
    } catch (e) {
      debugPrint('SearchScreen._searchPlaces: $e');
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _placesError = e.toString();
        _loadingPlaces = false;
        _placeResults = [];
      });
    }
  }

  Future<void> _searchPeople(String term, int generation) async {
    try {
      final snap = await _db
          .collection(_kUsersCollection)
          .where('username', isGreaterThanOrEqualTo: term)
          .where('username', isLessThan: '${term}z')
          .orderBy('username')
          .limit(30)
          .get();

      if (!mounted || generation != _searchGeneration) return;

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final people = <_PeopleResult>[];

      await Future.wait(snap.docs.map((doc) async {
        final data = doc.data();
        final username = data['username'] as String? ??
            data['displayName'] as String? ??
            'User';

        int postCount = 0;
        try {
          final countSnap = await _db
              .collection('location_posts')
              .where('userId', isEqualTo: doc.id)
              .count()
              .get();
          postCount = countSnap.count ?? 0;
        } catch (_) {}

        var isFollowing = false;
        if (currentUid != null && currentUid != doc.id) {
          try {
            final followDoc = await _db
                .collection('users')
                .doc(currentUid)
                .collection('following')
                .doc(doc.id)
                .get();
            isFollowing = followDoc.exists;
          } catch (_) {}
        }

        people.add(
          _PeopleResult(
            userId: doc.id,
            username: username,
            postCount: postCount,
            isFollowing: isFollowing,
          ),
        );
      }));

      people.sort(
        (a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()),
      );

      if (!mounted || generation != _searchGeneration) return;

      setState(() {
        _peopleResults = people;
        _followingByUserId
          ..clear()
          ..addEntries(people.map((p) => MapEntry(p.userId, p.isFollowing)));
        _loadingPeople = false;
      });
    } catch (e) {
      debugPrint('SearchScreen._searchPeople: $e');
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _peopleError = e.toString();
        _loadingPeople = false;
        _peopleResults = [];
      });
    }
  }

  List<Map<String, dynamic>> _groupPlacesByLocation(
    List<QueryDocumentSnapshot> docs,
  ) {
    final byName = <String, Map<String, dynamic>>{};
    for (final doc in docs) {
      final data = <String, dynamic>{
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      };
      final name = data['locationName'] as String? ?? '';
      if (name.isEmpty) continue;

      final existing = byName[name];
      if (existing == null ||
          _timestampMs(data['timestamp']) > _timestampMs(existing['timestamp'])) {
        byName[name] = data;
      }
    }
    return byName.values.toList();
  }

  static int _timestampMs(dynamic ts) {
    if (ts is Timestamp) return ts.millisecondsSinceEpoch;
    if (ts is DateTime) return ts.millisecondsSinceEpoch;
    return 0;
  }

  Future<void> _toggleFollow(_PeopleResult person) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == person.userId) return;

    setState(() => _followLoading.add(person.userId));
    try {
      final myRef = _db.collection('users').doc(currentUser.uid);
      final theirRef = _db.collection('users').doc(person.userId);
      final isFollowing = _followingByUserId[person.userId] ?? false;
      final now = FieldValue.serverTimestamp();

      if (isFollowing) {
        await Future.wait([
          myRef.collection('following').doc(person.userId).delete(),
          theirRef.collection('followers').doc(currentUser.uid).delete(),
        ]);
      } else {
        await Future.wait([
          myRef
              .collection('following')
              .doc(person.userId)
              .set({'followedAt': now}),
          theirRef
              .collection('followers')
              .doc(currentUser.uid)
              .set({'followedAt': now}),
        ]);
      }

      if (mounted) {
        setState(() {
          _followingByUserId[person.userId] = !isFollowing;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _followLoading.remove(person.userId));
    }
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
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  String _formatDistance(Map<String, dynamic> post) {
    final m = _distanceMeters(post);
    if (m == null) return '—';
    final mi = m * 0.000621371;
    if (mi < 0.1) return '${(m * 3.28084).round()} ft';
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

  int _crowdLevel(Map<String, dynamic> post) {
    return (post['crowdingLevel'] as num?)?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final trimmedQuery = _query.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Column(
        children: [
          _buildHeader(topPad),
          _buildSearchBar(),
          if (trimmedQuery.isEmpty && _recentSearches.isNotEmpty)
            _buildRecentChips(),
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2244EE),
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: const Color(0xFF2244EE),
              tabs: const [
                Tab(text: 'Places'),
                Tab(text: 'People'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPlacesTab(trimmedQuery),
                _buildPeopleTab(trimmedQuery),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double topPad) {
    return Container(
      color: const Color(0xFF2244EE),
      padding: EdgeInsets.fromLTRB(0, topPad + 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Search',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search places or people',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF2244EE)),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF3F4F8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildRecentChips() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent searches',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((term) {
              return ActionChip(
                label: Text(term),
                onPressed: () => _applyRecentSearch(term),
                backgroundColor: const Color(0xFFEEF1FF),
                labelStyle: const TextStyle(
                  color: Color(0xFF2244EE),
                  fontSize: 13,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesTab(String trimmedQuery) {
    if (trimmedQuery.isEmpty) {
      return _buildIdleHint('Search for a place by name');
    }
    if (_loadingPlaces) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_placesError != null) {
      return _buildErrorState(_placesError!, () => _runSearch(trimmedQuery));
    }
    if (_placeResults.isEmpty) {
      return _buildEmptyState(trimmedQuery);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _placeResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _buildLocationCard(_placeResults[index]);
      },
    );
  }

  Widget _buildPeopleTab(String trimmedQuery) {
    if (trimmedQuery.isEmpty) {
      return _buildIdleHint('Search for people by username');
    }
    if (_loadingPeople) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_peopleError != null) {
      return _buildErrorState(_peopleError!, () => _runSearch(trimmedQuery));
    }
    if (_peopleResults.isEmpty) {
      return _buildEmptyState(trimmedQuery);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _peopleResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _buildPeopleRow(_peopleResults[index]);
      },
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> post) {
    final crowdingLevel = _crowdLevel(post);
    final w = MediaQuery.sizeOf(context).width;
    final cardHeight = w * 0.19;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => LocationDetailScreen(postData: post),
        ),
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
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: Colors.grey.shade300,
                child: const Icon(Icons.place, color: Colors.white54, size: 40),
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

  Widget _buildPeopleRow(_PeopleResult person) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isSelf = currentUid == person.userId;
    final isFollowing = _followingByUserId[person.userId] ?? false;
    final loading = _followLoading.contains(person.userId);
    final initial =
        person.username.isNotEmpty ? person.username[0].toUpperCase() : '?';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => UserProfileScreen(userId: person.userId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF2244EE),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.username,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${person.postCount} post${person.postCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isSelf && currentUid != null)
                TextButton(
                  onPressed: loading ? null : () => _toggleFollow(person),
                  style: TextButton.styleFrom(
                    foregroundColor: isFollowing
                        ? Colors.grey.shade700
                        : const Color(0xFF2244EE),
                    backgroundColor: isFollowing
                        ? Colors.grey.shade200
                        : const Color(0xFFEEF1FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdleHint(String message) {
    return Center(
      child: Text(
        message,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              'No results for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2244EE),
              ),
              child: const Text('Try again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleResult {
  const _PeopleResult({
    required this.userId,
    required this.username,
    required this.postCount,
    required this.isFollowing,
  });

  final String userId;
  final String username;
  final int postCount;
  final bool isFollowing;
}
