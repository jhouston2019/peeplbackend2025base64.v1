import 'dart:async';
import 'dart:math' as math;
import 'dart:math' show atan2, cos, pi, sin, sqrt;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../notifiers/active_filter_notifier.dart';
import '../constants/local_deals.dart';
import '../constants/national_brand_ads.dart';
import '../services/ad_cadence_service.dart';
import '../services/geofence_service.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';
import '../widgets/crowd_meter.dart';
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
  final NativeAdsService _adsService = NativeAdsService();
  final AdCadenceService _cadence = AdCadenceService();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _feedSub;

  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _feedItems = [];
  List<Map<String, dynamic>> _availableAds = [];

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  String _activeFilter = 'Newest';
  String _searchQuery = '';

  List<Map<String, dynamic>> _dealBannerItems = LocalDeals.fallback
      .map((deal) => Map<String, dynamic>.from(deal))
      .toList();
  int _dealBannerIndex = 0;
  Timer? _dealRotationTimer;

  final String _areaLabel = 'Perimeter Mall Area';

  double? _userLat;
  double? _userLng;
  double? _latitude;
  double? _longitude;

  static const double _localRadiusMeters = 16000.0;

  static const double _heroHeightFraction = 0.17;
  static const double _cardMarginBottom = 6;
  static const double _shellBottomNavHeight = 44;
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

  /// National brand inventory when Firestore native_ads is empty (or web preview).
  static List<Map<String, dynamic>> get _fallbackAds => NationalBrandAds.all;

  @override
  void initState() {
    super.initState();
    _activeFilter = activeFilterNotifier.value;
    activeFilterNotifier.addListener(_onFilterChanged);
    unawaited(_cadence.init().then((_) {
      if (!mounted) return;
      setState(() => _feedItems = _rebuildFeedItems());
    }));
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low)
        .then((pos) {
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        _feedItems = _rebuildFeedItems();
      });
    }).catchError((_) {});
    _initLocation();
    _loadFeedData();
    _loadDealBanner();
    _loadAds();
  }

  void _onFilterChanged() {
    setState(() => _activeFilter = activeFilterNotifier.value);
    _loadFeedData();
  }

  @override
  void dispose() {
    activeFilterNotifier.removeListener(_onFilterChanged);
    _dealRotationTimer?.cancel();
    _feedSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (!mounted || pos == null) return;
    setState(() {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      _latitude = pos.latitude;
      _longitude = pos.longitude;
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildFeedQuery() {
    final base = FirebaseFirestore.instance.collection('location_posts');
    switch (_activeFilter) {
      case 'Nearby':
        return base
            .orderBy('timestamp', descending: true)
            .limit(100)
            .snapshots();
      case 'Local':
        return base
            .orderBy('timestamp', descending: true)
            .limit(100)
            .snapshots();
      case 'Region':
        return base
            .orderBy('timestamp', descending: true)
            .limit(200)
            .snapshots();
      case 'Newest':
        return base
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots();
      default:
        return base
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots();
    }
  }

  void _loadFeedData() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    _feedSub?.cancel();
    _feedSub = _buildFeedQuery().listen(
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

  Map<String, dynamic>? get _currentBannerDeal {
    if (_dealBannerItems.isEmpty) return null;
    return _dealBannerItems[_dealBannerIndex % _dealBannerItems.length];
  }

  Future<void> _loadDealBanner() async {
    var deals = <Map<String, dynamic>>[];

    try {
      final hasDealSnap = await FirebaseFirestore.instance
          .collection('native_ads')
          .where('isActive', isEqualTo: true)
          .where('hasDeal', isEqualTo: true)
          .where('dealExpiry', isGreaterThan: Timestamp.now())
          .orderBy('dealExpiry')
          .limit(20)
          .get();
      deals = hasDealSnap.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('[feed] hasDeal banner query failed: $e');
    }

    if (deals.isEmpty) {
      try {
        final activeSnap = await FirebaseFirestore.instance
            .collection('native_ads')
            .where('isActive', isEqualTo: true)
            .where('endDate', isGreaterThan: Timestamp.now())
            .orderBy('endDate')
            .limit(20)
            .get();
        deals = activeSnap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      } catch (e) {
        debugPrint('[feed] active ads banner query failed: $e');
      }
    }

    if (deals.isEmpty) {
      deals = LocalDeals.fallback
          .map((deal) => Map<String, dynamic>.from(deal))
          .toList();
    }

    deals.sort(_compareDealsByDistance);

    if (!mounted) return;
    setState(() {
      _dealBannerItems = deals;
      _dealBannerIndex = 0;
    });
    _startDealRotation();
  }

  int _compareDealsByDistance(Map<String, dynamic> a, Map<String, dynamic> b) {
    final da = _dealDistanceMeters(a);
    final db = _dealDistanceMeters(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  double? _dealDistanceMeters(Map<String, dynamic> deal) {
    final userLat = _latitude ?? _userLat;
    final userLng = _longitude ?? _userLng;
    if (userLat == null || userLng == null) return null;

    final lat = (deal['venueLat'] as num?)?.toDouble() ??
        (deal['latitude'] as num?)?.toDouble();
    final lng = (deal['venueLng'] as num?)?.toDouble() ??
        (deal['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    return _haversine(userLat, userLng, lat, lng);
  }

  String _dealDistanceLabel(Map<String, dynamic> deal) {
    final cached = deal['distance'] as String?;
    if (cached != null && cached.trim().isNotEmpty) return cached.trim();

    final meters = _dealDistanceMeters(deal);
    if (meters == null) return '';
    final miles = meters / 1609.344;
    if (miles < 0.1) return 'nearby';
    return '${miles.toStringAsFixed(1)} mi';
  }

  String _dealBannerText(Map<String, dynamic> deal) {
    return [
      LocalDeals.discount(deal),
      LocalDeals.advertiser(deal),
      _dealDistanceLabel(deal),
    ].where((part) => part.isNotEmpty).join('  ·  ');
  }

  void _startDealRotation() {
    _dealRotationTimer?.cancel();
    if (_dealBannerItems.length <= 1) return;

    _dealRotationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _dealBannerItems.length <= 1) return;
      setState(() {
        _dealBannerIndex = (_dealBannerIndex + 1) % _dealBannerItems.length;
      });
    });
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
      if (!mounted) return;
      setState(() {
        _availableAds = [];
        _feedItems = _rebuildFeedItems();
      });
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

    posts.removeWhere((p) =>
        (p['imageUrl'] ?? '').toString().trim().isEmpty);

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
    var adIndex = 0;
    var patternIndex = 0;
    var peepCardsSinceAd = 0;
    var nextAdThreshold = _peepCardsBeforeAdPattern[0];
    var streamCardIndex = 0;

    Map<String, dynamic> pickAd() {
      final pool = _fallbackAds;
      final ad = Map<String, dynamic>.from(
        pool[adIndex % pool.length],
      );
      adIndex++;
      return ad;
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

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dphi = (lat2 - lat1) * pi / 180;
    final dlambda = (lon2 - lon1) * pi / 180;
    final a = sin(dphi / 2) * sin(dphi / 2) +
        cos(phi1) * cos(phi2) * sin(dlambda / 2) * sin(dlambda / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double? _distanceMeters(Map<String, dynamic> post) {
    final lat = post['latitude'];
    final lng = post['longitude'];
    final userLat = _latitude ?? _userLat;
    final userLng = _longitude ?? _userLng;
    if (userLat == null || userLng == null) return null;
    if (lat is! num || lng is! num) return null;
    return _haversine(
      userLat,
      userLng,
      lat.toDouble(),
      lng.toDouble(),
    );
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

  DateTime? _postTimestamp(Map<String, dynamic> post) {
    final timestamp = post['timestamp'];
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    try {
      return (timestamp as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> posts) {
    switch (_activeFilter) {
      case 'Nearby':
        if (_latitude != null && _longitude != null) {
          final out = List<Map<String, dynamic>>.from(posts);
          out.sort((a, b) {
            final da = _distanceMeters(a);
            final db = _distanceMeters(b);
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
          return out;
        }
        return posts;

      case 'Local':
        final filtered = posts.where((post) {
          final meters = _distanceMeters(post);
          return meters != null && meters <= _localRadiusMeters;
        }).toList();
        filtered.sort((a, b) {
          final ta = _postTimestamp(a);
          final tb = _postTimestamp(b);
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });
        return filtered;

      case 'Region':
        return posts;

      case 'Newest':
      default:
        return posts;
    }
  }

  String? _distanceLabel(Map<String, dynamic> post) {
    final miles = _milesTo(post);
    if (miles == null) return null;
    return '${miles.toStringAsFixed(1)} mi';
  }

  String _displayName(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown Venue';
    final parts = raw.split(',');
    final first = parts.first.trim();
    if (RegExp(r'^\d+\s|^US-|^I-\d+').hasMatch(first)) {
      return raw.trim();
    }
    return first;
  }

  List<Map<String, dynamic>> get _visibleFeedItems {
    if (_searchQuery.isEmpty) return _feedItems;
    final q = _searchQuery.toLowerCase();
    return _feedItems.where((item) {
      if (item['type'] == 'ad') return false;
      final name = (item['locationName'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search venues...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim());
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  double _headerHeight(BuildContext context) {
    const logoRowHeight = 60.0;
    const bannerGap = 14.0;
    const dealBannerHeight = 22.0;
    const iconRowHeight = 56.0;
    const verticalInset = 8.0;
    const iconRowGap = 6.0;
    const minHeaderHeight = verticalInset +
        logoRowHeight +
        bannerGap +
        dealBannerHeight +
        iconRowGap +
        iconRowHeight +
        4;
    return math.max(
      MediaQuery.sizeOf(context).height * 0.20,
      minHeaderHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final headerHeight = _headerHeight(context);
    final feedHeight = screenHeight - headerHeight - 44;
    final cardHeight = (feedHeight - (7 * 6)) / 8;

    return Scaffold(
      backgroundColor: _T.white,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            _buildBlueHeader(),
            Expanded(
              child: _buildFeedContent(cardHeight: cardHeight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlueHeader() {
    const logoRowHeight = 60.0;
    const bannerGap = 14.0;
    const dealBannerHeight = 22.0;
    const iconRowHeight = 56.0;
    const verticalInset = 8.0;
    const iconRowGap = 6.0;
    const minHeaderHeight = verticalInset +
        logoRowHeight +
        bannerGap +
        dealBannerHeight +
        iconRowGap +
        iconRowHeight +
        4;
    final totalHeader = math.max(
      MediaQuery.sizeOf(context).height * 0.20,
      minHeaderHeight,
    );

    return SizedBox(
      height: totalHeader,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Container(
            height: totalHeader,
            width: double.infinity,
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
          ),
          Column(
            children: [
              const SizedBox(height: verticalInset),
              SizedBox(height: logoRowHeight, child: _buildLogoBar()),
              const SizedBox(height: bannerGap),
              _buildDealBanner(),
              const SizedBox(height: iconRowGap),
              SizedBox(height: iconRowHeight, child: _buildIconRow(iconRowHeight)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoBar() {
    final logoCharStyle = TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.w900,
      height: 1.0,
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: _buildLocationChip()),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text('p', style: logoCharStyle),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('e', style: logoCharStyle),
                  Transform.scale(
                    scaleX: -1,
                    child: Text('e', style: logoCharStyle),
                  ),
                ],
              ),
              Text('pl', style: logoCharStyle),
            ],
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _buildIconRow(double slotHeight) {
    const iconSize = 14.0;
    const labelSize = 7.0;
    final outerSize = slotHeight * 0.42;
    final peepSize = slotHeight * 0.62;

    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 8, right: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _headerAction(
            icon: Icons.search,
            label: 'Search',
            circleSize: outerSize,
            iconSize: iconSize,
            labelSize: labelSize,
            onTap: _showSearchSheet,
          ),
          _headerAction(
            icon: Icons.notifications_outlined,
            label: 'Alerts',
            circleSize: outerSize,
            iconSize: iconSize,
            labelSize: labelSize,
            onTap: () => Navigator.pushNamed(context, '/alerts'),
          ),
          _headerAction(
            icon: Icons.explore,
            label: 'Explore',
            circleSize: outerSize,
            iconSize: iconSize,
            labelSize: labelSize,
            onTap: () => Navigator.pushNamed(context, '/explore'),
          ),
          _headerPeepAction(
            circleSize: peepSize,
            labelSize: labelSize,
          ),
          _headerAction(
            icon: Icons.local_offer,
            label: 'Deals',
            circleSize: outerSize,
            iconSize: iconSize,
            labelSize: labelSize,
            circleColor: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
            onTap: () => Navigator.pushNamed(context, '/deals'),
          ),
          _headerAction(
            icon: Icons.map_outlined,
            label: 'Map',
            circleSize: outerSize,
            iconSize: iconSize,
            labelSize: labelSize,
            onTap: () => Navigator.pushNamed(context, '/map'),
          ),
          _headerAction(
            icon: Icons.menu,
            label: 'Menu',
            circleSize: outerSize,
            iconSize: iconSize,
            labelSize: labelSize,
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
    );
  }

  Widget _headerAction({
    required IconData icon,
    required String label,
    required double circleSize,
    required double iconSize,
    required double labelSize,
    required VoidCallback onTap,
    Color? circleColor,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              color: circleColor ?? _T.white,
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
            child: Icon(icon, color: iconColor ?? _T.blue, size: iconSize),
          ),
          SizedBox(height: circleSize * 0.06),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: labelSize,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerPeepAction({
    required double circleSize,
    required double labelSize,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/post'),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: circleSize,
            height: circleSize,
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
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '+',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
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
          SizedBox(height: circleSize * 0.06),
          SizedBox(height: labelSize),
        ],
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

  Widget _buildDealBanner() {
    final deal = _currentBannerDeal;
    if (deal == null) {
      return const SizedBox.shrink();
    }

    final bannerText = _dealBannerText(deal);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/deals'),
      child: Container(
        width: double.infinity,
        height: 22,
        color: const Color(0xFFE8F5E9),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.local_offer, color: Color(0xFF2E7D32), size: 12),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Text(
                  bannerText,
                  key: ValueKey<String>(
                    '${_dealBannerIndex}_$bannerText',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const Text(
              'View Deal >',
              style: TextStyle(
                color: Color(0xFF2E7D32),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
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

    final items = _visibleFeedItems;

    if (items.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty
              ? 'No venues match your search.'
              : 'No peeps yet. Be the first.',
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
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 50),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 6, left: 0, right: 0),
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
        tagline: content.tagline,
        distance: content.distance,
        initial: content.initial,
        accentColor: content.accentColor,
        imageUrl: content.imageUrl,
        ctaLabel: content.ctaLabel,
        onOpen: content.onOpen,
        onCta: content.onCta,
        onImpression: content.onImpression,
        onViewable: content.onViewable,
      );
    }

    final post = item;
    final name = _displayName(post['locationName']?.toString());
    return _FeedPostCard(
      imageUrl: (post['imageUrl'] ?? '').toString(),
      name: name,
      subtitle: _subtitleLine(post),
      crowdLevel: _crowdLevelInt(post),
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
    final advertiser = (ad['advertiser'] ??
            ad['brandName'] ??
            ad['advertiserName'] ??
            ad['merchantName'] ??
            ad['headline'] ??
            ad['title'] ??
            '')
        .toString();
    final headline =
        (ad['headline'] ?? ad['title'] ?? 'Sponsored offer').toString();
    final rawCta = (ad['cta'] ?? ad['ctaText'])?.toString().trim();
    final ctaText = (rawCta != null && rawCta.isNotEmpty)
        ? rawCta
        : _normalizeSponsorCta(rawCta);
    final adId = (ad['id'] ?? '').toString();
    final placement = (ad['feedPlacement'] as num?)?.toInt();
    final advertiserId = (ad['advertiserId'] ??
            ad['advertiserName'] ??
            ad['advertiser'] ??
            '')
        .toString();
    final name = advertiser.isNotEmpty ? advertiser : headline;
    final tagline = (ad['tagline'] ??
            ad['subline'] ??
            ad['headline'] ??
            ad['bodyText'] ??
            '')
        .toString();
    final distance = (ad['distance'] ?? '').toString();
    final accentColor = Color(
      (ad['accentColor'] as int?) ?? 0xFF1565C0,
    );
    final initialRaw = (ad['initial'] ?? '').toString();
    final initial = initialRaw.isNotEmpty
        ? initialRaw
        : (name.isNotEmpty ? name.trim()[0].toUpperCase() : 'A');
    final imageUrl = NationalBrandAds.imageSource(ad);

    return _FeedCardContent(
      name: name,
      tagline: tagline,
      distance: distance,
      initial: initial,
      accentColor: accentColor,
      imageUrl: imageUrl,
      ctaLabel: ctaText.isNotEmpty ? ctaText : 'Learn More',
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
    required this.tagline,
    required this.distance,
    required this.initial,
    required this.accentColor,
    required this.imageUrl,
    required this.ctaLabel,
    required this.onOpen,
    required this.onCta,
    this.onImpression,
    this.onViewable,
  });

  final String name;
  final String tagline;
  final String distance;
  final String initial;
  final Color accentColor;
  final String imageUrl;
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
    required this.onTap,
  });

  final String imageUrl;
  final String name;
  final String? subtitle;
  final int crowdLevel;
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
                      style: TextStyle(
                        color: const Color(0xFFFFF9C4),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 4,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ],
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
                child: CrowdMeter(level: crowdLevel, size: 52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedAdCard extends StatefulWidget {
  const _FeedAdCard({
    required this.name,
    required this.tagline,
    required this.distance,
    required this.initial,
    required this.accentColor,
    required this.imageUrl,
    required this.ctaLabel,
    required this.onOpen,
    required this.onCta,
    this.onImpression,
    this.onViewable,
  });

  final String name;
  final String tagline;
  final String distance;
  final String initial;
  final Color accentColor;
  final String imageUrl;
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
    if (widget.imageUrl.isNotEmpty) {
      return _wrapVisibility(
        GestureDetector(
          onTap: widget.onOpen,
          behavior: HitTestBehavior.opaque,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _feedCardImage(widget.imageUrl),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withOpacity(0.72),
                          Colors.black.withOpacity(0.15),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SPONSORED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(0, 1),
                                    blurRadius: 4,
                                    color: Colors.black.withOpacity(0.6),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.tagline.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                widget.tagline,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.0,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(0, 1),
                                      blurRadius: 4,
                                      color: Colors.black.withOpacity(0.6),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.onCta,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.ctaLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
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
        ),
      );
    }

    const sponsoredBlue = Color(0xFF1565C0);
    final leadingTile = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: widget.accentColor,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );

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
              child: ColoredBox(color: sponsoredBlue),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  leadingTile,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: sponsoredBlue,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'SPONSORED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: sponsoredBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        if (widget.tagline.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.tagline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                        ],
                        if (widget.distance.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.distance,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black38,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onCta,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.ctaLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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

    return _wrapVisibility(card);
  }

  Widget _wrapVisibility(Widget card) {
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
            height: _FeedScreenState._shellBottomNavHeight + bottomInset,
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
