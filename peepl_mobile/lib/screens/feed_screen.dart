import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:math' show atan2, cos, pi, sin, sqrt;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../notifiers/active_filter_notifier.dart';
import '../constants/local_deals.dart';
import '../constants/national_brand_ads.dart';
import '../services/ad_cadence_service.dart';
import '../services/geofence_service.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';
import '../utils/crowd_display_mapper.dart';
import '../widgets/home/editorial_feed_layout.dart';
import '../widgets/home/feed_loading_skeleton.dart';
import '../widgets/home/happening_now_ticker.dart';
import '../widgets/home/organic_crowd_card.dart';
import '../widgets/home/peepl_home_header.dart';
import '../widgets/home/peepl_home_tokens.dart';
import '../widgets/home/quick_filter_row.dart';
import '../widgets/home/peepl_bottom_navigation.dart';
import '../widgets/home/sponsored_native_card.dart';
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

/// Legacy screen-local tokens retained for error/loading states only.
class _T {
  static const navy = PeeplHomeTokens.navyHeader;
  static const feedBackground = PeeplHomeTokens.feedBackground;
  static const primaryText = PeeplHomeTokens.white;
  static const secondaryText = PeeplHomeTokens.mutedWhite;
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
  List<Map<String, dynamic>> _allPosts = [];

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  String _activeFilter = 'Newest';

  List<Map<String, dynamic>> _dealBannerItems = LocalDeals.fallback
      .map((deal) => Map<String, dynamic>.from(deal))
      .toList();
  int _dealBannerIndex = 0;
  Timer? _dealRotationTimer;

  static const double _everywhereRadiusMiles = -1.0;

  double _selectedRadiusMiles = _everywhereRadiusMiles;
  double? _userLat;
  double? _userLng;
  double? _latitude;
  double? _longitude;
  String _areaLabel = 'Everywhere';
  bool _locationResolved = false;
  double? _searchedLat;
  double? _searchedLng;
  String? _searchedCityName;
  final TextEditingController _citySearchController = TextEditingController();
  List<Map<String, dynamic>> _citySuggestions = [];
  bool _isSearchingCity = false;

  static const _radiusOptions = [
    {'label': '¼ mi', 'miles': 0.25},
    {'label': '½ mi', 'miles': 0.5},
    {'label': '1 mi', 'miles': 1.0},
    {'label': '3 mi', 'miles': 3.0},
    {'label': '5 mi', 'miles': 5.0},
    {'label': '10 mi', 'miles': 10.0},
    {'label': '50 mi', 'miles': 50.0},
    {'label': '100 mi', 'miles': 100.0},
    {'label': '500 mi', 'miles': 500.0},
    {'label': '1000 mi', 'miles': 1000.0},
    {'label': 'Everywhere', 'miles': _everywhereRadiusMiles},
  ];

  static const double _localRadiusMeters = 16000.0;

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
    unawaited(
      _cadence.init().then((_) {
        if (!mounted) return;
        setState(() => _feedItems = _rebuildFeedItems());
      }),
    );
    _resolveLocation();
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
    _citySearchController.dispose();
    super.dispose();
  }

  Future<void> _resolveLocation() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null && mounted) {
        setState(() {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _locationResolved = true;
          _areaLabel = _radiusLabel(withRadiusSuffix: true);
        });
        _applyAreaFilter();
        if (!kIsWeb) {
          unawaited(_startGeofencingIfPermitted());
        }
      }
    } catch (_) {
      // no GPS — show all posts
    }
  }

  bool get _isEverywhereRadius => _selectedRadiusMiles < 0;

  String _radiusLabel({bool withRadiusSuffix = false}) {
    if (_isEverywhereRadius) return 'Everywhere';
    if (_selectedRadiusMiles == 0.25) return '¼ mi';
    if (_selectedRadiusMiles == 0.5) return '½ mi';
    if (_selectedRadiusMiles >= 1000) return '1000 mi';
    final miles = _selectedRadiusMiles % 1 == 0
        ? '${_selectedRadiusMiles.toInt()}'
        : '$_selectedRadiusMiles';
    return withRadiusSuffix ? '$miles mi radius' : '$miles mi';
  }

  void _applyAreaFilter() {
    if (_isEverywhereRadius) {
      setState(
        () => _feedItems = _mergeAdsIntoFeed(_applyFilter(_allPosts)),
      );
      return;
    }

    final centerLat = _searchedLat ?? _userLat;
    final centerLng = _searchedLng ?? _userLng;
    if (centerLat == null || centerLng == null) {
      setState(
        () => _feedItems = _mergeAdsIntoFeed(_applyFilter(_allPosts)),
      );
      return;
    }
    final radiusKm = _selectedRadiusMiles * 1.60934;
    final filtered = _allPosts.where((post) {
      final lat = (post['latitude'] as num?)?.toDouble();
      final lng = (post['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return true;
      return _haversineKm(centerLat, centerLng, lat, lng) <= radiusKm;
    }).toList();
    setState(() => _feedItems = _mergeAdsIntoFeed(_applyFilter(filtered)));
  }

  Future<void> _searchCity(String query) async {
    if (query.trim().length < 3) {
      setState(() => _citySuggestions = []);
      return;
    }
    setState(() => _isSearchingCity = true);
    try {
      final encoded = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=$encoded'
        '&key=AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8',
      );
      final response = await http.get(url);
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final results = (data['results'] as List).take(5).map((r) {
          return {
            'name': r['formatted_address'] as String,
            'lat': (r['geometry']['location']['lat'] as num).toDouble(),
            'lng': (r['geometry']['location']['lng'] as num).toDouble(),
          };
        }).toList();
        setState(
          () => _citySuggestions = List<Map<String, dynamic>>.from(results),
        );
      } else {
        setState(() => _citySuggestions = []);
      }
    } catch (_) {
      setState(() => _citySuggestions = []);
    } finally {
      setState(() => _isSearchingCity = false);
    }
  }

  void _selectCity(Map<String, dynamic> city) {
    final name = city['name'] as String;
    final lat = city['lat'] as double;
    final lng = city['lng'] as double;
    setState(() {
      _searchedLat = lat;
      _searchedLng = lng;
      _searchedCityName = name;
      _citySuggestions = [];
      _citySearchController.clear();
      _areaLabel = '$name • ${_radiusLabel()}';
    });
    _applyAreaFilter();
  }

  void _resetToMyLocation() {
    setState(() {
      _searchedLat = null;
      _searchedLng = null;
      _searchedCityName = null;
      _citySearchController.clear();
      _citySuggestions = [];
      _areaLabel = _locationResolved
          ? _radiusLabel(withRadiusSuffix: true)
          : _isEverywhereRadius
              ? 'Everywhere'
              : 'Nearby';
    });
    _applyAreaFilter();
  }

  void _showAreaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _citySearchController,
                    decoration: InputDecoration(
                      hintText: 'Search city, region, or country...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _isSearchingCity
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _citySearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () {
                                    _citySearchController.clear();
                                    setSheetState(() => _citySuggestions = []);
                                  },
                                )
                              : null,
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (val) {
                      setSheetState(() {});
                      _searchCity(val).then((_) => setSheetState(() {}));
                    },
                  ),
                  if (_citySuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: _citySuggestions.map((city) {
                          return ListTile(
                            leading: const Icon(
                              Icons.location_on_outlined,
                              color: Color(0xFF1565C0),
                              size: 20,
                            ),
                            title: Text(
                              city['name'] as String,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _selectCity(city);
                            },
                            dense: true,
                          );
                        }).toList(),
                      ),
                    ),
                  if (_searchedCityName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _resetToMyLocation();
                        },
                        child: const Row(
                          children: [
                            Icon(
                              Icons.my_location,
                              size: 16,
                              color: Color(0xFF1565C0),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Use my location',
                              style: TextStyle(
                                color: Color(0xFF1565C0),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Show peeps within...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _radiusOptions.map((opt) {
                      final miles = opt['miles'] as double;
                      final label = opt['label'] as String;
                      final selected = miles == _selectedRadiusMiles;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedRadiusMiles = miles;
                            _areaLabel = _searchedCityName != null
                                ? '$_searchedCityName • $label'
                                : miles < 0
                                    ? 'Everywhere'
                                    : '$label radius';
                          });
                          _applyAreaFilter();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF1565C0)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (!_locationResolved && _searchedCityName == null)
                    Text(
                      'Enable location access to filter by distance.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
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

    final lat =
        (deal['venueLat'] as num?)?.toDouble() ??
        (deal['latitude'] as num?)?.toDouble();
    final lng =
        (deal['venueLng'] as num?)?.toDouble() ??
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
    final discount = LocalDeals.discount(deal);
    final advertiser = LocalDeals.advertiser(deal);
    if (discount.isNotEmpty && advertiser.isNotEmpty) {
      return '$discount @ $advertiser';
    }
    return [discount, advertiser]
        .where((part) => part.isNotEmpty)
        .join('  ·  ');
  }

  String _happeningNowTickerText() {
    if (_dealBannerItems.isEmpty) return '';
    final parts = <String>[];
    for (var i = 0; i < _dealBannerItems.length && i < 5; i++) {
      final index = (_dealBannerIndex + i) % _dealBannerItems.length;
      final text = _dealBannerText(_dealBannerItems[index]);
      if (text.isNotEmpty) parts.add(text);
    }
    return parts.join('  •  ');
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

    posts.removeWhere((p) => (p['imageUrl'] ?? '').toString().trim().isEmpty);

    if (!mounted) return;
    setState(() {
      _posts = posts;
      _allPosts = posts;
      _isLoading = false;
    });
    _applyAreaFilter();
  }

  List<Map<String, dynamic>> _rebuildFeedItems() {
    if (_isEverywhereRadius) {
      return _mergeAdsIntoFeed(_applyFilter(_allPosts));
    }

    final centerLat = _searchedLat ?? _userLat;
    final centerLng = _searchedLng ?? _userLng;
    if (centerLat == null || centerLng == null) {
      return _mergeAdsIntoFeed(_applyFilter(_allPosts));
    }
    final radiusKm = _selectedRadiusMiles * 1.60934;
    final filtered = _allPosts.where((post) {
      final lat = (post['latitude'] as num?)?.toDouble();
      final lng = (post['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return true;
      return _haversineKm(centerLat, centerLng, lat, lng) <= radiusKm;
    }).toList();
    return _mergeAdsIntoFeed(_applyFilter(filtered));
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
      final ad = Map<String, dynamic>.from(pool[adIndex % pool.length]);
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
          nextAdThreshold =
              _peepCardsBeforeAdPattern[patternIndex %
                  _peepCardsBeforeAdPattern.length];
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
    await _resolveLocation();
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
    final a =
        sin(dphi / 2) * sin(dphi / 2) +
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
    return _haversine(userLat, userLng, lat.toDouble(), lng.toDouble());
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  double _haversineMiles(double lat1, double lon1, double lat2, double lon2) {
    const double radiusMiles = 3958.8;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
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

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PeeplHomeTokens.shellNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        const filters = ['Newest', 'Nearby', 'Local', 'Region'];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Feed filters',
                  style: TextStyle(
                    color: PeeplHomeTokens.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...filters.map((filter) {
                  return ValueListenableBuilder<String>(
                    valueListenable: activeFilterNotifier,
                    builder: (context, active, _) {
                      final selected = active == filter;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          filter,
                          style: TextStyle(
                            color: PeeplHomeTokens.white,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check,
                                color: PeeplHomeTokens.yellow,
                              )
                            : null,
                        onTap: () {
                          activeFilterNotifier.value = filter;
                          Navigator.pop(sheetContext);
                        },
                      );
                    },
                  );
                }),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Map',
                    style: TextStyle(color: PeeplHomeTokens.white),
                  ),
                  trailing: const Icon(
                    Icons.map_outlined,
                    color: PeeplHomeTokens.white,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.pushNamed(context, '/map');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _waitLabel(Map<String, dynamic> post) {
    final wait = post['waitTime'];
    if (wait == null || '$wait'.trim().isEmpty) return null;
    return 'Wait $wait';
  }

  Widget _buildOrganicCard(
    Map<String, dynamic> post, {
    required OrganicCardSize size,
    double? marginHorizontal,
  }) {
    final name = _displayName(post['locationName']?.toString());
    return OrganicCrowdCard(
      imageUrl: (post['imageUrl'] ?? '').toString(),
      name: name,
      crowdData: CrowdDisplayMapper.fromPost(post),
      distanceLabel: _distanceLabel(post),
      waitLabel: _waitLabel(post),
      size: size,
      marginHorizontal: marginHorizontal,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LocationDetailScreen(postData: post)),
      ),
    );
  }

  Widget _buildSponsoredCard(Map<String, dynamic> item) {
    final content = _feedCardContentFromAd(item);
    final offerLine = content.tagline.isNotEmpty
        ? content.tagline
        : (item['headline'] ?? item['title'] ?? '').toString();
    return SponsoredNativeCard(
      name: content.name,
      tagline: content.tagline,
      offerLine: offerLine,
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

  Widget _buildEditorialRow(EditorialFeedRow row) {
    switch (row.kind) {
      case EditorialRowKind.featuredOrganic:
        return _buildOrganicCard(
          row.items.first,
          size: OrganicCardSize.featured,
        );
      case EditorialRowKind.halfOrganicPair:
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PeeplHomeTokens.cardHorizontalMargin,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildOrganicCard(
                  row.items[0],
                  size: OrganicCardSize.half,
                  marginHorizontal: 0,
                ),
              ),
              const SizedBox(width: PeeplHomeTokens.halfCardGap),
              Expanded(
                child: _buildOrganicCard(
                  row.items[1],
                  size: OrganicCardSize.half,
                  marginHorizontal: 0,
                ),
              ),
            ],
          ),
        );
      case EditorialRowKind.sponsored:
        return _buildSponsoredCard(row.items.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplHomeTokens.feedBackground,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeLeft: true,
        removeRight: true,
        child: Column(
          children: [
            _buildHomeShellHeader(),
            Expanded(child: _buildFeedContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeShellHeader() {
    final topInset = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: PeeplHomeTokens.shellNavy,
      child: Padding(
        padding: EdgeInsets.only(top: topInset + 4, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PeeplHomeHeader(
              areaLabel: _areaLabel,
              onLocationTap: _showAreaPicker,
              onProfileTap: () => Navigator.pushNamed(context, '/profile'),
              onMenuTap: () => Navigator.pushNamed(context, '/settings'),
              onPostTap: () => Navigator.pushNamed(context, '/post'),
              onRequestPeepTap: () => Navigator.pushNamed(context, '/request-peep'),
            ),
            QuickFilterRow(
              onDealsTap: () => Navigator.pushNamed(context, '/deals'),
              onMapTap: () {
                activeFilterNotifier.value = 'Map';
                Navigator.pushNamed(context, '/map');
              },
              onMoreTap: _showFilterSheet,
              onRegionTap: _showAreaPicker,
            ),
            HappeningNowTicker(
              text: _happeningNowTickerText(),
              onTap: () => Navigator.pushNamed(context, '/deals'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedContent() {
    if (_isLoading) {
      return const FeedLoadingSkeleton();
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

    final items = _feedItems;

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No peeps yet. Be the first.',
          style: TextStyle(color: _T.secondaryText, fontSize: 15),
        ),
      );
    }

    final rows = EditorialFeedLayout.rowsFromItems(items);

    return RefreshIndicator(
      color: PeeplHomeTokens.yellow,
      backgroundColor: PeeplHomeTokens.feedBackground,
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < rows.length - 1
                  ? PeeplHomeTokens.rowVerticalGap
                  : 0,
            ),
            child: SizedBox(
              key: ValueKey('feed_row_$index'),
              height: EditorialFeedLayout.rowHeight(row),
              child: _buildEditorialRow(row),
            ),
          );
        },
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
    final destination =
        (ad['ctaUrl'] ?? ad['landingUrl'] ?? ad['destinationUrl'] ?? '')
            .toString()
            .trim();
    final isDummy = ad['isDummy'] == true;

    if (tapKind == 'card') {
      unawaited(
        _adsService.recordAdCardTap(
          adId,
          uid,
          feedPlacement: placement,
          advertiserId: advertiserId.isEmpty ? null : advertiserId,
        ),
      );
    } else {
      unawaited(
        _adsService.recordAdCtaTap(
          adId,
          uid,
          feedPlacement: placement,
          advertiserId: advertiserId.isEmpty ? null : advertiserId,
        ),
      );
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
      SnackBar(content: Text('$headline (demo ad)'), backgroundColor: _T.navy),
    );
  }

  _FeedCardContent _feedCardContentFromAd(Map<String, dynamic> ad) {
    final advertiser =
        (ad['advertiser'] ??
                ad['brandName'] ??
                ad['advertiserName'] ??
                ad['merchantName'] ??
                ad['headline'] ??
                ad['title'] ??
                '')
            .toString();
    final headline = (ad['headline'] ?? ad['title'] ?? 'Sponsored offer')
        .toString();
    final rawCta = (ad['cta'] ?? ad['ctaText'])?.toString().trim();
    final ctaText = (rawCta != null && rawCta.isNotEmpty)
        ? rawCta
        : _normalizeSponsorCta(rawCta);
    final adId = (ad['id'] ?? '').toString();
    final placement = (ad['feedPlacement'] as num?)?.toInt();
    final advertiserId =
        (ad['advertiserId'] ?? ad['advertiserName'] ?? ad['advertiser'] ?? '')
            .toString();
    final name = advertiser.isNotEmpty ? advertiser : headline;
    final tagline =
        (ad['tagline'] ??
                ad['subline'] ??
                ad['headline'] ??
                ad['bodyText'] ??
                '')
            .toString();
    final distance = (ad['distance'] ?? '').toString();
    final accentColor = Color((ad['accentColor'] as int?) ?? 0xFF1565C0);
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
        unawaited(
          _adsService.recordAdImpression(
            adId,
            _sponsorUserId(),
            feedPlacement: placement,
            advertiserId: advertiserId.isEmpty ? null : advertiserId,
          ),
        );
      },
      onViewable: () {
        unawaited(
          _adsService.recordAdViewability(
            adId,
            _sponsorUserId(),
            feedPlacement: placement,
            advertiserId: advertiserId.isEmpty ? null : advertiserId,
          ),
        );
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

/// Debug/web preview host — mirrors [MainShell] bottom navigation shell.
class FeedPreviewHost extends StatelessWidget {
  const FeedPreviewHost({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplHomeTokens.feedBackground,
      body: Column(
        children: [
          const Expanded(child: FeedScreen()),
          PeeplBottomNavigation(
            onExploreTap: () {},
            onSearchTap: () {},
            onPostTap: () {},
            onAlertsTap: () {},
            onProfileTap: () {},
          ),
        ],
      ),
    );
  }
}
