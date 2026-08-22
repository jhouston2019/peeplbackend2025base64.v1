import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import 'debug_log_service.dart';

class VenueNameService {
  VenueNameService._();

  static const String _apiKey = 'AIzaSyAROeS73A4uhjNjZx_mMbqUnW99MCrv31o';

  static const _nearbyRadiiMeters = [100, 200, 300];

  /// Venues farther than this from the GPS pin are ignored — prevents picking
  /// unrelated businesses or distant attractions (e.g. a farm 2 km away).
  static const _maxVenueDistanceMeters = 200.0;

  static const _preferredPlaceTypes = {
    'tourist_attraction',
    'amusement_park',
    'museum',
    'stadium',
    'park',
    'point_of_interest',
    'establishment',
  };

  static final RegExp _coordinatePair = RegExp(
    r'^-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?$',
  );

  static final RegExp _streetAddress = RegExp(
    r'\d+[^\n,]*\b(street|st|avenue|ave|road|rd|boulevard|blvd|drive|dr|lane|ln|way|court|ct|place|pl)\b',
    caseSensitive: false,
  );

  static final RegExp _leadingStreetNumber = RegExp(r'^\d+\s');

  static final Map<String, String> _resolvedCache = {};
  static final Map<String, Future<String?>> _inFlight = {};

  /// True when [value] looks like a street address or lat,lng coordinate pair.
  static bool looksLikeAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (_coordinatePair.hasMatch(trimmed)) return true;
    if (_leadingStreetNumber.hasMatch(trimmed)) return true;
    if (_streetAddress.hasMatch(trimmed)) return true;
    return false;
  }

  /// True when [value] is not useful as a venue label (address, city name, etc.).
  static bool isWeakVenueName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    if (trimmed == 'Current location' ||
        trimmed == 'this location' ||
        trimmed == 'Unknown Venue' ||
        trimmed == 'Unknown Location') {
      return true;
    }
    return looksLikeAddress(trimmed);
  }

  static String? _nonEmpty(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Returns a stored venue-style name from post fields, never an address.
  static String? storedVenueName(Map<String, dynamic> post) {
    for (final key in ['venueName', 'businessName', 'locationName']) {
      final raw = _nonEmpty(post[key]?.toString());
      if (raw == null || isWeakVenueName(raw)) continue;
      return raw.split(',').first.trim();
    }
    return null;
  }

  /// Address-only fallback when no venue name is available.
  static String? addressFallback(Map<String, dynamic> post) {
    for (final key in ['address', 'formattedAddress', 'locationName']) {
      final raw = _nonEmpty(post[key]?.toString());
      if (raw == null) continue;
      final first = raw.split(',').first.trim();
      if (first.isNotEmpty) return first;
    }
    return null;
  }

  static String _cacheKey(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(5)}_${longitude.toStringAsFixed(5)}';

  static Future<String?> _resolveCached(double latitude, double longitude) {
    final key = _cacheKey(latitude, longitude);
    final cached = _resolvedCache[key];
    if (cached != null) return Future.value(cached);

    final pending = _inFlight[key];
    if (pending != null) return pending;

    final future = resolveVenueName(latitude, longitude).then((resolved) {
      if (resolved != null && resolved.isNotEmpty) {
        _resolvedCache[key] = resolved;
      }
      _inFlight.remove(key);
      return resolved;
    });
    _inFlight[key] = future;
    return future;
  }

  /// Venue name for display: resolves via Places when needed; address only if
  /// no venue name can be found.
  static Future<String> displayNameForPost(Map<String, dynamic> post) async {
    final stored = storedVenueName(post);
    if (stored != null) return stored;

    final lat = (post['latitude'] as num?)?.toDouble();
    final lng = (post['longitude'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      final resolved = await _resolveCached(lat, lng);
      if (resolved != null && resolved.isNotEmpty) return resolved;
    }

    return addressFallback(post) ?? 'Unknown Venue';
  }

  /// Returns the best establishment name near [latitude]/[longitude], trying
  /// multiple Nearby Search radii and Text Search before giving up.
  static Future<String?> resolveVenueName(
    double latitude,
    double longitude,
  ) async {
    try {
      for (final radius in _nearbyRadiiMeters) {
        final name = await _bestNearbyName(latitude, longitude, radius);
        if (name != null) return name;
      }

      return await _textSearchVenueName(latitude, longitude);
    } catch (e) {
      await DebugLogService.log('VENUE_NAME', 'places_error', data: {
        'error': e.toString(),
      });
      return null;
    }
  }

  static Future<String?> _bestNearbyName(
    double latitude,
    double longitude,
    int radiusMeters,
  ) async {
    final results = await _nearbyResults(
      latitude,
      longitude,
      radiusMeters: radiusMeters,
    );
    if (results.isEmpty) return null;

    String? bestName;
    var bestScore = -9999;

    for (final result in results) {
      final name = result['name'] as String?;
      if (name == null || isWeakVenueName(name)) continue;
      if (await _isLocalityName(name, latitude, longitude)) continue;

      final distance = _resultDistanceMeters(result, latitude, longitude);
      if (distance != null && distance > _maxVenueDistanceMeters) continue;

      final score = _scorePlaceResult(result, latitude, longitude);
      if (score > bestScore) {
        bestScore = score;
        bestName = name;
      }
    }

    return bestName;
  }

  static int _scorePlaceResult(
    Map<String, dynamic> result,
    double latitude,
    double longitude,
  ) {
    final types = (result['types'] as List?)?.cast<String>() ?? const [];
    var score = 0;

    for (final type in types) {
      if (_preferredPlaceTypes.contains(type)) score += 12;
      if (type == 'locality' || type == 'political' || type == 'route') {
        score -= 40;
      }
    }

    final name = (result['name'] as String?)?.trim() ?? '';
    if (name.contains(' ')) score += 6;

    final geometry = result['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    final lat = (location?['lat'] as num?)?.toDouble();
    final lng = (location?['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      final distance = _haversineMeters(latitude, longitude, lat, lng);
      score -= (distance / 10).round();
    }

    return score;
  }

  static double? _resultDistanceMeters(
    Map<String, dynamic> result,
    double latitude,
    double longitude,
  ) {
    final geometry = result['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    final lat = (location?['lat'] as num?)?.toDouble();
    final lng = (location?['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return _haversineMeters(latitude, longitude, lat, lng);
  }

  static Future<List<Map<String, dynamic>>> _nearbyResults(
    double latitude,
    double longitude, {
    required int radiusMeters,
  }) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=$latitude,$longitude'
      '&radius=$radiusMeters'
      '&type=establishment'
      '&key=$_apiKey',
    );

    debugPrint('[VenueNameService] requesting: $url');

    try {
      final response =
          await http.get(url).timeout(const Duration(seconds: 10));

      await DebugLogService.log('VENUE_NAME', 'places_response', data: {
        'status_code': response.statusCode,
        'body': response.body.substring(0, response.body.length.clamp(0, 500)),
        'latitude': latitude,
        'longitude': longitude,
        'radius': radiusMeters,
      });

      if (response.statusCode != 200) return const [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as String?;
      final results = json['results'] as List<dynamic>?;
      if (status != 'OK' || results == null || results.isEmpty) {
        return const [];
      }

      return results.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[VenueNameService] _nearbyResults error: $e');
      return const [];
    }
  }

  static Future<String?> _textSearchVenueName(
    double latitude,
    double longitude,
  ) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/textsearch/json'
      '?query=${Uri.encodeComponent('point of interest')}'
      '&location=$latitude,$longitude'
      '&radius=${_maxVenueDistanceMeters.round()}'
      '&key=$_apiKey',
    );

    try {
      final response =
          await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as String?;
      final results = json['results'] as List<dynamic>?;
      if (status != 'OK' || results == null || results.isEmpty) return null;

      String? bestName;
      var bestScore = -9999;

      for (final raw in results) {
        final result = raw as Map<String, dynamic>;
        final name = result['name'] as String?;
        if (name == null || isWeakVenueName(name)) continue;
        if (await _isLocalityName(name, latitude, longitude)) continue;

        final distance = _resultDistanceMeters(result, latitude, longitude);
        if (distance != null && distance > _maxVenueDistanceMeters) continue;

        final score = _scorePlaceResult(result, latitude, longitude);
        if (score > bestScore) {
          bestScore = score;
          bestName = name;
        }
      }

      return bestName;
    } catch (e) {
      debugPrint('[VenueNameService] _textSearchVenueName error: $e');
      return null;
    }
  }

  static Future<bool> _isLocalityName(
    String name,
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return false;

      final place = placemarks.first;
      final candidates = [
        place.locality,
        place.subLocality,
        place.administrativeArea,
        place.name,
      ]
          .whereType<String>()
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty);

      return candidates.contains(name.trim().toLowerCase());
    } catch (_) {
      return false;
    }
  }

  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Returns lat/lng for a street address or place name via Google Geocoding API.
  static Future<({double latitude, double longitude})?> geocodeAddress(
    String address,
  ) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(trimmed)}'
        '&key=$_apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as String?;
      if (status != 'OK') {
        debugPrint('[VenueNameService] Geocode status: $status');
        return null;
      }

      final results = json['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final geometry = results.first['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = (location?['lat'] as num?)?.toDouble();
      final lng = (location?['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      return (latitude: lat, longitude: lng);
    } catch (e) {
      debugPrint('[VenueNameService] geocodeAddress error: $e');
      return null;
    }
  }

  /// @deprecated Use [resolveVenueName] instead.
  static Future<String?> getVenueName(
    double latitude,
    double longitude,
  ) =>
      resolveVenueName(latitude, longitude);
}
