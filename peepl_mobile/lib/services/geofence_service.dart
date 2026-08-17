import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:geofence_service/geofence_service.dart';
import 'package:geolocator/geolocator.dart' as geo;

import 'debug_log_service.dart';
import 'notification_service.dart';
import 'places_venue_detector.dart';

// FIRESTORE COMPOSITE INDEXES — see also NotificationService header comment.
// onPeepCreatedCrowdAlert: location_follows (locationId+alertsEnabled,
//   locationName+alertsEnabled).
class PeeplGeofenceService {
  PeeplGeofenceService._();
  static final PeeplGeofenceService instance = PeeplGeofenceService._();

  final GeofenceService _geofenceService = GeofenceService.instance.setup(
    interval: 20000,
    accuracy: 100,
    loiteringDelayMs: 120000,
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
      _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
      _geofenceService.addLocationChangeListener(_onLocationChanged);
      _geofenceService.addActivityChangeListener(_onActivityChanged);
      _geofenceService.addStreamErrorListener(_onError);
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
      }

      await DebugLogService.log(
        'GEOFENCE',
        'geofence_loaded',
        data: {
          'venueCount': geofences.length,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

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
    // ENTER is ignored to avoid drive-by prompts; DWELL fires after
    // [loiteringDelayMs] (~2 min) while still inside the registered geofence.
    if (geofenceStatus != GeofenceStatus.DWELL) return;

    final venueName = _locationNames[geofence.id];
    if (venueName == null) return;

    debugPrint(
      '[PeeplGeofenceService] Registry dwell complete for $venueName (${geofence.id})',
    );
    await DebugLogService.log(
      'GEOFENCE',
      'registry_dwell_complete',
      data: {
        'locationId': geofence.id,
        'venueName': venueName,
      },
    );

    await NotificationService.instance.handleVenueEntry(
      venueName: venueName,
      venueId: geofence.id,
      lat: location.latitude,
      lng: location.longitude,
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
