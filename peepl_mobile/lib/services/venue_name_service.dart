import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=$latitude,$longitude&rankby=distance&type=establishment&key=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as String?;
        if (status != 'OK' && status != 'ZERO_RESULTS') {
          debugPrint('[VenueNameService] Places API status: $status');
          return null;
        }
        final results = data['results'] as List?;
        if (results == null || results.isEmpty) {
          debugPrint(
            '[VenueNameService] Places returned zero results for $latitude,$longitude',
          );
          return null;
        }
        return results.first['name'] as String?;
      }
    } catch (e) {
      debugPrint('VenueNameService: Places API error: $e');
    }
    return null;
  }

  /// @deprecated Use [resolveVenueName] instead.
  static Future<String?> getVenueName(
    double latitude,
    double longitude,
  ) =>
      resolveVenueName(latitude, longitude);
}
