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

  /// True when [value] looks like a street address or lat,lng coordinate pair.
  static bool looksLikeAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (_coordinatePair.hasMatch(trimmed)) return true;
    if (_streetAddress.hasMatch(trimmed)) return true;
    return false;
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

  /// @deprecated Use [resolveVenueName] instead.
  static Future<String?> getVenueName(
    double latitude,
    double longitude,
  ) =>
      resolveVenueName(latitude, longitude);
}
