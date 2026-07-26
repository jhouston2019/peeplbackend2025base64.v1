import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../services/ad_cadence_service.dart';
import '../services/crowdsource_service.dart';
import '../services/feed_service.dart';
import '../services/geofence_service.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';
import '../utils/post_crowd_format.dart';
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

  /// Hero = 10% viewport. Mockup design 393×852, spec rows 130+36+84+34 = 284px.
  static const double _heroHeightFraction = 0.10;
  static const double _heroDesignHeight = 284.0;
  static const double _gridGutter = 8;
  static const int _targetVisibleRows = 8;
  /// Peep cards between native ad slots: 4, 7, 11, 14, 18, 21 … (3, 2, 3, 2 …).
  static const List<int> _peepCardsBeforeAdPattern = [3, 2];

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
      'id': 'dummy_progressive',
      'isDummy': true,
      'brandName': 'Progressive',
      'headline': 'Save on auto insurance',
      'subline': 'Bundle and save today',
      'ctaText': 'Get Quote',
      'imageUrl':
          'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?w=240',
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
        for (var i = 0; i < _availableAds.length; i++) {
          final candidate = _availableAds[(liveAdIndex + i) % _availableAds.length];
          if (_cadence.tryConsumeRowAdSlot(
            candidateAdId: candidate['id'] as String?,
          )) {
            liveAdIndex += i + 1;
            return candidate;
          }
        }
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
              'Explore Live request sent for $locationName',
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

  void _onFilterTapped(String filter) {
    if (filter == 'Map') {
      setState(() => _activeFilter = 'Map');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Map view coming soon')),
      );
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

  /// Card height sized so exactly [_targetVisibleRows] two-column rows
  /// fit in the feed viewport on a phone without scrolling.
  double _cardHeightForFeed(double feedViewportHeight) {
    final rowStride = feedViewportHeight / _targetVisibleRows;
    return math.max(44, rowStride - _gridGutter);
  }

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
            _buildNearbyRow(),
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
    final screen = MediaQuery.sizeOf(context);
    final heroH = screen.height * _heroHeightFraction;
    final scale = heroH / _heroDesignHeight;
    final m = _HeroDesign.scaled(scale);

    return SizedBox(
      height: heroH,
      width: double.infinity,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _T.blue,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(m.curveRadius),
            bottomRight: Radius.circular(m.curveRadius),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x18000000),
              offset: Offset(0, 2 * scale),
              blurRadius: 6 * scale,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: m.headerH,
              child: Padding(
                padding: EdgeInsets.fromLTRB(m.hPad, 0, m.hPad, m.headerBottomPad),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildHeaderBar(m),
                ),
              ),
            ),
            SizedBox(height: m.dealH, child: _buildDealBanner(m)),
            SizedBox(height: m.actionH, child: _buildActionRow(m)),
            SizedBox(height: m.filterH, child: Center(child: _buildFilterRow(m))),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar(_HeroDesign m) {
    return Row(
      children: [
        Expanded(child: _buildLocationChip(m)),
        Text(
          'peepl',
          style: TextStyle(
            color: Colors.white,
            fontSize: m.logoSize,
            fontWeight: FontWeight.w800,
            height: 1.0,
            letterSpacing: -0.3,
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: m.profileSize,
                height: m.profileSize,
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
                  size: m.profileSize * 0.55,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationChip(_HeroDesign m) {
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
          Icon(Icons.location_on, color: Colors.white, size: m.locationIcon),
          SizedBox(width: 2 * m.scale),
          Flexible(
            child: Text(
              _areaLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: m.locationFont,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(Icons.keyboard_arrow_down, color: Colors.white, size: m.locationIcon),
        ],
      ),
    );
  }

  Widget _buildDealBanner(_HeroDesign m) {
    final deal = _deals[_dealIndex];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(_dealIndex),
        width: double.infinity,
        height: m.dealH,
        color: _T.dealGreen,
        padding: EdgeInsets.symmetric(horizontal: m.hPad),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.sell, size: m.dealIcon, color: _T.dealGreenText),
            SizedBox(width: m.hPad * 0.5),
            Text(
              deal['offer']!,
              style: TextStyle(
                color: _T.dealGreenText,
                fontSize: m.dealOfferFont,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: m.hPad * 0.5),
            Expanded(
              child: Text(
                '${deal['merchant']}  ·  ${deal['distance']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _T.dealGreenText,
                  fontSize: m.dealMetaFont,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              'View Deal',
              style: TextStyle(
                color: _T.dealGreenText,
                fontSize: m.dealMetaFont,
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(Icons.chevron_right, color: _T.dealGreenText, size: m.dealIcon),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(_HeroDesign m) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: m.hPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _circleAction(Icons.search, 'Search', m, () {
            Navigator.pushNamed(context, '/search');
          }),
          _circleAction(Icons.explore_outlined, 'Explore', m, () {
            Navigator.pushNamed(context, '/discover');
          }),
          _peepButton(m),
          _circleAction(Icons.local_offer_outlined, 'Deals', m, () {
            Navigator.pushNamed(context, '/deals');
          }),
          _circleAction(Icons.menu, 'Menu', m, () {
            Navigator.pushNamed(context, '/settings');
          }),
        ],
      ),
    );
  }

  Widget _circleAction(
    IconData icon,
    String label,
    _HeroDesign m,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: m.actionCircle,
            height: m.actionCircle,
            decoration: BoxDecoration(
              color: _T.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x26000000),
                  offset: Offset(0, 2 * m.scale),
                  blurRadius: 4 * m.scale,
                ),
              ],
            ),
            child: Icon(icon, color: _T.blue, size: m.actionIcon),
          ),
          SizedBox(height: m.actionLabelGap),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: m.actionLabel,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _peepButton(_HeroDesign m) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/post'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: m.peepCircle,
        height: m.peepCircle,
        decoration: BoxDecoration(
          color: _T.yellow,
          shape: BoxShape.circle,
          border: Border.all(color: _T.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: _T.yellow.withValues(alpha: 0.35),
              blurRadius: 6 * m.scale,
              offset: Offset(0, 2 * m.scale),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: _T.blue, size: m.peepIcon),
            Text(
              'PEEPL',
              style: TextStyle(
                color: _T.blue,
                fontSize: m.peepFont,
                fontWeight: FontWeight.w800,
                height: 1.0,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow(_HeroDesign m) {
    const filters = <String, IconData>{
      'Newest': Icons.calendar_today_outlined,
      'Nearby': Icons.location_on_outlined,
      'Local': Icons.storefront_outlined,
      'Map': Icons.map_outlined,
      'Region': Icons.public_outlined,
    };

    return SizedBox(
      height: m.filterPillH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: m.hPad),
        itemCount: filters.length,
        separatorBuilder: (_, __) => SizedBox(width: m.filterGap),
        itemBuilder: (context, index) {
          final entry = filters.entries.elementAt(index);
          final isActive = _activeFilter == entry.key;
          return GestureDetector(
            onTap: () => _onFilterTapped(entry.key),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: m.filterPillH,
              padding: EdgeInsets.symmetric(horizontal: m.hPad * 0.85),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF0046BE)
                    : const Color(0xFF0046BE).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(m.filterPillH / 2),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isActive ? 0.55 : 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x33000000),
                    offset: Offset(0, 2 * m.scale),
                    blurRadius: 4 * m.scale,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(entry.value, size: m.filterIcon, color: Colors.white),
                  SizedBox(width: m.hPad * 0.35),
                  Text(
                    entry.key,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: m.filterFont,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                  if (entry.key == 'Newest') ...[
                    SizedBox(width: m.hPad * 0.15),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: m.filterIcon,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNearbyRow() {
    return Container(
      color: _T.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        children: [
          const Text(
            'Nearby',
            style: TextStyle(
              color: _T.primaryText,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Map view coming soon')),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.map_outlined, size: 16, color: _T.blue),
                SizedBox(width: 4),
                Text(
                  'Map View',
                  style: TextStyle(
                    color: _T.blue,
                    fontSize: 13,
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
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: _buildFeedSlivers(context, cardHeight),
      ),
    );
  }

  List<Widget> _buildFeedSlivers(BuildContext context, double cardHeight) {
    final slivers = <Widget>[];
    final postBuffer = <Map<String, dynamic>>[];

    void flushRow() {
      if (postBuffer.isEmpty) return;

      final left = postBuffer.removeAt(0);
      final right = postBuffer.isNotEmpty ? postBuffer.removeAt(0) : null;

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: _gridGutter),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: cardHeight,
                      child: _buildGridCard(left, cardHeight),
                    ),
                  ),
                  const SizedBox(width: _gridGutter),
                  Expanded(
                    child: right == null
                        ? SizedBox(height: cardHeight)
                        : SizedBox(
                            height: cardHeight,
                            child: _buildGridCard(right, cardHeight),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    for (final item in _feedItems) {
      postBuffer.add(item);
      if (postBuffer.length == 2) flushRow();
    }
    flushRow();

    slivers.add(
      const SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 90),
        sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
      ),
    );

    return slivers;
  }

  Widget _buildGridCard(Map<String, dynamic> item, double cardHeight) {
    final content = _feedCardContent(item);
    return _FeedListingCard(
      cardHeight: cardHeight,
      imageUrl: content.imageUrl,
      name: content.name,
      address: content.address,
      distance: content.distance,
      topMark: content.topMark,
      ctaLabel: content.ctaLabel,
      showSponsoredDisclosure: content.showSponsoredDisclosure,
      onImpression: content.onImpression,
      onViewable: content.onViewable,
      onOpen: content.onOpen,
      onExploreLive: content.onCta,
    );
  }

  _FeedCardContent _feedCardContent(Map<String, dynamic> item) {
    if (item['type'] == 'ad') {
      return _feedCardContentFromAd(item);
    }
    return _feedCardContentFromPost(item);
  }

  _FeedCardContent _feedCardContentFromPost(Map<String, dynamic> post) {
    final name = (post['locationName'] ?? 'Unknown').toString();
    return _FeedCardContent(
      imageUrl: (post['imageUrl'] ?? '').toString(),
      name: name,
      address: _addressLine(post),
      distance: _distanceLabel(post),
      topMark: _FeedTopMark.aiScore(
        label: _scoreLabel(post),
        color: _ringColor(
          post['aiScore'] is num
              ? post['aiScore'] as num
              : ((post['crowdingLevel'] as num?) ?? 0),
        ),
      ),
      ctaLabel: 'Explore Live',
      showSponsoredDisclosure: false,
      onOpen: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LocationDetailScreen(postData: post),
        ),
      ),
      onCta: () => _onAskTapped(post),
    );
  }

  String? _sponsorSecondaryLine(Map<String, dynamic> ad) {
    for (final key in [
      'promotionalBadge',
      'dealText',
      'offerText',
      'eventTitle',
      'announcementText',
      'subline',
      'bodyText',
    ]) {
      final value = (ad[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return null;
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
    final subline = (ad['subline'] ?? ad['bodyText'] ?? '').toString();
    final ctaText = _normalizeSponsorCta(ad['ctaText'] as String?);
    final logoUrl = (ad['logoUrl'] ??
            ad['brandLogoUrl'] ??
            ad['advertiserLogoUrl'] ??
            '')
        .toString();
    final adId = (ad['id'] ?? '').toString();
    final placement = (ad['feedPlacement'] as num?)?.toInt();
    final advertiserId = (ad['advertiserId'] ?? ad['advertiserName'] ?? '')
        .toString();

    final name = brandName.isNotEmpty ? brandName : headline;
    final secondary = _sponsorSecondaryLine(ad);
    String? address;
    String? distance;
    if (brandName.isNotEmpty && headline.isNotEmpty) {
      address = headline;
      distance = subline.isNotEmpty && subline != headline ? subline : secondary;
    } else {
      address = secondary;
      distance = subline.isNotEmpty && subline != address ? subline : null;
    }

    return _FeedCardContent(
      imageUrl: (ad['imageUrl'] ?? '').toString(),
      name: name,
      address: address,
      distance: distance,
      topMark: logoUrl.isNotEmpty
          ? _FeedTopMark.sponsorLogo(logoUrl)
          : const _FeedTopMark.sponsorAd(),
      ctaLabel: ctaText,
      showSponsoredDisclosure: true,
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

class _FeedTopMark {
  const _FeedTopMark._({
    required this.kind,
    this.scoreLabel,
    this.ringColor,
    this.logoUrl,
  });

  const _FeedTopMark.aiScore({
    required String label,
    required Color color,
  }) : this._(
          kind: _FeedTopMarkKind.aiScore,
          scoreLabel: label,
          ringColor: color,
        );

  const _FeedTopMark.sponsorLogo(String url)
      : this._(kind: _FeedTopMarkKind.sponsorLogo, logoUrl: url);

  const _FeedTopMark.sponsorAd()
      : this._(kind: _FeedTopMarkKind.sponsorAd);

  final _FeedTopMarkKind kind;
  final String? scoreLabel;
  final Color? ringColor;
  final String? logoUrl;
}

enum _FeedTopMarkKind { aiScore, sponsorLogo, sponsorAd }

class _FeedCardContent {
  const _FeedCardContent({
    required this.imageUrl,
    required this.name,
    required this.address,
    required this.distance,
    required this.topMark,
    required this.ctaLabel,
    required this.showSponsoredDisclosure,
    required this.onOpen,
    required this.onCta,
    this.onImpression,
    this.onViewable,
  });

  final String imageUrl;
  final String name;
  final String? address;
  final String? distance;
  final _FeedTopMark topMark;
  final String ctaLabel;
  final bool showSponsoredDisclosure;
  final VoidCallback onOpen;
  final VoidCallback onCta;
  final VoidCallback? onImpression;
  final VoidCallback? onViewable;
}

class _FeedListingCard extends StatefulWidget {
  const _FeedListingCard({
    required this.cardHeight,
    required this.imageUrl,
    required this.name,
    required this.address,
    required this.distance,
    required this.topMark,
    required this.ctaLabel,
    required this.showSponsoredDisclosure,
    required this.onOpen,
    required this.onExploreLive,
    this.onImpression,
    this.onViewable,
  });

  final double cardHeight;
  final String imageUrl;
  final String name;
  final String? address;
  final String? distance;
  final _FeedTopMark topMark;
  final String ctaLabel;
  final bool showSponsoredDisclosure;
  final VoidCallback onOpen;
  final VoidCallback onExploreLive;
  final VoidCallback? onImpression;
  final VoidCallback? onViewable;

  @override
  State<_FeedListingCard> createState() => _FeedListingCardState();
}

class _FeedListingCardState extends State<_FeedListingCard> {
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
    final h = widget.cardHeight;
    final overlayH = (h * 0.54).clamp(22.0, 46.0);
    final ringSize = (h * 0.30).clamp(22.0, 32.0);
    final nameSize = (h * 0.13).clamp(8.0, 11.0);
    final sponsoredLabelSize = (h * 0.12).clamp(10.0, 11.0);
    final metaSize = (h * 0.11).clamp(7.0, 9.0);
    final pad = (h * 0.06).clamp(4.0, 8.0);
    final showAddress = h >= 56 && widget.address != null && !widget.showSponsoredDisclosure;
    final showDistance = widget.distance != null && !widget.showSponsoredDisclosure;
    final ctaHeight = (h * 0.22).clamp(16.0, 22.0);

    final card = GestureDetector(
      onTap: widget.onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [_T.cardShadow],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.imageUrl.isNotEmpty)
                Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, 0.35),
                  errorBuilder: (_, __, ___) =>
                      Container(color: _T.cardFallback),
                )
              else
                Container(color: _T.cardFallback),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: overlayH + 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.82),
                        Colors.black.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: pad * 0.5,
                right: pad * 0.5,
                child: _CardTopMark(mark: widget.topMark, size: ringSize),
              ),
              Positioned(
                left: pad,
                right: pad,
                bottom: pad * 0.35,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.showSponsoredDisclosure) ...[
                            Text(
                              'Sponsored',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: sponsoredLabelSize,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                              ),
                            ),
                            SizedBox(height: pad * 0.1),
                          ],
                          Text(
                            widget.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: nameSize,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                          if (showAddress) ...[
                            SizedBox(height: pad * 0.12),
                            Text(
                              widget.address!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: metaSize,
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                              ),
                            ),
                          ],
                          if (showDistance) ...[
                            SizedBox(height: pad * 0.12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: metaSize,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  widget.distance!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: metaSize,
                                    fontWeight: FontWeight.w500,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    _ExploreLiveButton(
                      onTap: widget.onExploreLive,
                      height: ctaHeight,
                      fontSize: (h * 0.09).clamp(6.0, 8.0),
                      label: widget.ctaLabel,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.onImpression == null && widget.onViewable == null) {
      return card;
    }

    return VisibilityDetector(
      key: Key('feed_card_${widget.name}_${widget.imageUrl.hashCode}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: card,
    );
  }
}

class _CardTopMark extends StatelessWidget {
  const _CardTopMark({required this.mark, required this.size});

  final _FeedTopMark mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (mark.kind) {
      case _FeedTopMarkKind.aiScore:
        return _ScoreRing(
          label: mark.scoreLabel ?? '0.0',
          color: mark.ringColor ?? _T.ringGreen,
          size: size,
        );
      case _FeedTopMarkKind.sponsorLogo:
        return _SponsorMark(
          size: size,
          logoUrl: mark.logoUrl,
        );
      case _FeedTopMarkKind.sponsorAd:
        return _SponsorMark(size: size);
    }
  }
}

/// Same footprint as [_ScoreRing]. Logo when provided, otherwise compact "AD".
class _SponsorMark extends StatelessWidget {
  const _SponsorMark({required this.size, this.logoUrl});

  final double size;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.42),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? Image.network(
              logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _adLabel(),
            )
          : _adLabel(),
    );
  }

  Widget _adLabel() {
    return Center(
      child: Text(
        'AD',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.28,
          fontWeight: FontWeight.w800,
          height: 1.0,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({
    required this.label,
    required this.color,
    this.size = 32,
  });

  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.42),
        border: Border.all(color: color, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.30,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: _T.ringGreen,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.16,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreLiveButton extends StatelessWidget {
  const _ExploreLiveButton({
    required this.onTap,
    this.height = 22,
    this.fontSize = 7,
    this.label = 'Explore Live',
  });

  final VoidCallback onTap;
  final double height;
  final double fontSize;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: height * 0.3),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

/// Spec v1.0 mockup at 393×852 — every dimension × [scale] to fit 10% hero.
class _HeroDesign {
  const _HeroDesign({
    required this.scale,
    required this.headerH,
    required this.dealH,
    required this.actionH,
    required this.filterH,
    required this.headerBottomPad,
    required this.hPad,
    required this.curveRadius,
    required this.logoSize,
    required this.profileSize,
    required this.locationFont,
    required this.locationIcon,
    required this.dealIcon,
    required this.dealOfferFont,
    required this.dealMetaFont,
    required this.actionCircle,
    required this.peepCircle,
    required this.actionIcon,
    required this.peepIcon,
    required this.peepFont,
    required this.actionLabel,
    required this.actionLabelGap,
    required this.filterPillH,
    required this.filterFont,
    required this.filterIcon,
    required this.filterGap,
  });

  factory _HeroDesign.scaled(double scale) {
    double s(double v) => v * scale;
    return _HeroDesign(
      scale: scale,
      headerH: s(130),
      dealH: s(36),
      actionH: s(84),
      filterH: s(34),
      headerBottomPad: s(8),
      hPad: s(12),
      curveRadius: s(20),
      logoSize: s(18),
      profileSize: s(30),
      locationFont: s(11),
      locationIcon: s(12),
      dealIcon: s(11),
      dealOfferFont: s(10),
      dealMetaFont: s(9),
      actionCircle: s(58),
      peepCircle: s(84),
      actionIcon: s(22),
      peepIcon: s(24),
      peepFont: s(7),
      actionLabel: s(9),
      actionLabelGap: s(3),
      filterPillH: s(34),
      filterFont: s(10),
      filterIcon: s(11),
      filterGap: s(6),
    );
  }

  final double scale;
  final double headerH;
  final double dealH;
  final double actionH;
  final double filterH;
  final double headerBottomPad;
  final double hPad;
  final double curveRadius;
  final double logoSize;
  final double profileSize;
  final double locationFont;
  final double locationIcon;
  final double dealIcon;
  final double dealOfferFont;
  final double dealMetaFont;
  final double actionCircle;
  final double peepCircle;
  final double actionIcon;
  final double peepIcon;
  final double peepFont;
  final double actionLabel;
  final double actionLabelGap;
  final double filterPillH;
  final double filterFont;
  final double filterIcon;
  final double filterGap;
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
