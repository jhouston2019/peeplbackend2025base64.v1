import '../services/venue_name_service.dart';

/// Parsed launch context for post composers (Flows 1–5).
class ComposerLaunch {
  const ComposerLaunch({
    this.composerSource,
    this.locationName,
    this.placeId,
    this.latitude,
    this.longitude,
    this.fromVenueEntry = false,
    this.requestId,
  });

  final String? composerSource;
  final String? locationName;
  final String? placeId;
  final double? latitude;
  final double? longitude;
  final bool fromVenueEntry;
  final String? requestId;

  static ComposerLaunch? fromRouteArgs(Object? args) {
    if (args is! Map) return null;
    final lat = args['latitude'];
    final lng = args['longitude'];
    final hasContext = args['locationName'] != null ||
        args['fromVenueEntry'] == true ||
        args['composerSource'] != null ||
        lat is num ||
        lng is num;
    if (!hasContext) return null;

    return ComposerLaunch(
      composerSource: args['composerSource']?.toString(),
      locationName: args['locationName']?.toString(),
      placeId: args['placeId']?.toString().trim(),
      latitude: lat is num ? lat.toDouble() : null,
      longitude: lng is num ? lng.toDouble() : null,
      fromVenueEntry: args['fromVenueEntry'] == true,
      requestId: args['requestId']?.toString(),
    );
  }

  bool get hasPrefilledCoords =>
      latitude != null &&
      longitude != null &&
      !(latitude == 0 && longitude == 0);

  bool get hasLaunchContext =>
      locationName != null ||
      fromVenueEntry ||
      composerSource != null ||
      hasPrefilledCoords;

  /// Flows 2 & 3, or any launch with a known [placeId].
  bool shouldSkipPlaces() {
    if (placeId != null && placeId!.isNotEmpty) return true;
    final source = composerSource;
    if (source == 'crowdsource' || source == 'venue_tap') {
      final name = locationName?.trim() ?? '';
      return name.isNotEmpty && !VenueNameService.isWeakVenueName(name);
    }
    return false;
  }

  /// Flows 1 & 4 — one Places attempt when the composer opens.
  bool shouldCallPlaces({required bool placesAttempted}) {
    if (placesAttempted) return false;
    if (shouldSkipPlaces()) return false;
    final source = composerSource;
    return source == null || source == 'direct' || source == 'walk_in';
  }

  /// Flow 2 — open `/post` with prefilled context, zero Places calls.
  static Map<String, dynamic> crowdsourceRouteArgs({
    required String locationName,
    double? latitude,
    double? longitude,
    String? placeId,
    String? requestId,
  }) {
    return {
      'composerSource': 'crowdsource',
      'locationName': locationName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (placeId != null && placeId.isNotEmpty) 'placeId': placeId,
      if (requestId != null && requestId.isNotEmpty) 'requestId': requestId,
    };
  }

  /// Flow 3 — venue/map/explore tap, zero Places calls.
  static Map<String, dynamic> venueTapRouteArgs({
    required String locationName,
    double? latitude,
    double? longitude,
    String? placeId,
  }) {
    return {
      'composerSource': 'venue_tap',
      'locationName': locationName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (placeId != null && placeId.isNotEmpty) 'placeId': placeId,
    };
  }

  /// Flow 4 — manual composer open, one Places attempt on mount.
  static Map<String, dynamic> directRouteArgs() {
    return const {'composerSource': 'direct'};
  }
}
