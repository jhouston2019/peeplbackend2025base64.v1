import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'debug_log_service.dart';

/// Resolves a human-readable place label from coordinates.
///
/// Prefers on-device reverse geocoding (no API key) before Google REST,
/// because mobile HTTP calls are often blocked by API-key restrictions.
class LocationLabelService {
  LocationLabelService._();

  static const _placesApiKey = 'AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8';
  static const _placesSearchRadiusMeters = 200;
  static const _maxVenueDistanceMeters = 150.0;

  static Future<String> resolve(double lat, double lng) async {
    final platform = await _resolvePlatform(lat, lng);
    if (platform != null && platform.isNotEmpty) return platform;

    final venue = await _resolveNearbyVenue(lat, lng);
    if (venue != null && venue.isNotEmpty) return venue;

    final googleAddress = await _resolveGoogleGeocode(lat, lng);
    if (googleAddress != null && googleAddress.isNotEmpty) {
      return googleAddress;
    }

    // Last resort — never show raw coordinates in the UI.
    return 'Current location';
  }

  static Future<String?> _resolvePlatform(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final name = place.name?.trim();
      final street = place.street?.trim();
      final thoroughfare = place.thoroughfare?.trim();
      final subThoroughfare = place.subThoroughfare?.trim();
      final subLocality = place.subLocality?.trim();
      final locality = place.locality?.trim();
      final region = place.administrativeArea?.trim();

      // POI name from Apple (mall, park, business) when distinct from street.
      if (name != null &&
          name.isNotEmpty &&
          name != street &&
          name != thoroughfare) {
        return name;
      }

      final line1 = street ??
          [subThoroughfare, thoroughfare]
              .where((part) => part != null && part.isNotEmpty)
              .join(' ');
      if (line1.isNotEmpty) {
        final city = locality ?? subLocality;
        if (city != null && city.isNotEmpty) {
          return region != null && region.isNotEmpty
              ? '$line1, $city, $region'
              : '$line1, $city';
        }
        return line1;
      }

      final parts = <String>[
        if (subLocality != null && subLocality.isNotEmpty) subLocality,
        if (locality != null && locality.isNotEmpty) locality,
        if (region != null && region.isNotEmpty) region,
      ];
      if (parts.isEmpty) return null;
      return parts.join(', ');
    } catch (e) {
      await DebugLogService.log('LOCATION_LABEL', 'platform_geocode_error', data: {
        'error': e.toString(),
        'latitude': lat,
        'longitude': lng,
      });
      return null;
    }
  }

  static Future<String?> _resolveNearbyVenue(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=$lat,$lng'
      '&radius=$_placesSearchRadiusMeters'
      '&type=establishment'
      '&key=$_placesApiKey',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      await DebugLogService.log('LOCATION_LABEL', 'places_response', data: {
        'status_code': response.statusCode,
        'body': response.body.substring(0, response.body.length.clamp(0, 500)),
        'latitude': lat,
        'longitude': lng,
      });
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return null;

      final results = json['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      String? bestName;
      var bestDistance = double.infinity;
      for (final raw in results) {
        final place = raw as Map<String, dynamic>;
        final name = place['name'] as String?;
        if (name == null || name.trim().isEmpty) continue;

        final placeLat =
            (place['geometry']?['location']?['lat'] as num?)?.toDouble();
        final placeLng =
            (place['geometry']?['location']?['lng'] as num?)?.toDouble();
        if (placeLat == null || placeLng == null) continue;

        final distance =
            Geolocator.distanceBetween(lat, lng, placeLat, placeLng);
        if (distance <= _maxVenueDistanceMeters && distance < bestDistance) {
          bestDistance = distance;
          bestName = name.trim();
        }
      }

      // If nothing within max distance, use the first result (ranked by prominence).
      return bestName ?? (results.first as Map<String, dynamic>)['name'] as String?;
    } catch (e) {
      await DebugLogService.log('LOCATION_LABEL', 'places_error', data: {
        'error': e.toString(),
        'latitude': lat,
        'longitude': lng,
      });
      return null;
    }
  }

  static Future<String?> _resolveGoogleGeocode(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$lat,$lng'
      '&key=$_placesApiKey',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      await DebugLogService.log('LOCATION_LABEL', 'geocode_response', data: {
        'status_code': response.statusCode,
        'body': response.body.substring(0, response.body.length.clamp(0, 500)),
        'latitude': lat,
        'longitude': lng,
      });
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return null;

      final results = json['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final formatted =
          (results.first as Map<String, dynamic>)['formatted_address'] as String?;
      if (formatted == null || formatted.trim().isEmpty) return null;
      return formatted.trim();
    } catch (e) {
      await DebugLogService.log('LOCATION_LABEL', 'geocode_error', data: {
        'error': e.toString(),
        'latitude': lat,
        'longitude': lng,
      });
      return null;
    }
  }
}
