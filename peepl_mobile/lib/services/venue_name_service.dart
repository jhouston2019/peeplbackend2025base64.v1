import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'places_api_guard.dart';

class NearbyVenue {
  const NearbyVenue({required this.placeId, required this.name});

  final String placeId;
  final String name;
}

/// Venue labels for display, plus the single Places API (New) call used at
/// post creation. Feed and every other screen read Firestore only.
class VenueNameService {
  VenueNameService._();

  static const String _apiKey = 'AIzaSyAROeS73A4uhjNjZx_mMbqUnW99MCrv31o';
  static const double _searchRadiusMeters = 20.0;
  static const _searchNearbyUrl =
      'https://places.googleapis.com/v1/places:searchNearby';

  static final RegExp _coordinatePair = RegExp(
    r'^-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?$',
  );

  static final RegExp _streetAddress = RegExp(
    r'\d+[^\n,]*\b(street|st|avenue|ave|road|rd|boulevard|blvd|drive|dr|lane|ln|way|court|ct|place|pl)\b',
    caseSensitive: false,
  );

  static final RegExp _leadingStreetNumber = RegExp(r'^\d+\s');

  static Future<NearbyVenue?>? _inFlight;

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

  static Future<String> displayNameForPostAsync(
    Map<String, dynamic> post,
  ) async =>
      labelForPost(post);

  /// The only Places API call in the app. One SearchNearby, top result only.
  /// Concurrent callers wait for this same Future — they never start another HTTP request.
  static Future<NearbyVenue?> searchNearbyTop({
    required double latitude,
    required double longitude,
  }) {
    final pending = _inFlight;
    if (pending != null) return pending;

    late final Future<NearbyVenue?> future;
    future = _searchNearbyUncached(latitude, longitude).whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    _inFlight = future;
    return future;
  }

  static Future<NearbyVenue?> _searchNearbyUncached(
    double latitude,
    double longitude,
  ) async {
    if (!await PlacesApiGuard.allowRequest(reason: 'search_nearby')) {
      return null;
    }

    try {
      final response = await http
          .post(
            Uri.parse(_searchNearbyUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _apiKey,
              'X-Goog-FieldMask': 'places.id,places.displayName',
            },
            body: jsonEncode({
              'maxResultCount': 1,
              'rankPreference': 'POPULARITY',
              'locationRestriction': {
                'circle': {
                  'center': {
                    'latitude': latitude,
                    'longitude': longitude,
                  },
                  'radius': _searchRadiusMeters,
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
          '[VenueNameService] searchNearby status=${response.statusCode}',
        );
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final places = json['places'] as List<dynamic>?;
      if (places == null || places.isEmpty) return null;

      final place = places.first as Map<String, dynamic>;
      final placeId = _nonEmpty(place['id']?.toString());
      final displayName = place['displayName'] as Map<String, dynamic>?;
      final name = _nonEmpty(displayName?['text']?.toString());
      if (placeId == null || name == null) return null;

      return NearbyVenue(placeId: placeId, name: name);
    } catch (e) {
      debugPrint('[VenueNameService] searchNearby error: $e');
      return null;
    }
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
}
