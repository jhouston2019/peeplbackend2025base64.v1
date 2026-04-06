import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/ad_cadence_service.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';
import '../widgets/ad_card.dart';
import '../widgets/crowd_dot_ring_meter.dart';

// ─── Mode enum ────────────────────────────────────────────────────────────────
enum _Mode { nearMe, newCity, specificVenue }

// ─── Screen ───────────────────────────────────────────────────────────────────

class GetPeepsScreen extends StatefulWidget {
  const GetPeepsScreen({super.key});

  @override
  State<GetPeepsScreen> createState() => _GetPeepsScreenState();
}

class _GetPeepsScreenState extends State<GetPeepsScreen> {
  // ── Mode ─────────────────────────────────────────────────────────────────────
  _Mode _mode = _Mode.nearMe;

  // ── Controllers ───────────────────────────────────────────────────────────────
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _venueCtrl = TextEditingController();
  Timer? _debounce;

  // ── User location ─────────────────────────────────────────────────────────────
  double? _userLat;
  double? _userLng;

  // ── Ads ───────────────────────────────────────────────────────────────────────
  final NativeAdsService _adsService = NativeAdsService();
  final AdCadenceService _cadence = AdCadenceService();
  List<Map<String, dynamic>> _ads = [];

  // ── Mode 1 — Near Me ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _nearMeVenues = [];
  bool _nearMeLoading = false;
  String? _nearMeError;

  // ── Mode 2 — New City ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _cityVenues = [];
  bool _cityLoading = false;
  String _cityQueried = '';
  bool _citySearched = false;

  // ── Mode 3 — Specific Venue ───────────────────────────────────────────────────
  List<Map<String, dynamic>> _venueResults = [];
  bool _venueLoading = false;
  String _venueTerm = '';

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadNearMe();
    _initAds();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cityCtrl.dispose();
    _venueCtrl.dispose();
    super.dispose();
  }

  // ── Ads ───────────────────────────────────────────────────────────────────────
  Future<void> _initAds() async {
    await _cadence.init();
    try {
      final ads =
          await _adsService.getAdsForFeed(context: 'get_peeps', limit: 3);
      if (mounted) setState(() => _ads = ads);
    } catch (e) {
      debugPrint('GetPeepsScreen ads: $e');
    }
  }

  // ── Mode 1 loading ────────────────────────────────────────────────────────────
  Future<void> _loadNearMe({bool refresh = false}) async {
    if (_nearMeLoading) return;
    setState(() {
      _nearMeLoading = true;
      _nearMeError = null;
    });
    try {
      if (refresh) LocationService.clearCache();
      final pos = await LocationService.getCurrentLocation();
      if (mounted) {
        _userLat = pos?.latitude;
        _userLng = pos?.longitude;
      }

      final snap = await FirebaseFirestore.instance
          .collection('location_posts')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      final venues = _groupByVenue(snap.docs);

      if (_userLat != null && _userLng != null) {
        for (final v in venues) {
          final lat = (v['latitude'] as num?)?.toDouble();
          final lng = (v['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null && !(lat == 0 && lng == 0)) {
            v['_distanceM'] = _haversineM(_userLat!, _userLng!, lat, lng);
          }
        }
        venues.sort((a, b) {
          final da = a['_distanceM'] as double?;
          final db = b['_distanceM'] as double?;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
      }

      if (mounted) setState(() {
        _nearMeVenues = venues;
        _nearMeLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _nearMeError = e.toString();
        _nearMeLoading = false;
      });
    }
  }

  // ── Mode 2 loading ────────────────────────────────────────────────────────────
  Future<void> _searchCity(String city) async {
    final term = city.trim();
    if (term.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _cityLoading = true;
      _cityQueried = term;
      _citySearched = true;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('location_posts')
          .where('city', isGreaterThanOrEqualTo: term)
          .where('city', isLessThanOrEqualTo: '$term\uf8ff')
          .orderBy('city')
          .limit(50)
          .get();
      if (mounted) setState(() {
        _cityVenues = _groupByVenue(snap.docs);
        _cityLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _cityVenues = [];
        _cityLoading = false;
      });
      debugPrint('GetPeepsScreen city search: $e');
    }
  }

  // ── Mode 3 loading ────────────────────────────────────────────────────────────
  void _onVenueTyped(String value) {
    _debounce?.cancel();
    final term = value.trim();
    setState(() => _venueTerm = term);
    if (term.isEmpty) {
      setState(() => _venueResults = []);
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 450), () => _searchVenues(term));
  }

  Future<void> _searchVenues(String term) async {
    setState(() => _venueLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('location_posts')
          .where('locationName', isGreaterThanOrEqualTo: term)
          .where('locationName', isLessThanOrEqualTo: '$term\uf8ff')
          .orderBy('locationName')
          .limit(30)
          .get();
      if (mounted) setState(() {
        _venueResults = _groupByVenue(snap.docs);
        _venueLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _venueResults = [];
        _venueLoading = false;
      });
      debugPrint('GetPeepsScreen venue search: $e');
    }
  }

  // ── Refresh ───────────────────────────────────────────────────────────────────
  Future<void> _onRefresh() async {
    switch (_mode) {
      case _Mode.nearMe:
        await _loadNearMe(refresh: true);
      case _Mode.newCity:
        if (_cityQueried.isNotEmpty) await _searchCity(_cityQueried);
      case _Mode.specificVenue:
        if (_venueTerm.isNotEmpty) await _searchVenues(_venueTerm);
    }
  }

  // ── Mode switch ───────────────────────────────────────────────────────────────
  void _setMode(_Mode mode) {
    if (_mode == mode) return;
    _debounce?.cancel();
    setState(() {
      _mode = mode;
      if (mode == _Mode.nearMe && _nearMeVenues.isEmpty && !_nearMeLoading) {
        _loadNearMe();
      }
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _groupByVenue(List<QueryDocumentSnapshot> docs) {
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
    if (c.contains('mall') || c.contains('grocery')) {
      return const LinearGradient(
          colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)]);
    }
    return const LinearGradient(
        colors: [Color(0xFF2244EE), Color(0xFF1565C0)]);
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: switch (_mode) {
                _Mode.nearMe => _buildNearMeList(),
                _Mode.newCity => _buildNewCityList(),
                _Mode.specificVenue => _buildSpecificVenueList(),
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: const Color(0xFF2244EE),
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Find Peeps',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ModePill(
                label: 'Near Me',
                selected: _mode == _Mode.nearMe,
                onTap: () => _setMode(_Mode.nearMe),
              ),
              const SizedBox(width: 6),
              _ModePill(
                label: 'New City',
                selected: _mode == _Mode.newCity,
                onTap: () => _setMode(_Mode.newCity),
              ),
              const SizedBox(width: 6),
              _ModePill(
                label: 'Specific Venue',
                selected: _mode == _Mode.specificVenue,
                onTap: () => _setMode(_Mode.specificVenue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Mode lists ────────────────────────────────────────────────────────────────
  Widget _buildNearMeList() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        if (_nearMeLoading)
          const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_nearMeError != null)
          _buildErrorWidget('Could not load nearby peeps. Pull to retry.')
        else ...[
          _buildSectionHeader(
            'What\'s happening near you',
            count: _nearMeVenues.length,
          ),
          if (_nearMeVenues.isEmpty)
            _buildEmptyWidget('No recent peeps found near you.'),
          ..._nearMeVenues.map(_buildVenueCard),
          _buildAdSlot(),
        ],
      ],
    );
  }

  Widget _buildNewCityList() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        _buildSearchField(
          controller: _cityCtrl,
          hint: 'Enter a city...',
          icon: Icons.location_city_outlined,
          onChanged: (_) => setState(() {}),
          onSubmitted: _searchCity,
          onClear: () => setState(() {
            _cityCtrl.clear();
            _cityVenues = [];
            _citySearched = false;
            _cityQueried = '';
          }),
        ),
        if (_cityLoading)
          const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_citySearched) ...[
          _buildSectionHeader(
            _cityVenues.isEmpty
                ? 'No Peeps found in $_cityQueried'
                : 'Near $_cityQueried',
            count: _cityVenues.isEmpty ? null : _cityVenues.length,
          ),
          if (_cityVenues.isEmpty)
            _buildEmptyWidget(
                'Try a different city name or check the spelling.'),
          ..._cityVenues.map(_buildVenueCard),
          if (_cityVenues.isNotEmpty) _buildAdSlot(),
        ] else
          _buildHintWidget(
            icon: Icons.location_city_outlined,
            text: 'Enter a city name and press Search',
          ),
      ],
    );
  }

  Widget _buildSpecificVenueList() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        _buildSearchField(
          controller: _venueCtrl,
          hint: 'Search for a venue...',
          icon: Icons.search,
          onChanged: _onVenueTyped,
          onClear: () {
            _venueCtrl.clear();
            _onVenueTyped('');
          },
        ),
        if (_venueLoading)
          const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_venueTerm.isNotEmpty) ...[
          _buildSectionHeader(
            _venueResults.isEmpty
                ? 'No venues found for "$_venueTerm"'
                : 'Matching "$_venueTerm"',
            count: _venueResults.isEmpty ? null : _venueResults.length,
          ),
          if (_venueResults.isEmpty)
            _buildEmptyWidget('Try a different name or partial spelling.'),
          ..._venueResults.map(_buildVenueCard),
          if (_venueResults.isNotEmpty) _buildAdSlot(),
        ] else
          _buildHintWidget(
            icon: Icons.storefront_outlined,
            text: 'Start typing to search for a venue',
          ),
      ],
    );
  }

  // ── UI building blocks ────────────────────────────────────────────────────────
  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    VoidCallback? onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: controller,
        textInputAction: onSubmitted != null
            ? TextInputAction.search
            : TextInputAction.done,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF2244EE), size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon:
                      const Icon(Icons.clear, size: 18, color: Colors.grey),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF2244EE), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text, {int? count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          if (count != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:
                    const Color(0xFF2244EE).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count venue${count == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Color(0xFF2244EE),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVenueCard(Map<String, dynamic> venue) {
    final name = venue['locationName'] as String? ?? 'Unknown Venue';
    final imageUrl = venue['imageUrl'] as String? ?? '';
    final crowdLevel = (venue['crowdingLevel'] as num?)?.toInt() ?? 0;
    final distM = venue['_distanceM'] as double?;
    final peepCount = (venue['peepCount'] as int?) ?? 1;
    final category = venue['venueType'] as String?;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/venue', arguments: venue),
      child: Container(
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background — image with gradient fallback
              if (imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: _categoryGradient(category)),
                  ),
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: _categoryGradient(category)),
                ),
              // Readability overlay: left-to-right dark fade
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xCC000000), Color(0x55000000)],
                  ),
                ),
              ),
              // Top-right: crowd ring
              Positioned(
                top: 4,
                right: 8,
                child: CrowdDotRingMeter(level: crowdLevel, size: 38),
              ),
              // Bottom-left: venue name
              Positioned(
                left: 10,
                bottom: 8,
                right: 62,
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 4,
                          color: Colors.black87),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Bottom-right: distance + peep count
              Positioned(
                right: 8,
                bottom: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (distM != null)
                      Text(
                        _formatDist(distM),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      '$peepCount ${peepCount == 1 ? 'peep' : 'peeps'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 10,
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

  Widget _buildAdSlot() {
    if (_ads.isEmpty) return const SizedBox.shrink();
    final ad = _ads.first;
    final adId = ad['id'] as String? ?? '';
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: AdCard(
        ad: ad,
        onImpression: () => _adsService.recordAdImpression(adId, uid),
        onTap: () => _adsService.recordAdClick(adId, uid),
      ),
    );
  }

  Widget _buildEmptyWidget(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 32),
      child: Column(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 32),
      child: Column(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildHintWidget({required IconData icon, required String text}) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mode pill ────────────────────────────────────────────────────────────────

class _ModePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: selected ? 0.0 : 0.5),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? const Color(0xFF2244EE) : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
