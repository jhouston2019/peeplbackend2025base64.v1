import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:geolocator/geolocator.dart' as geo;

import 'notification_service.dart';
import 'places_venue_detector.dart';

// FIRESTORE COMPOSITE INDEXES — see also NotificationService header comment.
// onPeepCreatedCrowdAlert: location_follows (locationId+alertsEnabled,
//   locationName+alertsEnabled).
const _nativeChannel = MethodChannel('com.peepl.geofence/native');

class PeeplGeofenceService {
  PeeplGeofenceService._();
  static final PeeplGeofenceService instance = PeeplGeofenceService._();

  final GeofenceService _geofenceService = GeofenceService.instance.setup(
    interval: 20000,
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

  bool _isActive = false;
  bool _permanentlyDenied = false;
  bool _listenersRegistered = false;
  bool _alreadyActiveLogged = false;
  bool _denialLogged = false;
  bool _firestoreErrorLogged = false;

  bool get isActive => _isActive;

  Future<void> _registerNativeRegion({
    required String venueId,
    required String venueName,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    try {
      await _nativeChannel.invokeMethod('registerRegion', {
        'venueId': venueId,
        'venueName': venueName,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
      });
    } catch (e) {
      debugPrint('[NativeGeofence] registerRegion failed: $e');
    }
  }

  bool isVenueMonitored(String placeId, String venueName) {
    return _locationNames.containsKey(placeId);
  }
  void _logDenialOnce(String message) {
    if (_denialLogged) return;
    _denialLogged = true;
    debugPrint('[PeeplGeofenceService] $message');
  }

  /// Requires When-In-Use to already be granted (feed owns that prompt).
  /// Escalates to Always for background geofencing. Never prompts cold.
  Future<bool> ensurePermission() async {
    if (kIsWeb) return false;
    if (_permanentlyDenied) return false;

    try {
      var permission = await geo.Geolocator.checkPermission();

      if (permission != geo.LocationPermission.whileInUse &&
          permission != geo.LocationPermission.always) {
        return false;
      }

      if (permission == geo.LocationPermission.always) {
        return true;
      }

      // When-In-Use granted — escalate to Always (in-context on iOS).
      permission = await geo.Geolocator.requestPermission();

      if (permission == geo.LocationPermission.always) {
        return true;
      }

      _permanentlyDenied = true;
      _logDenialOnce(
        'Always location denied — geofencing disabled.',
      );
      return false;
    } catch (_) {
      _logDenialOnce('Permission check failed — geofencing disabled.');
      return false;
    }
  }

  /// Registers listeners only. Does not request location permission.
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('[PeeplGeofenceService] Geofencing unavailable on web.');
      return;
    }

    try {
      if (_listenersRegistered) return;
      PlacesVenueDetector.instance.venueMonitoredCheck = isVenueMonitored;
      _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);      _geofenceService.addLocationChangeListener(_onLocationChanged);
      _geofenceService.addActivityChangeListener(_onActivityChanged);      _geofenceService.addStreamErrorListener(_onError);
      _listenersRegistered = true;
    } catch (e) {
      debugPrint('[PeeplGeofenceService] initialize failed (non-fatal): $e');
    }
  }

  /// Activates geofencing after Always permission. Idempotent.
  Future<void> start() async {
    if (kIsWeb) return;

    if (_permanentlyDenied) {
      _logDenialOnce('Geofencing permanently disabled.');
      return;
    }

    if (_isActive) {
      if (!_alreadyActiveLogged) {
        _alreadyActiveLogged = true;
        debugPrint('[PeeplGeofenceService] Geofencing already active.');
      }
      return;
    }

    try {
      final granted = await ensurePermission();
      if (!granted) return;

      _isActive = true;
    } catch (e) {
      debugPrint('[PeeplGeofenceService] start failed (non-fatal): $e');
    }
  }

  /// Loads venue geofences from Firestore. Requires [isActive] and signed-in user.
  Future<void> loadGeofencesFromFirestore() async {
    if (kIsWeb) return;
    if (!_isActive) return;

    if (FirebaseAuth.instance.currentUser == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('locations')
          .limit(100)
          .get();

      _locationNames.clear();
      final geofences = <Geofence>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final isActive = data['isActive'] as bool? ?? true;
        if (!isActive) continue;

        final name = data['locationName'] as String?;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();

        if (name == null || lat == null || lng == null) continue;

        final placeId = data['placeId'] as String?;
        final locationId = (placeId != null && placeId.isNotEmpty)
            ? placeId
            : doc.id;

        _locationNames[locationId] = name;
        geofences.add(
          Geofence(
            id: locationId,
            latitude: lat,
            longitude: lng,
            radius: [
              GeofenceRadius(id: 'radius_150m', length: 150),
            ],
          ),
        );

        await _registerNativeRegion(
          venueId: locationId,
          venueName: name,
          latitude: lat,
          longitude: lng,
          radius: 150,
        );
      }

      await _geofenceService.start(geofences);
      debugPrint(
        '[PeeplGeofenceService] Started with ${geofences.length} geofences.',
      );
    } catch (e) {
      if (!_firestoreErrorLogged) {
        _firestoreErrorLogged = true;
        debugPrint(
          '[PeeplGeofenceService] loadGeofencesFromFirestore error: $e',
        );
      }
    }
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

    await NotificationService.instance.handleVenueEntry(
      venueName: locationName,
      venueId: locationId,
      lat: geofence.latitude,
      lng: geofence.longitude,
    );
  }

  void _onActivityChanged(Activity prevActivity, Activity currActivity) {}

  void _onLocationChanged(Location location) {
    PlacesVenueDetector.instance.onLocationUpdate(
      location.latitude,
      location.longitude,
    );
  }

  // ignore: avoid_annotating_with_dynamic
  void _onError(dynamic error) {
    if (_permanentlyDenied) return;
    debugPrint('[PeeplGeofenceService] Error: $error');
  }

  Future<void> addGeofence(
    String locationId,
    String locationName,
    double lat,
    double lng,
  ) async {
    if (kIsWeb || !_isActive) return;

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
    _isActive = false;
  }
}
