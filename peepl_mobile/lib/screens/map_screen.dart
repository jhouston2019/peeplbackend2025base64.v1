import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';
import '../widgets/crowd_dot_ring_meter.dart';

// ─── Data models ──────────────────────────────────────────────────────────────

class _VenuePin {
  final String locationName;
  final double lat;
  final double lng;
  final int crowdLevel;
  final double? distanceM;
  final Map<String, dynamic> postData;

  const _VenuePin({
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.crowdLevel,
    this.distanceM,
    required this.postData,
  });
}

class _DealPin {
  final String id;
  final String venueName;
  final double lat;
  final double lng;
  final String dealText;
  final dynamic endDate; // Timestamp

  const _DealPin({
    required this.id,
    required this.venueName,
    required this.lat,
    required this.lng,
    required this.dealText,
    this.endDate,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Atlanta, GA — used when location is unavailable
  static const _kAtlanta = LatLng(33.749, -84.388);

  static const _kInitialCamera = CameraPosition(
    target: _kAtlanta,
    zoom: 13,
  );

  // ── Map ───────────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  // ── Data ──────────────────────────────────────────────────────────────────────
  List<_VenuePin> _venuePins = [];
  List<_DealPin> _dealPins = [];

  // ── Marker bitmaps (level 1–10 + deal) ───────────────────────────────────────
  final Map<int, BitmapDescriptor> _levelBitmaps = {};
  BitmapDescriptor? _dealMarker;

  // ── User location ─────────────────────────────────────────────────────────────
  double? _userLat;
  double? _userLng;

  // ── Route args (optional center override) ─────────────────────────────────────
  double? _argLat;
  double? _argLng;
  bool _didRouteInit = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didRouteInit) {
      _didRouteInit = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _argLat = (args['lat'] as num?)?.toDouble();
        _argLng = (args['lng'] as num?)?.toDouble();
      }
      _init();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ── Init pipeline ─────────────────────────────────────────────────────────────
  Future<void> _init() async {
    await _buildMarkerBitmaps();

    final pos = await LocationService.getCurrentLocation();
    if (pos != null && mounted) {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
    }

    // Center map: route args > user location > Atlanta default
    final centerLat = _argLat ?? _userLat;
    final centerLng = _argLng ?? _userLng;
    if (centerLat != null && centerLng != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(centerLat, centerLng), zoom: 13),
        ),
      );
    }

    await Future.wait([_loadCrowdPins(), _loadDealPins()]);
  }

  // ── Marker bitmaps ────────────────────────────────────────────────────────────
  Future<void> _buildMarkerBitmaps() async {
    try {
      final futures = <Future<BitmapDescriptor>>[];
      for (var level = 1; level <= 10; level++) {
        futures.add(
          _drawCircleMarker(color: _crowdColor(level), label: level.toString()),
        );
      }
      futures.add(_drawDealMarker());

      final bitmaps = await Future.wait(futures);
      for (var i = 0; i < 10; i++) {
        _levelBitmaps[i + 1] = bitmaps[i];
      }
      _dealMarker = bitmaps[10];
    } catch (e) {
      debugPrint('MapScreen bitmaps: $e');
    }
  }

  static Future<BitmapDescriptor> _drawCircleMarker({
    required Color color,
    required String label,
    double size = 54,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final c = Offset(size / 2, size / 2);
    final r = size / 2 - 2;

    // Shadow
    canvas.drawCircle(
      c + const Offset(0, 1.5),
      r,
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Fill
    canvas.drawCircle(c, r, Paint()..color = color);
    // White border
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Level number
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> _drawDealMarker({double size = 52}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final c = Offset(size / 2, size / 2);
    final r = size / 2 - 2;

    canvas.drawCircle(
      c + const Offset(0, 1.5),
      r,
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFD700));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: '★',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // ── Data loading ──────────────────────────────────────────────────────────────
  Future<void> _loadCrowdPins() async {
    try {
      final twoHoursAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 2)),
      );
      final snap = await FirebaseFirestore.instance
          .collection('location_posts')
          .where('timestamp', isGreaterThan: twoHoursAgo)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      // Group by venue — keep most recent post per venue
      final byVenue = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        final data = {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};
        final name = data['locationName'] as String? ?? '';
        if (name.isEmpty) continue;
        byVenue.putIfAbsent(name, () => data);
      }

      final pins = <_VenuePin>[];
      for (final entry in byVenue.entries) {
        final post = entry.value;
        final lat = (post['latitude'] as num?)?.toDouble();
        final lng = (post['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;

        double? distM;
        if (_userLat != null && _userLng != null) {
          distM = _haversineM(_userLat!, _userLng!, lat, lng);
        }

        pins.add(_VenuePin(
          locationName: entry.key,
          lat: lat,
          lng: lng,
          crowdLevel: (post['crowdingLevel'] as num?)?.toInt() ?? 0,
          distanceM: distM,
          postData: post,
        ));
      }

      if (mounted) setState(() => _venuePins = pins);
      _rebuildMarkers();
    } catch (e) {
      debugPrint('MapScreen crowd pins: $e');
    }
  }

  Future<void> _loadDealPins() async {
    try {
      final now = Timestamp.now();
      final snap = await FirebaseFirestore.instance
          .collection('native_ads')
          .where('isActive', isEqualTo: true)
          .where('endDate', isGreaterThan: now)
          .limit(20)
          .get();

      final pins = <_DealPin>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        // native_ads may store coordinates directly
        final lat =
            (data['lat'] as num?)?.toDouble() ??
            (data['latitude'] as num?)?.toDouble();
        final lng =
            (data['lng'] as num?)?.toDouble() ??
            (data['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;

        final venues =
            List<String>.from(data['targetLocations'] as List? ?? []);
        pins.add(_DealPin(
          id: doc.id,
          venueName: venues.isNotEmpty
              ? venues.first
              : (data['title'] as String? ?? ''),
          lat: lat,
          lng: lng,
          dealText: data['title'] as String? ?? '',
          endDate: data['endDate'],
        ));
      }

      if (mounted) setState(() => _dealPins = pins);
      _rebuildMarkers();
    } catch (e) {
      debugPrint('MapScreen deal pins: $e');
    }
  }

  // ── Marker assembly ───────────────────────────────────────────────────────────
  void _rebuildMarkers() {
    if (!mounted) return;
    final markers = <Marker>{};

    for (final pin in _venuePins) {
      final lvl = pin.crowdLevel == 0
          ? 0
          : pin.crowdLevel.clamp(1, 10) as int;
      final icon = _levelBitmaps[lvl] ?? BitmapDescriptor.defaultMarker;
      markers.add(Marker(
        markerId: MarkerId('v_${pin.locationName}'),
        position: LatLng(pin.lat, pin.lng),
        icon: icon,
        infoWindow: InfoWindow.noText,
        onTap: () => _showCrowdSheet(pin),
      ));
    }

    final dealIcon = _dealMarker;
    if (dealIcon != null) {
      for (final deal in _dealPins) {
        markers.add(Marker(
          markerId: MarkerId('d_${deal.id}'),
          position: LatLng(deal.lat, deal.lng),
          icon: dealIcon,
          infoWindow: InfoWindow.noText,
          onTap: () => _showDealSheet(deal),
        ));
      }
    }

    setState(() => _markers = markers);
  }

  // ── Camera helpers ────────────────────────────────────────────────────────────
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    final centerLat = _argLat ?? _userLat;
    final centerLng = _argLng ?? _userLng;
    if (centerLat != null && centerLng != null) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(centerLat, centerLng), zoom: 13),
        ),
      );
    }
  }

  Future<void> _goToMyLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (pos == null || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(pos.latitude, pos.longitude),
          zoom: 14,
        ),
      ),
    );
  }

  // ── Bottom sheets (marker taps) ───────────────────────────────────────────────
  void _showCrowdSheet(_VenuePin pin) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CrowdDotRingMeter(level: pin.crowdLevel, size: 76),
            const SizedBox(height: 12),
            Text(
              pin.locationName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (pin.distanceM != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatDist(pin.distanceM!),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/venue',
                      arguments: pin.postData);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2244EE),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('View Venue',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDealSheet(_DealPin deal) {
    final countdown = _dealCountdown(deal.endDate);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎟️', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(
              deal.venueName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              deal.dealText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            if (countdown.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  countdown,
                  style: const TextStyle(
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/deal_claimed',
                      arguments: {
                        'dealId': deal.id,
                        'venueName': deal.venueName,
                      });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Claim Deal',
                    style: TextStyle(
                        color: Colors.black87, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nearby sort ───────────────────────────────────────────────────────────────
  List<_VenuePin> _nearbyVenues() {
    final sorted = List<_VenuePin>.from(_venuePins);
    sorted.sort((a, b) {
      final da = a.distanceM;
      final db = b.distanceM;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return sorted;
  }

  // ── Static helpers ────────────────────────────────────────────────────────────
  static Color _crowdColor(int level) {
    if (level >= 9) return const Color(0xFFD32F2F); // PACKED – red
    if (level >= 7) return const Color(0xFF1565C0); // BUSY – blue
    if (level >= 4) return const Color(0xFFEF6C00); // MODERATE – orange
    return const Color(0xFF2E7D32); // LIGHT – green
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

  static String _dealCountdown(dynamic endDate) {
    if (endDate is! Timestamp) return '';
    final diff = endDate.toDate().difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inHours > 0) {
      return 'Ends in ${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    return 'Ends in ${diff.inMinutes}m';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Map',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Full-screen map ────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: _kInitialCamera,
            onMapCreated: _onMapCreated,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // ── Search bar (top) ───────────────────────────────────────────────
          Positioned(
            top: 10,
            left: 12,
            right: 60,
            child: _buildSearchBar(),
          ),

          // ── My Location button ─────────────────────────────────────────────
          Positioned(
            top: 10,
            right: 10,
            child: _buildLocationFAB(),
          ),

          // ── Legend (bottom-right, above sheet) ─────────────────────────────
          Positioned(
            right: 10,
            bottom: 180,
            child: _buildLegend(),
          ),

          // ── Persistent bottom sheet ────────────────────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.20,
            minChildSize: 0.10,
            maxChildSize: 0.62,
            snap: true,
            snapSizes: const [0.20, 0.62],
            builder: (ctx, ctrl) => _buildSheetContent(ctrl),
          ),
        ],
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
          context, '/search_results', arguments: ''),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search, color: Color(0xFF2244EE), size: 20),
            const SizedBox(width: 8),
            Text(
              'Search venues...',
              style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ── My Location FAB ───────────────────────────────────────────────────────────
  Widget _buildLocationFAB() {
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: Colors.white,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _goToMyLocation,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.my_location, color: Color(0xFF2244EE), size: 20),
        ),
      ),
    );
  }

  // ── Legend ────────────────────────────────────────────────────────────────────
  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22000000),
              blurRadius: 6,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendRow(const Color(0xFFD32F2F), 'PACKED'),
          _legendRow(const Color(0xFF1565C0), 'BUSY'),
          _legendRow(const Color(0xFFEF6C00), 'MODERATE'),
          _legendRow(const Color(0xFF2E7D32), 'LIGHT'),
          const SizedBox(height: 3),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 3),
          _legendRow(const Color(0xFFFFD700), '★ Deal', star: true),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label, {bool star = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A)),
          ),
        ],
      ),
    );
  }

  // ── Bottom sheet ──────────────────────────────────────────────────────────────
  Widget _buildSheetContent(ScrollController ctrl) {
    final nearby = _nearbyVenues();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
              color: Color(0x28000000),
              blurRadius: 14,
              offset: Offset(0, -3))
        ],
      ),
      child: CustomScrollView(
        controller: ctrl,
        slivers: [
          // Handle + header
          SliverToBoxAdapter(
            child: Column(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      const Text(
                        'Nearby Venues',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Spacer(),
                      Text(
                        '${nearby.length} spot${nearby.length == 1 ? '' : 's'}',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Horizontal chips — 3 nearest venues
          if (nearby.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: math.min(3, nearby.length),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) => _buildVenueChip(nearby[i]),
                ),
              ),
            ),

          if (nearby.isNotEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Full list
          if (nearby.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No recent peeps nearby',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 14),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildNearbyRow(nearby[i]),
                childCount: nearby.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildVenueChip(_VenuePin pin) {
    final color = _crowdColor(pin.crowdLevel);
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/venue',
          arguments: pin.postData),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              pin.locationName,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyRow(_VenuePin pin) {
    final color = _crowdColor(pin.crowdLevel);
    final dist = pin.distanceM != null ? _formatDist(pin.distanceM!) : null;
    return InkWell(
      onTap: () =>
          Navigator.pushNamed(context, '/venue', arguments: pin.postData),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  pin.crowdLevel.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pin.locationName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dist != null)
                    Text(
                      dist,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 11),
                    ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
