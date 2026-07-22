import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HeatMapScreen extends StatefulWidget {
  const HeatMapScreen({super.key});

  @override
  State<HeatMapScreen> createState() => _HeatMapScreenState();
}

class _HeatMapScreenState extends State<HeatMapScreen> {
  static const _kAtlanta = LatLng(33.749, -84.388);
  static const _kGreen = Color(0xFF4CAF50);
  static const _kOrange = Color(0xFFFFA726);
  static const _kRed = Color(0xFFFF5722);

  GoogleMapController? _mapController;
  Set<Circle> _circles = {};
  bool _isLoading = true;
  LatLng _mapCenter = _kAtlanta;
  double _mapZoom = 13;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _loadUserLocation(),
      _loadLocationPosts(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUserLocation() async {
    try {
      final position = await _getCurrentPosition();
      if (position == null || !mounted) return;
      setState(() {
        _mapCenter = LatLng(position.latitude, position.longitude);
        _mapZoom = 14;
      });
    } catch (e) {
      debugPrint('HeatMapScreen location: $e');
    }
  }

  Future<Position?> _getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
  }

  Future<void> _loadLocationPosts() async {
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

      final circles = <Circle>{};
      for (final doc in docs) {
        final data = doc.data();
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;

        final level = (data['crowdingLevel'] as num?)?.toInt() ?? 0;
        final clamped = level.clamp(0, 10);
        circles.add(
          Circle(
            circleId: CircleId(doc.id),
            center: LatLng(lat, lng),
            radius: 60 + clamped * 8,
            fillColor: _colorForLevel(clamped).withValues(
              alpha: _opacityForLevel(clamped),
            ),
            strokeColor: _colorForLevel(clamped).withValues(alpha: 0.6),
            strokeWidth: 1,
          ),
        );
      }

      if (mounted) setState(() => _circles = circles);
    } catch (e) {
      debugPrint('HeatMapScreen posts: $e');
    }
  }

  Color _colorForLevel(int level) {
    if (level <= 4) return _kGreen;
    if (level <= 6) return _kOrange;
    return _kRed;
  }

  double _opacityForLevel(int level) {
    return 0.25 + (level / 10) * 0.55;
  }

  Future<void> _recenterOnUser() async {
    final position = await _getCurrentPosition();
    if (position == null || _mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        14,
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legendItem(_kGreen, 'Low'),
          _legendItem(_kOrange, 'Moderate'),
          _legendItem(_kRed, 'High'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Heat Map',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              backgroundColor: const Color(0xFF1565C0),
              onPressed: _recenterOnUser,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _mapCenter,
                    zoom: _mapZoom,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  circles: _circles,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: _buildLegend(),
                  ),
                ),
              ],
            ),
    );
  }
}
