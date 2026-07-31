import 'dart:math' as math;
import '../theme/peepl_app_tokens.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/ad_cadence_service.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';
import '../widgets/ad_card.dart';
import '../widgets/crowd_dot_ring_meter.dart';

// ─── Sort options ─────────────────────────────────────────────────────────────
enum _SortMode { distance, crowdDesc, mostRecent }

extension _SortModeLabel on _SortMode {
  String get label {
    switch (this) {
      case _SortMode.distance:
        return 'Distance';
      case _SortMode.crowdDesc:
        return 'Crowd Level (high → low)';
      case _SortMode.mostRecent:
        return 'Most Recent';
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class SearchResultsScreen extends StatefulWidget {
  /// Optional: pass [query] directly; otherwise resolved from route arguments.
  final String? query;

  const SearchResultsScreen({super.key, this.query});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  String _query = '';
  String _locationLabel = 'your area';

  List<Map<String, dynamic>> _raw = []; // deduplicated venue rows
  bool _loading = false;
  String? _error;

  double? _userLat;
  double? _userLng;

  _SortMode _sortMode = _SortMode.distance;

  final NativeAdsService _adsService = NativeAdsService();
  final AdCadenceService _cadence = AdCadenceService();
  List<Map<String, dynamic>> _ads = [];

  bool _didInit = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _query = widget.query ??
          (ModalRoute.of(context)?.settings.arguments as String?) ??
          '';
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    await _initAds();
    await _fetch();
  }

  Future<void> _initAds() async {
    await _cadence.init();
    final pos = await LocationService.getCurrentLocation();
    if (pos != null && mounted) {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
    }
    try {
      final ads = await _adsService.getAdsForFeed(
        context: 'discover',
        userLat: _userLat,
        userLng: _userLng,
        limit: 5,
      );
      if (mounted) setState(() => _ads = ads);
    } catch (e) {
      debugPrint('SearchResultsScreen ads: $e');
    }
  }

  Future<void> _fetch() async {
    if (_query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('location_posts')
          .where('locationName', isGreaterThanOrEqualTo: _query)
          .where('locationName', isLessThanOrEqualTo: '$_query\uf8ff')
          .orderBy('locationName')
          .limit(40)
          .get();

      final venues = _groupByVenue(snap.docs);

      // Compute distances and extract city label from first result
      String? city;
      for (final v in venues) {
        if (city == null) {
          city = v['city'] as String?;
        }
        final lat = (v['latitude'] as num?)?.toDouble();
        final lng = (v['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null && !(lat == 0 && lng == 0)) {
          if (_userLat != null && _userLng != null) {
            v['_distanceM'] = _haversineM(_userLat!, _userLng!, lat, lng);
          }
        }
      }

      if (city != null && city.isNotEmpty) _locationLabel = city;

      if (mounted) setState(() {
        _raw = venues;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
      debugPrint('SearchResultsScreen fetch: $e');
    }
  }

  // ── Sorting & ad injection ────────────────────────────────────────────────────
  List<Map<String, dynamic>> _sorted() {
    final list = List<Map<String, dynamic>>.from(_raw);
    switch (_sortMode) {
      case _SortMode.distance:
        list.sort((a, b) {
          final da = a['_distanceM'] as double?;
          final db = b['_distanceM'] as double?;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
      case _SortMode.crowdDesc:
        list.sort((a, b) {
          final ca = (a['crowdingLevel'] as num?)?.toInt() ?? 0;
          final cb = (b['crowdingLevel'] as num?)?.toInt() ?? 0;
          return cb.compareTo(ca);
        });
      case _SortMode.mostRecent:
        list.sort((a, b) {
          final ta = a['timestamp'];
          final tb = b['timestamp'];
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          final ms = (dynamic t) => t is int
              ? t
              : t is Timestamp
                  ? t.toDate().millisecondsSinceEpoch
                  : (t is DateTime ? t.millisecondsSinceEpoch : 0);
          return ms(tb).compareTo(ms(ta));
        });
    }
    return list;
  }

  /// Builds the display list: organic venues + sponsored ad at position 3.
  List<Map<String, dynamic>> _displayList() {
    final organic = _sorted();
    _cadence.resetForMerge(postCount: organic.length);
    if (_ads.isEmpty || organic.length < 3) return organic;

    final result = <Map<String, dynamic>>[];
    int adIndex = 0;
    for (var i = 0; i < organic.length; i++) {
      result.add(organic[i]);
      // Inject after item at index 2 (position 3) once
      if (i == 2 && adIndex < _ads.length) {
        final ad = _ads[adIndex++];
        result.add({'_isAd': true, ...ad});
      }
    }
    return result;
  }

  // ── Sort bottom sheet ─────────────────────────────────────────────────────────
  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort results',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._SortMode.values.map(
              (mode) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _sortIcon(mode),
                  color: _sortMode == mode
                      ? PeeplAppTokens.background
                      : Colors.grey,
                ),
                title: Text(
                  mode.label,
                  style: TextStyle(
                    fontWeight: _sortMode == mode
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _sortMode == mode
                        ? PeeplAppTokens.background
                        : const Color(0xFF1A1A1A),
                  ),
                ),
                trailing: _sortMode == mode
                    ? const Icon(Icons.check, color: PeeplAppTokens.background)
                    : null,
                onTap: () {
                  setState(() => _sortMode = mode);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _sortIcon(_SortMode mode) {
    switch (mode) {
      case _SortMode.distance:
        return Icons.near_me_outlined;
      case _SortMode.crowdDesc:
        return Icons.people_outline;
      case _SortMode.mostRecent:
        return Icons.access_time_outlined;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _groupByVenue(
      List<QueryDocumentSnapshot> docs) {
    final byVenue = <String, Map<String, dynamic>>{};
    final counts = <String, int>{};
    for (final doc in docs) {
      final data = {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};
      final name = data['locationName'] as String? ?? '';
      if (name.isEmpty) continue;
      byVenue.putIfAbsent(name, () => data);
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return byVenue.entries
        .map((e) => {...e.value, 'peepCount': counts[e.key] ?? 1})
        .toList();
  }

  static double _haversineM(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dl = (lat2 - lat1) * math.pi / 180;
    final dn = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dl / 2) * math.sin(dl / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dn / 2) * math.sin(dn / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static String _formatDist(double m) {
    final mi = m * 0.000621371;
    if (mi < 0.1) return '${(m * 3.28084).round()} ft';
    if (mi < 10) return '${mi.toStringAsFixed(1)} mi';
    return '${mi.round()} mi';
  }

  static LinearGradient _categoryGradient(String? category) {
    final c = (category ?? '').toLowerCase();
    if (c.contains('bar') || c.contains('brew')) {
      return const LinearGradient(
          colors: [Color(0xFF1A0535), Color(0xFF3D1A6E)]);
    }
    if (c.contains('restaurant') || c.contains('cafe')) {
      return const LinearGradient(
          colors: [Color(0xFF7B1900), Color(0xFFBF360C)]);
    }
    if (c.contains('park') || c.contains('beach')) {
      return const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)]);
    }
    if (c.contains('gym') || c.contains('spa')) {
      return const LinearGradient(
          colors: [Color(0xFF006064), Color(0xFF00838F)]);
    }
    return const LinearGradient(
        colors: [PeeplAppTokens.background, PeeplAppTokens.accentBlue]);
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: PeeplAppTokens.background,
      body: Column(
        children: [
          _buildHeader(topPad),
          _buildSubHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(double topPad) {
    return Container(
      color: PeeplAppTokens.background,
      padding: EdgeInsets.fromLTRB(0, topPad + 10, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              '"$_query"',
              style: const TextStyle(
                color: PeeplAppTokens.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Filter/sort icon
          GestureDetector(
            onTap: _showSortSheet,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort, color: PeeplAppTokens.textPrimary, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Sort',
                    style: TextStyle(
                      color: PeeplAppTokens.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader() {
    final count = _raw.length;
    final label = _loading
        ? 'Searching...'
        : '$count result${count == 1 ? '' : 's'} near $_locationLabel';
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A37CC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_raw.isEmpty) {
      return _buildEmptyState();
    }

    final items = _displayList();
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item['_isAd'] == true) return _buildSponsoredSlot(item);
        return _buildResultRow(item);
      },
    );
  }

  // ── List rows ─────────────────────────────────────────────────────────────────

  /// 3-column flex: [52px thumbnail] | [Expanded: name + meta] | [30px DotRing]
  Widget _buildResultRow(Map<String, dynamic> venue) {
    final name = venue['locationName'] as String? ?? 'Unknown Venue';
    final imageUrl = venue['imageUrl'] as String? ?? '';
    final crowdLevel = (venue['crowdingLevel'] as num?)?.toInt() ?? 0;
    final distM = venue['_distanceM'] as double?;
    final peepCount = (venue['peepCount'] as int?) ?? 1;
    final category = venue['venueType'] as String?;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/venue', arguments: venue),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: PeeplAppTokens.textPrimary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: PeeplAppTokens.textPrimary.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left: 52px gradient/image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 52,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: _categoryGradient(category)),
                        ),
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: _categoryGradient(category)),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Center: venue name + distance + peep count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (distM != null) ...[
                        Icon(Icons.near_me,
                            size: 11, color: PeeplAppTokens.card0),
                        const SizedBox(width: 2),
                        Text(
                          _formatDist(distM),
                          style: TextStyle(
                              fontSize: 11, color: PeeplAppTokens.textSecondary),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(Icons.bar_chart,
                          size: 11, color: PeeplAppTokens.card0),
                      const SizedBox(width: 2),
                      Text(
                        '$peepCount report${peepCount == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontSize: 11, color: PeeplAppTokens.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right: DotRing badge at 34px
            CrowdDotRingMeter(level: crowdLevel, size: 34),
          ],
        ),
      ),
    );
  }

  Widget _buildSponsoredSlot(Map<String, dynamic> ad) {
    final adId = ad['id'] as String? ?? '';
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'SPONSORED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: PeeplAppTokens.card0,
                letterSpacing: 0.8,
              ),
            ),
          ),
          AdCard(
            ad: ad,
            onImpression: () => _adsService.recordAdImpression(adId, uid),
            onTap: () => _adsService.recordAdClick(adId, uid),
          ),
        ],
      ),
    );
  }

  // ── Empty / error states ──────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 14),
            Text(
              'No results for "$_query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different name or browse Near Me',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: PeeplAppTokens.textSecondary),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushReplacementNamed(
                  context, '/get_peeps'),
              icon: const Icon(Icons.near_me, size: 16),
              label: const Text('Browse Near Me'),
              style: OutlinedButton.styleFrom(
                foregroundColor: PeeplAppTokens.background,
                side: const BorderSide(color: PeeplAppTokens.background),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text(
              'Something went wrong loading results.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetch,
              style: ElevatedButton.styleFrom(
                backgroundColor: PeeplAppTokens.background,
              ),
              child: const Text('Try Again',
                  style: TextStyle(color: PeeplAppTokens.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}
