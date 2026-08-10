import 'dart:convert';
import 'dart:math' show atan2, cos, min, pi, sin, sqrt;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'notification_service.dart';

typedef VenueMonitoredCheck = bool Function(String placeId, String venueName);

class PlacesVenueDetector {
  PlacesVenueDetector._();

  static final PlacesVenueDetector instance = PlacesVenueDetector._();

  /// Set by [PeeplGeofenceService.initialize] to avoid circular imports.
  VenueMonitoredCheck? venueMonitoredCheck;

  static const String _apiKey =
      'AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8';
  static const double _detectionRadiusMeters = 50.0;
  static const int _dwellSeconds = 60;
  static const double _movementThresholdMeters = 100.0;

  double? _lastCheckLat;
  double? _lastCheckLng;
  String? _candidateVenueId;
  String? _candidateVenueName;
  double? _candidateLat;
  double? _candidateLng;
  DateTime? _candidateSince;

  Future<void> onLocationUpdate(
    double latitude,
    double longitude,
  ) async {
    if (_lastCheckLat != null && _lastCheckLng != null) {
      final distance = _haversineDistance(
        _lastCheckLat!,
        _lastCheckLng!,
        latitude,
        longitude,
      );
      if (distance < _movementThresholdMeters) {
        await _checkDwell(latitude, longitude);
        return;
      }
    }

    _lastCheckLat = latitude;
    _lastCheckLng = longitude;
    _candidateVenueId = null;
    _candidateVenueName = null;
    _candidateSince = null;

    await _checkPosition(latitude, longitude);
  }

  Future<void> _checkPosition(
    double latitude,
    double longitude,
  ) async {
    try {
      final result = await _getNearbyVenue(latitude, longitude);
      if (result == null) return;

      final placeId = result['place_id'] as String?;
      final name = result['name'] as String?;
      if (placeId == null || name == null || name.isEmpty) return;

      if (venueMonitoredCheck?.call(placeId, name) ?? false) {
        return;
      }

      _candidateVenueId = placeId;
      _candidateVenueName = name;
      _candidateLat = latitude;
      _candidateLng = longitude;
      _candidateSince = DateTime.now();
    } catch (e) {
      debugPrint('[PlacesVenueDetector] error: $e');
    }
  }

  Future<void> _checkDwell(
    double latitude,
    double longitude,
  ) async {
    if (_candidateVenueId == null || _candidateSince == null) return;

    final dwellDuration = DateTime.now().difference(_candidateSince!);
    if (dwellDuration.inSeconds < _dwellSeconds) return;

    final venueId = _candidateVenueId!;
    final venueName = _candidateVenueName!;
    final lat = _candidateLat ?? latitude;
    final lng = _candidateLng ?? longitude;

    _candidateVenueId = null;
    _candidateVenueName = null;
    _candidateSince = null;

    await NotificationService.instance.handleGeofenceWalkIn(
      locationId: venueId,
      locationName: venueName,
      latitude: lat,
      longitude: lng,
    );

    await _upsertToLocations(venueId, venueName, lat, lng);
  }

  Future<Map<String, dynamic>?> _getNearbyVenue(
    double lat,
    double lng,
  ) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=$lat,$lng'
      '&radius=${_detectionRadiusMeters.round()}'
      '&type=establishment'
      '&key=$_apiKey',
    );
    try {
      final response =
          await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;
      return results.first as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[PlacesVenueDetector] Places API error: $e');
      return null;
    }
  }

  Future<void> _upsertToLocations(
    String placeId,
    String venueName,
    double lat,
    double lng,
  ) async {
    try {
      final slugLength = min(100, venueName.length);
      final locationId = venueName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_')
          .substring(0, slugLength);

      if (locationId.isEmpty) return;

      await FirebaseFirestore.instance.collection('locations').doc(locationId).set(
        {
          'locationName': venueName,
          'latitude': lat,
          'longitude': lng,
          'geofenceRadiusMeters': 150,
          'isActive': true,
          'placeId': placeId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastPeeped': FieldValue.serverTimestamp(),
          'peepCount': 0,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[PlacesVenueDetector] upsert error: $e');
    }
  }

  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) *
            cos(_toRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;
}
