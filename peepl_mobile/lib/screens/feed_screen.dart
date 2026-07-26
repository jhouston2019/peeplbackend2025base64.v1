import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../services/ad_cadence_service.dart';
import '../services/feed_service.dart';
import '../services/geofence_service.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';
import 'location_detail_screen.dart';

/// Peepl Home Feed — Sponsored Card Specification
///
/// **Architecture (approved)**
/// - Single component path: [_FeedCardContent] → [_FeedListingCard]
/// - No layout forks; identical card shell for Peepl + sponsored content
/// - Deterministic placement: cards 4, 7, 11, 14, 18, 21 … (3, 2, 3, 2 … peeps)
/// - No full-width sponsored rows; one standard grid cell per ad
///
/// **1. Identification** — identifiable ≤1 s without dominating UI:
///   Top-right: advertiser logo or compact AD marker (same ring footprint).
///   Bottom overlay: muted “Sponsored” label (10–11 px) above brand name.
///
/// **2. Click behavior** — entire card tappable; CTA same destination + separate
///   analytics (impression, card_tap, cta_tap).
///
/// **3. Imagery** — full-bleed, center crop, no stretch/letterbox (same as Peepl).
///
/// **4. Frequency** — never two sponsored cards consecutively in the stream.
///
/// **5. Analytics** — impression, viewability (≥50 % for ≥1 s), card/CTA taps,
///   CTR by advertiser + by [feedPlacement] slot.
///
/// **6. Future slots** — optional promotionalBadge, eventTitle, dealText,
///   announcementText populate existing name/address/distance fields only.

/// Peepl Home Screen Engineering Specification v1.0 design tokens.
class _T {
  static const blue = Color(0xFF0054D8);
  static const yellow = Color(0xFFFFC107);
  static const dealGreen = Color(0xFFDCEFCB);
  static const dealGreenText = Color(0xFF1B5C2E);
  static const white = Color(0xFFFFFFFF);
  static const primaryText = Color(0xFF111111);
  static const secondaryText = Color(0xFF6B7280);
  static const cardFallback = Color(0xFF0D47A1);

  static const ringGreen = Color(0xFF34C759);
  static const ringAmber = Color(0xFFFF9F0A);
  static const ringOrange = Color(0xFFFF6B35);
  static const ringRed = Color(0xFFFF3B30);

  static const cardShadow = BoxShadow(
    color: Color(0x24000000),
    offset: Offset(0, 4),
    blurRadius: 12,
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

  final String _areaLabel = 'Perimeter Mall Area';

  double? _userLat;
  double? _userLng;

  static const double _localRadiusMiles = 25.0;
  static const double _regionRadiusMiles = 100.0;

  static const double _heroHeightFraction = 0.20;
  static const double _cardMarginBottom = 6;
  static const String _logoAsset = 'assets/images/peepl_logo_mirrored.png';
  /// Ad gap pattern: ad after 2 posts, then 3, then 2, then 3, repeating.
  static const List<int> _peepCardsBeforeAdPattern = [2, 3, 2, 3];

  /// Approved sponsor CTA labels — keeps pill size/typography consistent with Peepl cards.
  static const List<String> _approvedSponsorCtas = [
    'Book Now',
    'Order Online',
    'Reserve',
    'Shop Now',
    'Learn More',
    'Get Quote',
    'Get Offer',
    'View Menu',
    'Call Now',
    'Download',
  ];

  /// Sponsored cards share the Peepl card shell. Never louder: same size, type,
  /// overlay, CTA, shadows; no autoplay, animation, flash, or extra badges
  /// beyond a compact AD / logo mark in the score-ring slot.
  static const List<Map<String, dynamic>> _dummyNativeAds = [
    {
      'id': 'dummy_cocacola',
      'isDummy': true,
      'brandName': 'Coca-Cola',
      'headline': 'Taste the feeling',
      'subline': 'Ice-cold refreshment',
      'ctaText': 'Learn More',
      'imageAsset': 'assets/ads/cocacola.png',
    },
    {
      'id': 'dummy_progressive',
      'isDummy': true,
      'brandName': 'Progressive',
      'headline': 'Save on auto insurance',
      'subline': 'Bundle and save today',
      'ctaText': 'Get Quote',
      'imageAsset': 'assets/ads/progressive.png',
    },
    {
      'id': 'dummy_chanel',
      'isDummy': true,
      'brandName': 'Chanel',
      'headline': 'Bleu de Chanel',
      'subline': 'Luxury collection',
      'ctaText': 'Shop Now',
      'imageAsset': 'assets/ads/chanel.png',
    },
    {
      'id': 'dummy_stella_artois',
      'isDummy': true,
      'brandName': 'Stella Artois',
      'headline': 'Make time for the life artois',
      'subline': 'Premium lager',
      'ctaText': 'Learn More',
      'imageAsset': 'assets/ads/stella_artois.png',
    },
    {
      'id': 'dummy_vrbo',
      'isDummy': true,
      'brandName': 'Vrbo',
      'headline': 'Find your perfect getaway',
      'subline': 'Whole homes for your whole group',
      'ctaText': 'Book Now',
      'imageUrl':
          'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=240',
    },
    {
      'id': 'dummy_cotto',
      'isDummy': true,
      'brandName': 'Cotto Grill',
      'headline': '20% off entrees this week',
      'subline': '0.4 mi · Perimeter area',
      'promotionalBadge': '20% OFF',
      'ctaText': 'Get Offer',
      'imageUrl':
          'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=240',
    },
    {
      'id': 'dummy_nike',
      'isDummy': true,
      'brandName': 'Nike',
      'headline': 'Just do it',
      'subline': 'New arrivals in store',
      'ctaText': 'Shop Now',
      'imageUrl':
          'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=240',
    },
  ];

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
    if (_cadence.suppressesAds) {
      return List<Map<String, dynamic>>.from(posts);
    }

    _cadence.resetForMerge(postCount: posts.length);
    final items = <Map<String, dynamic>>[];
    var liveAdIndex = 0;
    var dummyAdIndex = 0;
    var patternIndex = 0;
    var peepCardsSinceAd = 0;
    var nextAdThreshold = _peepCardsBeforeAdPattern[0];
    var streamCardIndex = 0;

    Map<String, dynamic> pickAd() {
      if (_availableAds.isNotEmpty) {
        final ad = _availableAds[liveAdIndex % _availableAds.length];
        liveAdIndex++;
        return ad;
      }
      final dummy = Map<String, dynamic>.from(
        _dummyNativeAds[dummyAdIndex % _dummyNativeAds.length],
      );
      dummyAdIndex++;
      return dummy;
    }

    for (final post in posts) {
      if (peepCardsSinceAd >= nextAdThreshold) {
        final lastIsAd = items.isNotEmpty && items.last['type'] == 'ad';
        if (!lastIsAd) {
          streamCardIndex++;
          final ad = pickAd();
          items.add(<String, dynamic>{
            'type': 'ad',
            'feedPlacement': streamCardIndex,
            ...ad,
          });
          peepCardsSinceAd = 0;
          patternIndex++;
          nextAdThreshold = _peepCardsBeforeAdPattern[
              patternIndex % _peepCardsBeforeAdPattern.length];
        }
      }

      streamCardIndex++;
      items.add(post);
      peepCardsSinceAd++;
    }

    _cadence.finalizeMerge();
    return items;
  }

  String _normalizeSponsorCta(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Learn More';

    final trimmed = raw.trim();
    for (final cta in _approvedSponsorCtas) {
      if (trimmed.toLowerCase() == cta.toLowerCase()) return cta;
    }

    final key = trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    if (key.contains('book')) return 'Book Now';
    if (key.contains('order')) return 'Order Online';
    if (key.contains('reserv')) return 'Reserve';
    if (key.contains('shop')) return 'Shop Now';
    if (key.contains('quote')) return 'Get Quote';
    if (key.contains('offer') || key.contains('deal')) return 'Get Offer';
    if (key.contains('menu')) return 'View Menu';
    if (key.contains('call')) return 'Call Now';
    if (key.contains('download')) return 'Download';
    if (key.contains('learn')) return 'Learn More';
    return 'Learn More';
  }

  Future<void> _onRefresh() async {
    _loadFeedData();
    await _initLocation();
    await _loadAds();
  }

  Color _getCrowdingColor(int level) {
    if (level <= 4) return const Color(0xFF4CAF50);
    if (level <= 6) return const Color(0xFFFFA726);
    return const Color(0xFFFF5722);
  }

  int _crowdLevelInt(Map<String, dynamic> post) {
    final ai = post['aiScore'];
    if (ai is num) return ai.round().clamp(0, 10);
    final level = post['crowdingLevel'];
    if (level is num) return level.round().clamp(0, 10);
    return 0;
  }

  String _relativeTime(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime? dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else {
      try {
        dt = (timestamp as dynamic).toDate() as DateTime;
      } catch (_) {
        return '';
      }
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String? _subtitleLine(Map<String, dynamic> post) {
    final parts = <String>[];
    final distance = _distanceLabel(post);
    if (distance != null) parts.add(distance);
    final time = _relativeTime(post['timestamp']);
    if (time.isNotEmpty) parts.add(time);
    return parts.isEmpty ? null : parts.join(' · ');
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

      case 'Map':
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

  void _onFilterTapped(String filter) {
    if (filter == 'Map') {
      Navigator.pushNamed(context, '/map');
      return;
    }

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

  /// Card height so exactly 8 single-column rows fit without scrolling.
  double _cardHeightForFeed(double feedViewportHeight) {
    const rows = 8;
    return (feedViewportHeight - (rows - 1) * _cardMarginBottom) / rows;
  }

  double _headerHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height * _heroHeightFraction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.white,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            _buildHeroSection(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardHeight = _cardHeightForFeed(constraints.maxHeight);
                  return _buildFeedContent(cardHeight: cardHeight);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final headerHeight = _headerHeight(context);

    return SizedBox(
      height: headerHeight,
      width: double.infinity,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: _T.blue,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x18000000),
              offset: Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(child: _buildHeaderBar()),
            SizedBox(height: 44, child: _buildDealBanner()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _buildActionRow(),
              ),
            ),
            SizedBox(height: 36, child: _buildFilterAndMapRow()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Row(
          children: [
            Expanded(child: _buildLocationChip()),
            Image.asset(
              _logoAsset,
              height: 34,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                'peepl',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationChip() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Area selector coming soon')),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, color: Colors.white, size: 12),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              _areaLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 12),
        ],
      ),
    );
  }

  void _onDealBannerTapped() {
    final deal = _deals[_dealIndex];
    final merchant = (deal['merchant'] ?? '').toString();
    Map<String, dynamic>? match;
    for (final post in _posts) {
      final name = (post['locationName'] ?? '').toString();
      if (name.isEmpty) continue;
      final nameLower = name.toLowerCase();
      final merchantLower = merchant.toLowerCase();
      if (nameLower.contains(merchantLower) ||
          merchantLower.contains(nameLower)) {
        match = post;
        break;
      }
    }
    if (match != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LocationDetailScreen(postData: match!),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deal details coming soon')),
    );
  }

  Widget _buildDealBanner() {
    final deal = _deals[_dealIndex];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: GestureDetector(
        key: ValueKey(_dealIndex),
        onTap: _onDealBannerTapped,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: 44,
          color: _T.dealGreen,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.sell, size: 14, color: _T.dealGreenText),
              const SizedBox(width: 6),
              Text(
                deal['offer']!,
                style: const TextStyle(
                  color: _T.dealGreenText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${deal['merchant']}  ·  ${deal['distance']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _T.dealGreenText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Text(
                'View Deal',
                style: TextStyle(
                  color: _T.dealGreenText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(Icons.chevron_right, color: _T.dealGreenText, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
          _circleAction(Icons.local_offer_outlined, 'Deals', () {
            Navigator.pushNamed(context, '/deals');
          }),
          _circleAction(Icons.menu, 'Menu', () {
            Navigator.pushNamed(context, '/settings');
          }),
        ],
      ),
    );
  }

  Widget _circleAction(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _T.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, color: _T.blue, size: 18),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _peepButton() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/post'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: _T.yellow,
          shape: BoxShape.circle,
          border: Border.all(color: _T.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: _T.yellow.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: _T.blue, size: 20),
            const Text(
              'PEEP',
              style: TextStyle(
                color: _T.blue,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAndMapRow() {
    const filters = <String, IconData>{
      'Newest': Icons.calendar_today_outlined,
      'Nearby': Icons.location_on_outlined,
      'Local': Icons.storefront_outlined,
      'Region': Icons.public_outlined,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < filters.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _filterPill(filters.entries.elementAt(i)),
                  ],
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/map'),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.map_outlined, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Map View',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPill(MapEntry<String, IconData> entry) {
    final isActive = _activeFilter == entry.key;
    return GestureDetector(
      onTap: () => _onFilterTapped(entry.key),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF0046BE)
              : const Color(0xFF0046BE).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: isActive ? 0.55 : 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(entry.value, size: 11, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              entry.key,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
            if (entry.key == 'Newest') ...[
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down,
                size: 11,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedContent({required double cardHeight}) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_T.blue),
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
      color: _T.blue,
      backgroundColor: _T.white,
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        itemCount: _feedItems.length,
        itemBuilder: (context, index) {
          final item = _feedItems[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: _cardMarginBottom),
            child: SizedBox(
              height: cardHeight,
              child: _buildFeedCard(item),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedCard(Map<String, dynamic> item) {
    if (item['type'] == 'ad') {
      final content = _feedCardContentFromAd(item);
      return _FeedAdCard(
        name: content.name,
        ctaLabel: content.ctaLabel,
        onOpen: content.onOpen,
        onCta: content.onCta,
        onImpression: content.onImpression,
        onViewable: content.onViewable,
      );
    }

    final post = item;
    final name = (post['locationName'] ?? 'Unknown').toString();
    return _FeedPostCard(
      imageUrl: (post['imageUrl'] ?? '').toString(),
      name: name,
      subtitle: _subtitleLine(post),
      crowdLevel: _crowdLevelInt(post),
      crowdColor: _getCrowdingColor(_crowdLevelInt(post)),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LocationDetailScreen(postData: post),
        ),
      ),
    );
  }

  String _sponsorUserId() => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _openSponsorDestination(
    Map<String, dynamic> ad, {
    required String tapKind,
  }) async {
    final adId = (ad['id'] ?? '').toString();
    final placement = (ad['feedPlacement'] as num?)?.toInt();
    final advertiserId = (ad['advertiserId'] ?? ad['advertiserName'] ?? '')
        .toString();
    final uid = _sponsorUserId();
    final destination = (ad['ctaUrl'] ??
            ad['landingUrl'] ??
            ad['destinationUrl'] ??
            '')
        .toString()
        .trim();
    final isDummy = ad['isDummy'] == true;

    if (tapKind == 'card') {
      unawaited(_adsService.recordAdCardTap(
        adId,
        uid,
        feedPlacement: placement,
        advertiserId: advertiserId.isEmpty ? null : advertiserId,
      ));
    } else {
      unawaited(_adsService.recordAdCtaTap(
        adId,
        uid,
        feedPlacement: placement,
        advertiserId: advertiserId.isEmpty ? null : advertiserId,
      ));
    }

    if (destination.isNotEmpty) {
      final uri = Uri.tryParse(destination);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (!mounted || !isDummy) return;
    final headline = (ad['headline'] ?? ad['title'] ?? 'Sponsored').toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$headline (demo ad)'),
        backgroundColor: _T.blue,
      ),
    );
  }

  _FeedCardContent _feedCardContentFromAd(Map<String, dynamic> ad) {
    final brandName = (ad['brandName'] ??
            ad['advertiserName'] ??
            ad['merchantName'] ??
            '')
        .toString();
    final headline =
        (ad['headline'] ?? ad['title'] ?? 'Sponsored offer').toString();
    final ctaText = _normalizeSponsorCta(ad['ctaText'] as String?);
    final adId = (ad['id'] ?? '').toString();
    final placement = (ad['feedPlacement'] as num?)?.toInt();
    final advertiserId = (ad['advertiserId'] ?? ad['advertiserName'] ?? '')
        .toString();
    final name = brandName.isNotEmpty ? brandName : headline;

    return _FeedCardContent(
      name: name,
      ctaLabel: ctaText,
      onImpression: () {
        unawaited(_adsService.recordAdImpression(
          adId,
          _sponsorUserId(),
          feedPlacement: placement,
          advertiserId: advertiserId.isEmpty ? null : advertiserId,
        ));
      },
      onViewable: () {
        unawaited(_adsService.recordAdViewability(
          adId,
          _sponsorUserId(),
          feedPlacement: placement,
          advertiserId: advertiserId.isEmpty ? null : advertiserId,
        ));
      },
      onOpen: () => unawaited(_openSponsorDestination(ad, tapKind: 'card')),
      onCta: () => unawaited(_openSponsorDestination(ad, tapKind: 'cta')),
    );
  }
}

class _FeedCardContent {
  const _FeedCardContent({
    required this.name,
    required this.ctaLabel,
    required this.onOpen,
    required this.onCta,
    this.onImpression,
    this.onViewable,
  });

  final String name;
  final String ctaLabel;
  final VoidCallback onOpen;
  final VoidCallback onCta;
  final VoidCallback? onImpression;
  final VoidCallback? onViewable;
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({
    required this.imageUrl,
    required this.name,
    required this.subtitle,
    required this.crowdLevel,
    required this.crowdColor,
    required this.onTap,
  });

  final String imageUrl;
  final String name;
  final String? subtitle;
  final int crowdLevel;
  final Color crowdColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _feedCardImage(imageUrl),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 72,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: _CrowdBadge(
                  level: crowdLevel,
                  color: crowdColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrowdBadge extends StatelessWidget {
  const _CrowdBadge({
    required this.level,
    required this.color,
  });

  final int level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 2.5),
        ),
        alignment: Alignment.center,
        child: Text(
          '$level',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _FeedAdCard extends StatefulWidget {
  const _FeedAdCard({
    required this.name,
    required this.ctaLabel,
    required this.onOpen,
    required this.onCta,
    this.onImpression,
    this.onViewable,
  });

  final String name;
  final String ctaLabel;
  final VoidCallback onOpen;
  final VoidCallback onCta;
  final VoidCallback? onImpression;
  final VoidCallback? onViewable;

  @override
  State<_FeedAdCard> createState() => _FeedAdCardState();
}

class _FeedAdCardState extends State<_FeedAdCard> {
  bool _impressionFired = false;
  bool _viewabilityFired = false;
  Timer? _viewabilityTimer;

  @override
  void dispose() {
    _viewabilityTimer?.cancel();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (widget.onImpression == null && widget.onViewable == null) return;

    if (info.visibleFraction >= 0.5) {
      if (!_impressionFired && widget.onImpression != null) {
        _impressionFired = true;
        widget.onImpression!();
      }
      if (!_viewabilityFired &&
          widget.onViewable != null &&
          _viewabilityTimer == null) {
        _viewabilityTimer = Timer(const Duration(seconds: 1), () {
          if (!mounted || _viewabilityFired) return;
          _viewabilityFired = true;
          widget.onViewable?.call();
        });
      }
    } else {
      _viewabilityTimer?.cancel();
      _viewabilityTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF1565C0);

    final card = GestureDetector(
      onTap: widget.onOpen,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFFF5F7FA)),
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: accent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'SPONSORED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onCta,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.ctaLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
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
    );

    if (widget.onImpression == null && widget.onViewable == null) {
      return card;
    }

    return VisibilityDetector(
      key: Key('feed_ad_${widget.name}_${widget.ctaLabel.hashCode}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: card,
    );
  }
}

Widget _feedCardImage(String source, {Alignment alignment = const Alignment(0, 0.35)}) {
  if (source.isEmpty) {
    return Container(color: _T.cardFallback);
  }
  if (source.startsWith('assets/')) {
    return Image.asset(
      source,
      fit: BoxFit.cover,
      alignment: alignment,
      errorBuilder: (_, __, ___) => Container(color: _T.cardFallback),
    );
  }
  return Image.network(
    source,
    fit: BoxFit.cover,
    alignment: alignment,
    errorBuilder: (_, __, ___) => Container(color: _T.cardFallback),
  );
}

/// Debug/web preview host — mirrors [MainShell] bottom nav height so the
/// 8-row feed math matches a real phone viewport.
class FeedPreviewHost extends StatelessWidget {
  const FeedPreviewHost({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _T.white,
      body: Column(
        children: [
          const Expanded(child: FeedScreen()),
          Container(
            height: 41 + bottomInset,
            padding: EdgeInsets.only(bottom: bottomInset),
            color: _T.blue,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                Icon(Icons.home, color: Colors.white, size: 16),
                Icon(Icons.explore, color: Colors.white54, size: 16),
                Icon(Icons.notifications_outlined, color: Colors.white54, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
