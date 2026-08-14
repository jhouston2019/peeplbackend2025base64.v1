import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

/// Resolves a human-readable place label from coordinates using on-device
/// reverse geocoding only. No network calls, no Firebase.
class LocationLabelService {
  LocationLabelService._();

  static Future<String> resolve(double lat, double lng) async {
    final label = await _resolvePlatform(lat, lng);
    if (label != null && label.isNotEmpty) return label;
    return 'Current location';
  }

  static Future<String?> _resolvePlatform(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final name = _clean(place.name);
      final street = _clean(place.street);
      final thoroughfare = _clean(place.thoroughfare);
      final subThoroughfare = _clean(place.subThoroughfare);
      final subLocality = _clean(place.subLocality);
      final locality = _clean(place.locality);
      final region = _clean(place.administrativeArea);

      if (name != null &&
          name.isNotEmpty &&
          name != street &&
          name != thoroughfare) {
        return name;
      }

      final line1 = street ??
          [subThoroughfare, thoroughfare]
              .whereType<String>()
              .where((part) => part.isNotEmpty)
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
      debugPrint('[LocationLabelService] geocode failed: $e');
      return null;
    }
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
