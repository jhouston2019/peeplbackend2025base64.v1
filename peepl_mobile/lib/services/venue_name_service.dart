import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VenueNameService {
  VenueNameService._();

  static const String _apiKey =
      'AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8';

  /// Returns the nearest establishment name from Google Places Nearby Search,
  /// or null if no result or on any error.
  static Future<String?> getVenueName(
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
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results.first['name'] as String?;
        }
      }
    } catch (e) {
      debugPrint('VenueNameService: Places API error: $e');
    }
    return null;
  }
}
