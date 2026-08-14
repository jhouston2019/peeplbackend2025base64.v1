import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Thin singleton wrapper around Geolocator that:
///   • requests permissions exactly once per session
///   • caches the resolved [Position] in memory so subsequent callers
///     never trigger a second Geolocator call
///   • deduplicates concurrent calls via a shared [Future] — safe to call
///     from multiple screens simultaneously in [initState]
class LocationService {
  LocationService._();

  static Position? _cachedPosition;

  // If a fetch is already in flight, new callers await this same Future
  // instead of launching a duplicate Geolocator request.
  static Future<Position?>? _pendingFetch;

  /// Returns the device's current [Position], or null if location services
  /// are disabled or permission is denied.
  ///
  /// Results are cached for the session lifetime. Call [clearCache] on
  /// logout or when a fresh fix is needed (e.g. after a long background gap).
  static Future<Position?> getCurrentLocation({bool forceRefresh = false}) {
    if (forceRefresh) clearCache();
    if (_cachedPosition != null) return Future.value(_cachedPosition);
    _pendingFetch ??= _fetchLocation();
    return _pendingFetch!;
  }

  static Future<Position?> _fetchLocation() async {
    try {
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

      _cachedPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      return _cachedPosition;
    } catch (e) {
      debugPrint('LocationService: $e');
      return null;
    }
  }

  /// Force a fresh location fix on the next [getCurrentLocation] call.
  /// Call this on user logout or after returning from a long background gap.
  static void clearCache() {
    _cachedPosition = null;
    _pendingFetch = null;
  }
}
