import 'dart:ui' as ui;
import '../theme/peepl_app_tokens.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';
import 'location_detail_screen.dart';

class _PostPin {
  final String id;
  final String locationName;
  final double lat;
  final double lng;
  final int crowdLevel;
  final Timestamp? timestamp;
  final Map<String, dynamic> postData;

  const _PostPin({
    required this.id,
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.crowdLevel,
    this.timestamp,
    required this.postData,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _kAtlanta = LatLng(33.749, -84.388);
  static const _kGreen = Color(0xFF4CAF50);
  static const _kOrange = Color(0xFFFFA726);
  static const _kRed = Color(0xFFFF5722);

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  List<_PostPin> _allPins = [];
  List<_PostPin> _recentPosts = [];
  String _searchQuery = '';

  LatLng _mapCenter = _kAtlanta;
  double _mapZoom = 13;

  final Map<String, BitmapDescriptor> _markerBitmaps = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _buildMarkerBitmaps();

    final pos = await LocationService.getCurrentLocation();
    if (pos != null && mounted) {
      setState(() {
        _mapCenter = LatLng(pos.latitude, pos.longitude);
        _mapZoom = 14;
      });
    }

    await _loadPosts();

    if (_mapController != null && mounted) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _mapCenter, zoom: _mapZoom),
        ),
      );
    }
  }

  Future<void> _buildMarkerBitmaps() async {
    try {
      final green = await _drawMarkerBitmap(_kGreen);
      final orange = await _drawMarkerBitmap(_kOrange);
      final red = await _drawMarkerBitmap(_kRed);
      _markerBitmaps['green'] = green;
      _markerBitmaps['orange'] = orange;
      _markerBitmaps['red'] = red;
    } catch (e) {
      debugPrint('MapScreen bitmaps: $e');
    }
  }

  static Future<BitmapDescriptor> _drawMarkerBitmap(
    Color color, {
    double size = 48,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 2;

    canvas.drawCircle(
      center + const Offset(0, 1.5),
      radius,
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<void> _loadPosts() async {
    try {
      final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('location_posts')
          .limit(500);

      while (true) {
        final snap = await query.get();
        docs.addAll(snap.docs);
        if (snap.docs.length < 500) break;
        query = FirebaseFirestore.instance
            .collection('location_posts')
            .startAfterDocument(snap.docs.last)
            .limit(500);
      }

      final pins = <_PostPin>[];
      for (final doc in docs) {
        final data = doc.data();
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;

        pins.add(
          _PostPin(
            id: doc.id,
            locationName: data['locationName'] as String? ?? 'Unknown',
            lat: lat,
            lng: lng,
            crowdLevel: (data['crowdingLevel'] as num?)?.toInt() ?? 0,
            timestamp: data['timestamp'] as Timestamp?,
            postData: {'id': doc.id, ...data},
          ),
        );
      }

      pins.sort((a, b) {
        final ta = a.timestamp;
        final tb = b.timestamp;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      if (mounted) {
        setState(() {
          _allPins = pins;
          _recentPosts = pins.take(5).toList();
        });
        _rebuildMarkers();
      }
    } catch (e) {
      debugPrint('MapScreen posts: $e');
    }
  }

  List<_PostPin> get _filteredPins {
    if (_searchQuery.trim().isEmpty) return _allPins;
    final term = _searchQuery.trim().toLowerCase();
    return _allPins
        .where((p) => p.locationName.toLowerCase().contains(term))
        .toList();
  }

  void _rebuildMarkers() {
    if (!mounted) return;
    final markers = <Marker>{};

    for (final pin in _filteredPins) {
      final icon = _markerIconForLevel(pin.crowdLevel);
      markers.add(
        Marker(
          markerId: MarkerId(pin.id),
          position: LatLng(pin.lat, pin.lng),
          icon: icon,
          infoWindow: InfoWindow(
            title: pin.locationName,
            snippet: _wordLabel(pin.crowdLevel),
            onTap: () => _openDetail(pin),
          ),
        ),
      );
    }

    setState(() => _markers = markers);
  }

  BitmapDescriptor _markerIconForLevel(int level) {
    final clamped = level.clamp(0, 10);
    if (clamped <= 4) {
      return _markerBitmaps['green'] ?? BitmapDescriptor.defaultMarker;
    }
    if (clamped <= 6) {
      return _markerBitmaps['orange'] ?? BitmapDescriptor.defaultMarker;
    }
    return _markerBitmaps['red'] ?? BitmapDescriptor.defaultMarker;
  }

  static Color _colorForLevel(int level) {
    final clamped = level.clamp(0, 10);
    if (clamped <= 4) return _kGreen;
    if (clamped <= 6) return _kOrange;
    return _kRed;
  }

  static String _wordLabel(int level) {
    final value = level.clamp(0, 10);
    if (value == 0) return 'Empty';
    if (value <= 2) return 'Quiet';
    if (value <= 4) return 'Moderate';
    if (value <= 6) return 'Busy';
    if (value <= 8) return 'Crowded';
    return 'Packed';
  }

  void _openDetail(_PostPin pin) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LocationDetailScreen(postData: pin.postData),
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    LocationService.clearCache();
    final pos = await LocationService.getCurrentLocation();
    if (pos == null || _mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(pos.latitude, pos.longitude),
          zoom: 14,
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _rebuildMarkers();
  }

  static String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: PeeplAppTokens.shellNavy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Map',
          style: TextStyle(
            color: PeeplAppTokens.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: PeeplAppTokens.shellNavy,
        onPressed: _goToMyLocation,
        child: const Icon(Icons.my_location, color: PeeplAppTokens.textPrimary),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _mapCenter,
              zoom: _mapZoom,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _buildSearchBar(),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.22,
            minChildSize: 0.12,
            maxChildSize: 0.45,
            snap: true,
            snapSizes: const [0.22, 0.45],
            builder: (ctx, ctrl) => _buildRecentSheet(ctrl),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by location name...',
          hintStyle: TextStyle(color: PeeplAppTokens.card0, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: PeeplAppTokens.accentBlue),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: PeeplAppTokens.searchField,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildRecentSheet(ScrollController ctrl) {
    return Container(
      decoration: const BoxDecoration(
        color: PeeplAppTokens.textPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 14,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: ListView(
        controller: ctrl,
        padding: const EdgeInsets.only(bottom: 16),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Recent Posts',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          if (_recentPosts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No posts with location data yet',
                  style: TextStyle(color: PeeplAppTokens.card0, fontSize: 14),
                ),
              ),
            )
          else
            ..._recentPosts.map(_buildRecentRow),
        ],
      ),
    );
  }

  Widget _buildRecentRow(_PostPin pin) {
    final color = _colorForLevel(pin.crowdLevel);
    return InkWell(
      onTap: () => _openDetail(pin),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pin.locationName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_wordLabel(pin.crowdLevel)} · ${_formatTimestamp(pin.timestamp)}',
                    style: TextStyle(color: PeeplAppTokens.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
          ],
        ),
      ),
    );
  }
}
