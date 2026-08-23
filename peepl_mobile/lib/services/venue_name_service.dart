import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import 'debug_log_service.dart';
import 'location_label_service.dart';

class VenueNameService {
  VenueNameService._();

  static const String _apiKey = 'AIzaSyAROeS73A4uhjNjZx_mMbqUnW99MCrv31o';

  /// Attach a Google Places name only when the listing is at the GPS pin.
  static const _maxVenueDistanceMeters = 25.0;

  /// Large festivals / venues can span a wide area — allow a looser match.
  static const _maxMajorEventDistanceMeters = 250.0;

  /// Stored business labels are kept when Places confirms them near the pin.
  static const _storedNameConfirmMeters = 60.0;

  /// Google often lists big events as POI/establishment only.
  static const _minMajorPoiRatings = 75;

  static const _rankByDistanceTypes = [
    'restaurant',
    'bar',
    'night_club',
    'cafe',
    'bakery',
    'meal_takeaway',
    'tourist_attraction',
    'museum',
    'stadium',
    'amusement_park',
    'park',
  ];

  static const _foodDrinkTypes = {
    'restaurant',
    'bar',
    'night_club',
    'cafe',
    'bakery',
    'meal_takeaway',
    'food',
    'tourist_attraction',
    'museum',
    'stadium',
    'amusement_park',
    'park',
  };

  static const _excludedPlaceTypes = {
    'locality',
    'political',
    'route',
    'premise',
    'subpremise',
    'street_address',
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
    'store',
    'clothing_store',
    'shoe_store',
    'home_goods_store',
    'transit_station',
    'beauty_salon',
    'hair_care',
  };

  static final _eventNamePattern = RegExp(
    r'\b(festival|fair|renfest|renaissance)\b',
    caseSensitive: false,
  );

  static final _deprioritizedNamePattern = RegExp(
    r'\b(properties|property management|financial advisor|insurance|personnel|'
    r'capital management|edward jones|realty|real estate|law firm|attorney|'
    r'accounting|consulting group|models of atlanta|click models|'
    r'resource brokers|media group|law llc)\b',
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

  static bool looksLikeAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (_coordinatePair.hasMatch(trimmed)) return true;
    if (_leadingStreetNumber.hasMatch(trimmed)) return true;
    if (_streetAddress.hasMatch(trimmed)) return true;
    return false;
  }

  static bool isWeakVenueName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    if (trimmed == 'Current location' ||
        trimmed == 'this location' ||
        trimmed == 'Unknown Venue' ||
        trimmed == 'Unknown Location' ||
        trimmed == 'Home' ||
        trimmed == 'Park' ||
        trimmed == 'the house') {
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

  static String? storedVenueName(Map<String, dynamic> post) {
    for (final key in ['venueName', 'businessName', 'locationName']) {
      final raw = _nonEmpty(post[key]?.toString());
      if (raw == null || isWeakVenueName(raw)) continue;
      return raw.split(',').first.trim();
    }
    return null;
  }

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

  /// Label saved on the post at creation time — never re-resolve from Places.
  static String labelForPost(Map<String, dynamic> post) {
    for (final key in ['venueName', 'businessName', 'locationName']) {
      final raw = _nonEmpty(post[key]?.toString());
      if (raw == null) continue;
      final first = raw.split(',').first.trim();
      if (first.isEmpty) continue;
      if (key != 'locationName' && isWeakVenueName(first)) continue;
      return first;
    }
    return addressFallback(post) ?? 'Unknown Venue';
  }

  /// Same as [labelForPost] — display must not mutate stored post labels.
  static String displayNameForPost(Map<String, dynamic> post) =>
      labelForPost(post);

  static Future<String> displayNameForPostAsync(Map<String, dynamic> post) async =>
      labelForPost(post);

  static Future<String> resolveLabelAtPin(
    double latitude,
    double longitude,
  ) async {
    final venue = await resolveVenueName(latitude, longitude);
    if (venue != null && venue.isNotEmpty) return venue;
    return LocationLabelService.resolve(latitude, longitude);
  }

  static Future<String?> resolveVenueName(
    double latitude,
    double longitude,
  ) async {
    try {
      final ranked = await _bestNearbyVenue(latitude, longitude);
      if (ranked != null) return ranked;

      return await _resolveFromReverseGeocode(latitude, longitude);
    } catch (e) {
      await DebugLogService.log('VENUE_NAME', 'places_error', data: {
        'error': e.toString(),
      });
      return null;
    }
  }

  static Future<bool> _storedNameMatchesLocation(
    String storedName,
    double latitude,
    double longitude,
  ) async {
    final query = storedName.trim();
    if (query.isEmpty) return false;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/findplacefromtext/json'
      '?input=${Uri.encodeComponent(query)}'
      '&inputtype=textquery'
      '&fields=name,geometry'
      '&locationbias=circle:${_storedNameConfirmMeters.toInt()}@$latitude,$longitude'
      '&key=$_apiKey',
    );

    try {
      final response =
          await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return false;

      final candidates = json['candidates'] as List<dynamic>? ?? const [];
      final normalizedStored = _normalizeName(query);

      for (final raw in candidates) {
        final candidate = raw as Map<String, dynamic>;
        final name = candidate['name'] as String?;
        if (name == null) continue;
        if (!_namesMatch(normalizedStored, _normalizeName(name))) continue;

        final distance = _resultDistanceMeters(candidate, latitude, longitude);
        if (distance != null && distance <= _storedNameConfirmMeters) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }

    return false;
  }

  static String _normalizeName(String value) =>
      value.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]"), '');

  static bool _namesMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;
    return false;
  }

  /// Collect nearby candidates across venue types and pick the best-scored hit.
  static Future<String?> _bestNearbyVenue(
    double latitude,
    double longitude,
  ) async {
    final seenPlaceIds = <String>{};
    final candidates = <_VenueCandidate>[];

    for (final type in _rankByDistanceTypes) {
      final results = await _nearbyRankByDistance(
        latitude,
        longitude,
        type: type,
      );
      if (results.isEmpty) continue;

      for (final result in results.take(5)) {
        final placeId = result['place_id'] as String?;
        if (placeId != null) {
          if (seenPlaceIds.contains(placeId)) continue;
          seenPlaceIds.add(placeId);
        }

        if (!_isEligibleVenue(result)) continue;

        final name = result['name'] as String?;
        if (name == null || isWeakVenueName(name)) continue;
        if (await _isLocalityName(name, latitude, longitude)) continue;

        final distance = _resultDistanceMeters(result, latitude, longitude);
        final maxDistance = _maxDistanceForResult(result);
        if (distance == null || distance > maxDistance) continue;

        candidates.add(
          _VenueCandidate(
            name: name,
            score: _scoreCandidate(result, distance),
            distance: distance,
            ratings: (result['user_ratings_total'] as num?)?.toInt() ?? 0,
            vicinity: result['vicinity'] as String?,
            types: (result['types'] as List?)?.cast<String>() ?? const [],
          ),
        );
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final distanceCmp = a.distance.compareTo(b.distance);
      if ((a.distance - b.distance).abs() > 3) return distanceCmp;
      return b.ratings.compareTo(a.ratings);
    });
    return candidates.first.name;
  }

  static double _scoreCandidate(
    Map<String, dynamic> result,
    double distanceMeters,
  ) {
    var score = distanceMeters;
    final types = (result['types'] as List?)?.cast<String>() ?? const [];

    if (types.contains('restaurant')) score -= 4;
    if (types.contains('bar')) score -= 3;
    if (types.contains('night_club')) score -= 2;
    if (types.contains('cafe')) score -= 2;
    if (types.contains('bakery')) score -= 1;
    if (types.contains('tourist_attraction')) score -= 1;
    if (types.contains('park')) score -= 1;
    if (_eventNamePattern.hasMatch(result['name'] as String? ?? '')) {
      score -= 6;
    }

    if (types.length == 1 && types.first == 'point_of_interest') {
      score += 8;
    }

    // Duplicate listings at the same address (e.g. Chopblock vs The Stag at
    // 110 Main St) — prefer the widely-reviewed canonical business.
    final ratings = (result['user_ratings_total'] as num?)?.toInt() ?? 0;
    if (ratings >= _minMajorPoiRatings &&
        (types.contains('point_of_interest') ||
            types.contains('establishment'))) {
      score -= 8;
    }
    score -= math.log(ratings + 1) * 1.5;

    return score;
  }

  static bool _isEligibleVenue(Map<String, dynamic> result) {
    final name = result['name'] as String?;
    if (name == null || isWeakVenueName(name)) return false;

    final types = (result['types'] as List?)?.cast<String>() ?? const [];
    if (types.isEmpty) return false;
    if (types.any(_excludedPlaceTypes.contains)) return false;
    if (types.any(_foodDrinkTypes.contains)) return true;

    final ratings = (result['user_ratings_total'] as num?)?.toInt() ?? 0;
    if (ratings >= _minMajorPoiRatings &&
        (types.contains('point_of_interest') ||
            types.contains('establishment'))) {
      return true;
    }

    return false;
  }

  static double _maxDistanceForResult(Map<String, dynamic> result) {
    final types = (result['types'] as List?)?.cast<String>() ?? const [];
    final name = result['name'] as String? ?? '';
    final ratings = (result['user_ratings_total'] as num?)?.toInt() ?? 0;

    if (_eventNamePattern.hasMatch(name) ||
        (ratings >= _minMajorPoiRatings &&
            (types.contains('point_of_interest') ||
                types.contains('establishment') ||
                types.contains('tourist_attraction')))) {
      return _maxMajorEventDistanceMeters;
    }

    return _maxVenueDistanceMeters;
  }

  static Future<String?> _resolveNamedEventAtLocation(
    String query,
    double latitude,
    double longitude,
  ) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || !_eventNamePattern.hasMatch(trimmed)) return null;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/findplacefromtext/json'
      '?input=${Uri.encodeComponent(trimmed)}'
      '&inputtype=textquery'
      '&fields=name,geometry'
      '&key=$_apiKey',
    );

    try {
      final response =
          await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return null;

      final candidates = json['candidates'] as List<dynamic>? ?? const [];
      for (final raw in candidates) {
        final candidate = raw as Map<String, dynamic>;
        final name = candidate['name'] as String?;
        if (name == null || isWeakVenueName(name)) continue;
        if (!_namesMatch(_normalizeName(trimmed), _normalizeName(name)) &&
            !_eventNamePattern.hasMatch(name)) {
          continue;
        }

        final distance = _resultDistanceMeters(candidate, latitude, longitude);
        if (distance != null && distance <= _maxMajorEventDistanceMeters) {
          return name;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
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

  static Future<String?> getVenueName(
    double latitude,
    double longitude,
  ) =>
      resolveVenueName(latitude, longitude);
}

class _VenueCandidate {
  const _VenueCandidate({
    required this.name,
    required this.score,
    required this.distance,
    required this.ratings,
    required this.vicinity,
    required this.types,
  });

  final String name;
  final double score;
  final double distance;
  final int ratings;
  final String? vicinity;
  final List<String> types;
}
