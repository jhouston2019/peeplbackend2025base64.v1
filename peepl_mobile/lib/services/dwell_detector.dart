import 'dart:math' show atan2, cos, pi, sin, sqrt;

import 'package:flutter/foundation.dart';

/// Fired when the user has stayed within the movement threshold long enough.
/// [cellId] is a stable suppression key — not a Google Place ID.
typedef DwellArrivalCallback = void Function({
  required double lat,
  required double lng,
  required String cellId,
});

/// Universal walk-in arrival detection. No Places API, no Firestore, no naming.
class DwellDetector {
  DwellDetector._();

  static final DwellDetector instance = DwellDetector._();

  static const double movementThresholdMeters = 90.0;
  static const int dwellSeconds = 60;

  DwellArrivalCallback? onArrival;

  double? _anchorLat;
  double? _anchorLng;
  DateTime? _candidateSince;
  String? _pendingCellId;

  Future<void> onLocationUpdate(double latitude, double longitude) async {
    if (latitude.isNaN ||
        longitude.isNaN ||
        (latitude == 0 && longitude == 0)) {
      return;
    }

    if (_anchorLat == null || _anchorLng == null) {
      _setAnchor(latitude, longitude);
      return;
    }

    final distance = _haversineMeters(
      _anchorLat!,
      _anchorLng!,
      latitude,
      longitude,
    );

    if (distance >= movementThresholdMeters) {
      _setAnchor(latitude, longitude);
      return;
    }

    await _checkDwell(latitude, longitude);
  }

  void _setAnchor(double lat, double lng) {
    _anchorLat = lat;
    _anchorLng = lng;
    _candidateSince = DateTime.now();
    _pendingCellId = _cellIdFor(lat, lng);
  }

  Future<void> _checkDwell(double lat, double lng) async {
    if (_candidateSince == null || _pendingCellId == null) return;

    final elapsed = DateTime.now().difference(_candidateSince!);
    if (elapsed.inSeconds < dwellSeconds) return;

    final cellId = _pendingCellId!;
    _candidateSince = null;
    _pendingCellId = null;

    debugPrint('[DwellDetector] arrival cell=$cellId (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})');

    final callback = onArrival;
    if (callback == null) return;
    callback(lat: lat, lng: lng, cellId: cellId);
  }

  static String _cellIdFor(double lat, double lng) {
    final latKey = (lat * 1000).round();
    final lngKey = (lng * 1000).round();
    return 'dwell_${latKey}_$lngKey';
  }

  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
