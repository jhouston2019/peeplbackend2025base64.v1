import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import 'debug_log_service.dart';

class VenueNameService {
  VenueNameService._();

  static const String _apiKey = 'AIzaSyAROeS73A4uhjNjZx_mMbqUnW99MCrv31o';

  /// Venues farther than this from the GPS pin are ignored.
  static const _maxVenueDistanceMeters = 200.0;

  /// Visit-oriented place types queried with rankby=distance (closest first).
  static const _rankByDistanceTypes = [
    'restaurant',
    'bar',
    'night_club',
    'cafe',
    'bakery',
    'meal_takeaway',
    'tourist_attraction',
    'store',
  ];

  static const _excludedPlaceTypes = {
    'locality',
    'political',
    'route',
    'real_estate_agency',
    'finance',
    'insurance_agency',
    'accounting',
    'lawyer',
    'courthouse',
    'local_government_office',
    'general_contractor',
    'moving_company',
    'electrician',
    'plumber',
    'storage',
    'car_dealer',
    'car_repair',
    'gas_station',
  };

  static final _deprioritizedNamePattern = RegExp(
    r'\b(properties|property management|financial advisor|insurance|personnel|'
    r'capital management|edward jones|realty|real estate|law firm|attorney|'
    r'accounting|consulting group)\b',
    caseSensitive: false,
  );

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
    if (looksLikeAddress(trimmed)) return true;
    if (_deprioritizedNamePattern.hasMatch(trimmed)) return true;
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

  /// Venue name for display: always tries GPS resolution first so bad stored
  /// labels (e.g. a neighboring realtor) get corrected automatically.
  static Future<String> displayNameForPost(Map<String, dynamic> post) async {
    final lat = (post['latitude'] as num?)?.toDouble();
    final lng = (post['longitude'] as num?)?.toDouble();
    if (lat != null &&
        lng != null &&
        !(lat == 0 && lng == 0) &&
        !lat.isNaN &&
        !lng.isNaN) {
      final resolved = await _resolveCached(lat, lng);
      if (resolved != null && resolved.isNotEmpty) return resolved;
    }

    final stored = storedVenueName(post);
    if (stored != null) return stored;

    return addressFallback(post) ?? 'Unknown Venue';
  }

  /// Returns the closest visitable establishment near the GPS pin.
  static Future<String?> resolveVenueName(
    double latitude,
    double longitude,
  ) async {
    try {
      final ranked = await _closestRankedVenue(latitude, longitude);
      if (ranked != null) return ranked;

      return await _resolveFromReverseGeocode(latitude, longitude);
    } catch (e) {
      await DebugLogService.log('VENUE_NAME', 'places_error', data: {
        'error': e.toString(),
      });
      return null;
    }
  }

  /// Closest eligible venue from rankby=distance queries (restaurant, bar, etc.).
  /// When two venues are within this distance, prefer the one with more reviews.
  static const _tieBreakDistanceMeters = 25.0;

  static Future<String?> _closestRankedVenue(
    double latitude,
    double longitude,
  ) async {
    String? closestName;
    double? closestDistance;
    var closestReviews = -1;

    for (final type in _rankByDistanceTypes) {
      final results = await _nearbyRankByDistance(
        latitude,
        longitude,
        type: type,
      );

      for (final result in results.take(8)) {
        if (!_isEligibleVenue(result)) continue;
        if (await _isLocalityName(
          result['name'] as String? ?? '',
          latitude,
          longitude,
        )) {
          continue;
        }

        final distance = _resultDistanceMeters(result, latitude, longitude);
        if (distance == null || distance > _maxVenueDistanceMeters) continue;

        final reviews =
            (result['user_ratings_total'] as num?)?.toInt() ?? 0;
        final isCloser = closestDistance == null || distance < closestDistance!;
        final isTieBreak =
            closestDistance != null &&
            (distance - closestDistance!).abs() <= _tieBreakDistanceMeters &&
            reviews > closestReviews;

        if (isCloser || isTieBreak) {
          closestDistance = distance;
          closestName = result['name'] as String?;
          closestReviews = reviews;
        }
      }
    }

    return closestName;
  }

  static bool _isEligibleVenue(Map<String, dynamic> result) {
    final name = result['name'] as String?;
    if (name == null || isWeakVenueName(name)) return false;

    final types = (result['types'] as List?)?.cast<String>() ?? const [];
    if (types.any(_excludedPlaceTypes.contains)) return false;

    return types.any(
      (type) =>
          _rankByDistanceTypes.contains(type) ||
          type == 'food' ||
          type == 'point_of_interest',
    );
  }

  static Future<String?> _resolveFromReverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final name = _nonEmpty(place.name);
      if (name == null || isWeakVenueName(name)) return null;

      final street = _nonEmpty(place.street);
      final thoroughfare = _nonEmpty(place.thoroughfare);
      if (name == street || name == thoroughfare) return null;

      if (await _isLocalityName(name, latitude, longitude)) return null;

      return name.split(',').first.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _nearbyRankByDistance(
    double latitude,
    double longitude, {
    required String type,
  }) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=$latitude,$longitude'
      '&rankby=distance'
      '&type=$type'
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
        'type': type,
        'rankby': 'distance',
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
      debugPrint('[VenueNameService] _nearbyRankByDistance error: $e');
      return const [];
    }
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
