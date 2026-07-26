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
import '../shell_tab_bus.dart';
import 'location_detail_screen.dart';

/// Peepl Home Screen v2.0 design tokens.
class _T {
  static const blueTop = Color(0xFF0A66FF);
  static const blueBottom = Color(0xFF0054D8);
  static const dealGreen = Color(0xFFA5D6A7);
  static const feedBg = Color(0xFFFFFFFF);
  static const cardFallback = Color(0xFF0D47A1);
  static const primaryText = Color(0xFF111111);
  static const secondaryText = Color(0xFF6B7280);

  static const ringGreen = Color(0xFF34C759);
  static const ringAmber = Color(0xFFFF9F0A);
  static const ringOrange = Color(0xFFFF6B35);
  static const ringRed = Color(0xFFFF3B30);

  static const cardShadow = BoxShadow(
    color: Color(0x24000000),
    offset: Offset(0, 16),
    blurRadius: 40,
  );

  static const pillShadow = BoxShadow(
    color: Color(0x14000000),
    offset: Offset(0, 4),
    blurRadius: 10,
  );
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

  String _activeFilter = 'Newest';

  double? _userLat;
  double? _userLng;

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

  Color _ringColor(num level) {
    final v = level.toDouble();
    if (v <= 3) return _T.ringGreen;
    if (v <= 6) return _T.ringAmber;
    if (v <= 8) return _T.ringOrange;
    return _T.ringRed;
  }

  String _scoreLabel(Map<String, dynamic> post) {
    final ai = post['aiScore'];
    if (ai is num) {
      return ai.toDouble().toStringAsFixed(1);
    }
    final level = post['crowdingLevel'];
    if (level is num) {
      return level.toDouble().toStringAsFixed(1);
    }
    return '0.0';
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

  String? _distanceLabel(Map<String, dynamic> post) {
    final miles = _milesTo(post);
    if (miles == null) return null;
    return '${miles.toStringAsFixed(1)} mi';
  }

  String? _addressLine(Map<String, dynamic> post) {
    for (final key in [
      'address',
      'streetAddress',
      'formattedAddress',
      'street',
    ]) {
      final raw = post[key];
      if (raw == null) continue;
      final text = raw.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  Future<void> _onExploreLiveTapped(Map<String, dynamic> post) async {
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
              'Explore Live request sent for $locationName',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: _T.blueTop,
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

  void _openNotificationsTab() {
    ShellTabBus.requestTab(3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.feedBg,
      body: Column(
        children: [
          _buildHeader(),
          _buildDealBanner(),
          _buildNearbyHeader(),
          Expanded(child: _buildFeedContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_T.blueTop, _T.blueBottom],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 32,
              child: Center(
                child: Text(
                  'peepl',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _buildHeaderNav(),
            const SizedBox(height: 8),
            _buildFilterRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderNav() {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.local_offer_outlined, 'Deals', () => Navigator.pushNamed(context, '/deals')),
      (Icons.explore_outlined, 'Explore', () => Navigator.pushNamed(context, '/discover')),
      (Icons.bookmark_border, 'Saved', () => Navigator.pushNamed(context, '/favorites')),
      (Icons.notifications_outlined, 'Alerts', _openNotificationsTab),
      (Icons.person_outline, 'Profile', () => Navigator.pushNamed(context, '/profile')),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((item) {
        return _HeaderNavItem(
          icon: item.$1,
          label: item.$2,
          onTap: item.$3,
        );
      }).toList(),
    );
  }

  Widget _buildFilterRow() {
    const filters = <String, IconData>{
      'Newest': Icons.calendar_today_outlined,
      'Nearby': Icons.location_on_outlined,
      'Local': Icons.storefront_outlined,
      'Region': Icons.map_outlined,
    };

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entry = filters.entries.elementAt(index);
          final isActive = _activeFilter == entry.key;
          return GestureDetector(
            onTap: () => _onFilterTapped(entry.key),
            behavior: HitTestBehavior.opaque,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: 1.0,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? _T.blueBottom : _T.blueTop,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isActive ? 0.5 : 0.25),
                  ),
                  boxShadow: const [_T.pillShadow],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(entry.value, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      entry.key,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDealBanner() {
    final deal = _deals[_dealIndex];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(_dealIndex),
        width: double.infinity,
        height: 42,
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: _T.dealGreen,
        child: Row(
          children: [
            Icon(Icons.sell, size: 18, color: Colors.green.shade800),
            const SizedBox(width: 8),
            Text(
              deal['offer']!,
              style: const TextStyle(
                color: _T.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${deal['merchant']}  ·  ${deal['distance']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _T.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.green.shade900, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyHeader() {
    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Nearby',
            style: TextStyle(
              color: _T.primaryText,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_T.blueTop),
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
              Icon(Icons.error_outline, size: 56, color: _T.secondaryText),
              const SizedBox(height: 14),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: _T.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Please try again later',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _T.secondaryText, fontSize: 14),
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
          style: TextStyle(color: _T.secondaryText, fontSize: 15),
        ),
      );
    }

    return RefreshIndicator(
      color: _T.blueTop,
      backgroundColor: _T.feedBg,
      onRefresh: _onRefresh,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 3 / 4,
        ),
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
    final name = (post['locationName'] ?? 'Unknown').toString();
    final imageUrl = (post['imageUrl'] ?? '').toString();
    final address = _addressLine(post);
    final distance = _distanceLabel(post);
    final score = _scoreLabel(post);
    final ringColor = _ringColor(
      post['aiScore'] is num
          ? post['aiScore'] as num
          : ((post['crowdingLevel'] as num?) ?? 0),
    );

    return _FeedListingCard(
      imageUrl: imageUrl,
      name: name,
      address: address,
      distance: distance,
      scoreLabel: score,
      ringColor: ringColor,
      onOpen: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LocationDetailScreen(postData: post),
        ),
      ),
      onExploreLive: () => _onExploreLiveTapped(post),
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final headline = (ad['headline'] ?? ad['title'] ?? 'Sponsored').toString();
    final imageUrl = (ad['imageUrl'] ?? '').toString();

    return _FeedListingCard(
      imageUrl: imageUrl,
      name: headline,
      address: null,
      distance: null,
      scoreLabel: null,
      ringColor: null,
      isSponsored: true,
      onOpen: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(headline), backgroundColor: _T.blueTop),
        );
      },
      onExploreLive: null,
    );
  }
}

class _HeaderNavItem extends StatelessWidget {
  const _HeaderNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedListingCard extends StatefulWidget {
  const _FeedListingCard({
    required this.imageUrl,
    required this.name,
    required this.address,
    required this.distance,
    required this.scoreLabel,
    required this.ringColor,
    required this.onOpen,
    required this.onExploreLive,
    this.isSponsored = false,
  });

  final String imageUrl;
  final String name;
  final String? address;
  final String? distance;
  final String? scoreLabel;
  final Color? ringColor;
  final bool isSponsored;
  final VoidCallback onOpen;
  final VoidCallback? onExploreLive;

  @override
  State<_FeedListingCard> createState() => _FeedListingCardState();
}

class _FeedListingCardState extends State<_FeedListingCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onOpen,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _pressed ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [_T.cardShadow],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.imageUrl.isNotEmpty)
                  Image.network(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _T.cardFallback,
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: const Color(0xFFE8ECF2),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  )
                else
                  Container(color: _T.cardFallback),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.72),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                if (widget.isSponsored)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Text(
                      'Sponsored',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (widget.scoreLabel != null && widget.ringColor != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _ScoreRing(
                      label: widget.scoreLabel!,
                      color: widget.ringColor!,
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: widget.onExploreLive != null ? 52 : 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                        ),
                      ),
                      if (widget.address != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.address!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.80),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ],
                      if (widget.distance != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.distance!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.onExploreLive != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: _ExploreLiveButton(onTap: widget.onExploreLive!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.55)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreLiveButton extends StatefulWidget {
  const _ExploreLiveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ExploreLiveButton> createState() => _ExploreLiveButtonState();
}

class _ExploreLiveButtonState extends State<_ExploreLiveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _pressed ? 0.90 : 1.0,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: const Text(
            'Explore Live',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
