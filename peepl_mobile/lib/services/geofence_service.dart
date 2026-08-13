import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;

import 'debug_log_service.dart';
import 'location_service.dart';
import 'notification_service.dart';import 'places_venue_detector.dart';

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
      debugPrint('[NativeGeofence] registerRegion called for $venueName ($venueId)');
      await DebugLogService.log(
        'GEOFENCE',
        'native_region_registered',
        data: {'venueId': venueId, 'venueName': venueName},
      );
    } catch (e) {
      debugPrint('[NativeGeofence] registerRegion failed: $e');
      await DebugLogService.log(
        'GEOFENCE',
        'native_region_failed',
        data: {'venueId': venueId, 'error': e.toString()},
      );
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
  /// Escalates to Always when possible; When-In-Use alone still enables registration.
  Future<bool> ensurePermission() async {
    if (kIsWeb) return false;
    if (_permanentlyDenied) return false;

    try {
      var permission = await geo.Geolocator.checkPermission();

      if (permission == geo.LocationPermission.denied) {
        await DebugLogService.log(
          'GEOFENCE',
          'geofence_permission_denied',
          data: {'permission': permission.name},
        );
        return false;
      }

      if (permission == geo.LocationPermission.deniedForever) {
        _permanentlyDenied = true;
        await DebugLogService.log('GEOFENCE', 'geofence_permission_denied_forever');
        return false;
      }

      if (permission == geo.LocationPermission.whileInUse) {
        // Try to escalate to Always but do not block registration on decline.
        final upgraded = await geo.Geolocator.requestPermission();
        if (upgraded == geo.LocationPermission.always) {
          permission = upgraded;
        }
      }

      if (permission == geo.LocationPermission.whileInUse ||
          permission == geo.LocationPermission.always) {
        if (permission != geo.LocationPermission.always) {
          await DebugLogService.log(
            'GEOFENCE',
            'geofence_when_in_use_only',
            data: {
              'note':
                  'Registration proceeds; background venue entry needs Always',
            },
          );
        }
        return true;
      }

      await DebugLogService.log(
        'GEOFENCE',
        'geofence_permission_insufficient',
        data: {'permission': permission.name},
      );
      return false;
    } catch (e) {
      await DebugLogService.log(
        'GEOFENCE',
        'geofence_permission_error',
        data: {'error': e.toString()},
      );
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

  /// Activates geofencing when location permission is sufficient. Idempotent.
  Future<void> start() async {
    if (kIsWeb) return;

    if (_permanentlyDenied) {
      _logDenialOnce('Geofencing permanently disabled.');
      await DebugLogService.log(
        'GEOFENCE',
        'geofence_start_blocked',
        data: {'reason': 'permanently_denied'},
      );
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
      if (!granted) {
        await DebugLogService.log(
          'GEOFENCE',
          'geofence_start_blocked',
          data: {'reason': 'permission_not_granted'},
        );
        return;
      }

      _isActive = true;
      await DebugLogService.log('GEOFENCE', 'geofence_started');
    } catch (e) {
      debugPrint('[PeeplGeofenceService] start failed (non-fatal): $e');
      await DebugLogService.log(
        'GEOFENCE',
        'geofence_start_error',
        data: {'error': e.toString()},
      );
    }
  }

  Future<void> _seedNearbyVenues() async {
    try {
      final position = await LocationService.getCurrentLocation();
      if (position == null) return;

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${position.latitude},${position.longitude}'
        '&radius=500'
        '&type=establishment'
        '&key=AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return;

      final results = json['results'] as List<dynamic>;

      for (final place in results.take(20)) {
        try {
          final placeId = place['place_id'] as String?;
          final name = place['name'] as String?;
          final lat =
              (place['geometry']?['location']?['lat'] as num?)?.toDouble();
          final lng =
              (place['geometry']?['location']?['lng'] as num?)?.toDouble();

          if (placeId == null || name == null || lat == null || lng == null) {
            continue;
          }

          final callable =
              FirebaseFunctions.instance.httpsCallable('seedLocation');
          await callable.call({
            'locationName': name,
            'latitude': lat,
            'longitude': lng,
            'crowdingLevel': 0,
            'venueId': placeId,
          });

          await _registerNativeRegion(
            venueId: placeId,
            venueName: name,
            latitude: lat,
            longitude: lng,
            radius: 150,
          );

          debugPrint('[Geofence] seeded and registered: $name');
        } catch (e) {
          debugPrint('[Geofence] failed to seed: $e');
          continue;
        }
      }
    } catch (e) {
      debugPrint('[Geofence] _seedNearbyVenues failed: $e');
    }
  }

  /// Loads venue geofences from Firestore. Requires [isActive] and signed-in user.
  Future<void> loadGeofencesFromFirestore() async {
    if (kIsWeb) return;
    if (!_isActive) {
      await DebugLogService.log(
        'GEOFENCE',
        'geofence_load_skipped',
        data: {'reason': 'not_active'},
      );
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      await DebugLogService.log(
        'GEOFENCE',
        'geofence_load_skipped',
        data: {'reason': 'not_signed_in'},
      );
      return;
    }

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

      await DebugLogService.log(
        'GEOFENCE',
        'geofence_native_registration',
        data: {
          'venueCount': geofences.length,
          'nativeRegistrationAttempted': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      try {
        await _seedNearbyVenues();
      } catch (e) {
        debugPrint('[Geofence] _seedNearbyVenues failed: $e');
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
      await DebugLogService.log(
        'GEOFENCE',
        'geofence_load_error',
        data: {'error': e.toString()},
      );
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
