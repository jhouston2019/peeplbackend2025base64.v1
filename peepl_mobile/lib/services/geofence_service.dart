import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:geolocator/geolocator.dart' as geo;

import 'notification_service.dart';

class PeeplGeofenceService {
  PeeplGeofenceService._();
  static final PeeplGeofenceService instance = PeeplGeofenceService._();

  final GeofenceService _geofenceService = GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    loiteringDelayMs: 60000,
    statusChangeDelayMs: 10000,
    useActivityRecognition: false,
    allowMockLocations: false,
    printDevLog: false,
    geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
  );

  /// locationId → display name (for callbacks that still need the name).
  final Map<String, String> _locationNames = {};

  Function(String locationId, String locationName, double latitude, double longitude)?
      onLocationEntered;

  Future<void> initialize() async {
    geo.LocationPermission permission =
        await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      debugPrint(
          '[PeeplGeofenceService] Location permission denied — geofencing disabled.');
      return;
    }

    _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
    _geofenceService.addActivityChangeListener(_onActivityChanged);
    _geofenceService.addStreamErrorListener(_onError);
  }

  Future<void> _onGeofenceStatusChanged(
    Geofence geofence,
    GeofenceRadius geofenceRadius,
    GeofenceStatus geofenceStatus,
    Location location,
  ) async {
    if (geofenceStatus != GeofenceStatus.ENTER) return;

    final locationId = geofence.id;
    final locationName = _locationNames[locationId] ?? locationId;

    await NotificationService.instance.handleGeofenceWalkIn(
      locationId: locationId,
      locationName: locationName,
      latitude: geofence.latitude,
      longitude: geofence.longitude,
    );

    onLocationEntered?.call(
      locationId,
      locationName,
      geofence.latitude,
      geofence.longitude,
    );
  }

  void _onActivityChanged(Activity prevActivity, Activity currActivity) {}

  // ignore: avoid_annotating_with_dynamic
  void _onError(dynamic error) {
    debugPrint('[PeeplGeofenceService] Error: $error');
  }

  Future<void> loadGeofencesFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('locations')
          .limit(100)
          .get();

      _locationNames.clear();
      final geofences = <Geofence>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['locationName'] as String?;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();

        if (name == null || lat == null || lng == null) continue;

        _locationNames[doc.id] = name;
        geofences.add(
          Geofence(
            id: doc.id,
            latitude: lat,
            longitude: lng,
            radius: [
              GeofenceRadius(id: 'radius_150m', length: 150),
            ],
          ),
        );
      }

      await _geofenceService.start(geofences);
      debugPrint(
          '[PeeplGeofenceService] Started with ${geofences.length} geofences.');
    } catch (e) {
      debugPrint('[PeeplGeofenceService] loadGeofencesFromFirestore error: $e');
    }
  }

  Future<void> addGeofence(
    String locationId,
    String locationName,
    double lat,
    double lng,
  ) async {
    try {
      _locationNames[locationId] = locationName;
      _geofenceService.addGeofence(
        Geofence(
          id: locationId,
          latitude: lat,
          longitude: lng,
          radius: [
            GeofenceRadius(id: 'radius_150m', length: 150),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[PeeplGeofenceService] addGeofence error: $e');
    }
  }

  void dispose() {
    _geofenceService.stop();
  }
}
