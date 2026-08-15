import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'debug_log_service.dart';

class VenueNameService {
  VenueNameService._();

  static const String _apiKey = 'AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8';

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

  static String? _nonEmpty(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Returns a stored venue-style name from post fields, never an address.
  static String? storedVenueName(Map<String, dynamic> post) {
    for (final key in ['venueName', 'businessName', 'locationName']) {
      final raw = _nonEmpty(post[key]?.toString());
      if (raw == null || looksLikeAddress(raw)) continue;
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

  /// Returns the nearest establishment name from Google Places Nearby Search,
  /// or null if no result or on any error.
  static Future<String?> resolveVenueName(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$latitude,$longitude'
        '&radius=100'
        '&type=establishment'
        '&key=$_apiKey',
      );

      debugPrint('[VenueNameService] requesting: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      await DebugLogService.log('VENUE_NAME', 'places_response', data: {
        'status_code': response.statusCode,
        'body': response.body.substring(0, response.body.length.clamp(0, 500)),
        'latitude': latitude,
        'longitude': longitude,
      });

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as String?;
      final results = json['results'] as List<dynamic>?;

      if (status != 'OK' || results == null || results.isEmpty) return null;

      return results.first['name'] as String?;
    } catch (e) {
      await DebugLogService.log('VENUE_NAME', 'places_error', data: {'error': e.toString()});
      return null;
    }
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
