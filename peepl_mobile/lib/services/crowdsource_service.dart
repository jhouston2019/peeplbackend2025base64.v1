import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'growth_analytics_service.dart';

const _kUsersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

/// Result of creating a crowdsource request and waiting for Cloud Function delivery.
class CrowdsourceDeliveryResult {
  const CrowdsourceDeliveryResult({
    required this.requestId,
    required this.status,
    this.targetCount,
    this.sentCount,
  });

  final String requestId;
  final String status;
  final int? targetCount;
  final int? sentCount;

  bool get delivered =>
      status == 'sent' && (sentCount ?? 0) > 0;

  String get userMessage {
    switch (status) {
      case 'sent':
        return 'Request sent! Someone at that location has been notified.';
      case 'no_targets':
        return 'No one is checked in there yet. They\'ll be notified when someone arrives.';
      case 'no_fcm_tokens':
        return 'We found people there but notifications are off on their device.';
      case 'error':
        return 'Could not send — location coordinates are missing.';
      case 'pending':
        return 'Request submitted. Waiting for delivery…';
      default:
        return 'Request submitted.';
    }
  }
}

/// Canonical crowdsource request/response service (Phase 7A).
class CrowdsourceService {
  CrowdsourceService._();
  static final CrowdsourceService instance = CrowdsourceService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static bool isValidCoordinate(double latitude, double longitude) {
    if (!latitude.isFinite || !longitude.isFinite) return false;
    if (latitude == 0 && longitude == 0) return false;
    if (latitude.abs() > 90 || longitude.abs() > 180) return false;
    return true;
  }

  /// Resolves coordinates from recent posts or the locations registry.
  Future<({double latitude, double longitude})?> resolveCoordinates(
    String locationName,
  ) async {
    final trimmed = locationName.trim();
    if (trimmed.isEmpty) return null;

    try {
      final postsSnap = await _db
          .collection('location_posts')
          .where('locationName', isEqualTo: trimmed)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (postsSnap.docs.isNotEmpty) {
        final data = postsSnap.docs.first.data();
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null && isValidCoordinate(lat, lng)) {
          return (latitude: lat, longitude: lng);
        }
      }
    } catch (e) {
      debugPrint('[CrowdsourceService] resolveCoordinates posts: $e');
    }

    try {
      final locSnap = await _db
          .collection('locations')
          .where('locationName', isEqualTo: trimmed)
          .limit(1)
          .get();
      if (locSnap.docs.isNotEmpty) {
        final data = locSnap.docs.first.data();
        final lat =
            (data['latitude'] as num?)?.toDouble() ??
            (data['lat'] as num?)?.toDouble();
        final lng =
            (data['longitude'] as num?)?.toDouble() ??
            (data['lng'] as num?)?.toDouble();
        if (lat != null && lng != null && isValidCoordinate(lat, lng)) {
          return (latitude: lat, longitude: lng);
        }
      }
    } catch (e) {
      debugPrint('[CrowdsourceService] resolveCoordinates locations: $e');
    }

    return null;
  }

  /// Creates a top-level [crowdsource_requests] document using the canonical schema.
  Future<String> createRequest({
    required String requestedBy,
    required String locationName,
    required double latitude,
    required double longitude,
    String? message,
    String source = 'unknown',
    String? postAuthorId,
    double radiusKm = 1,
  }) async {
    final trimmedName = locationName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(locationName, 'locationName', 'is required');
    }

    var lat = latitude;
    var lng = longitude;
    if (!isValidCoordinate(lat, lng)) {
      final resolved = await resolveCoordinates(trimmedName);
      if (resolved == null) {
        throw ArgumentError(
          'Could not find coordinates for "$trimmedName". '
          'Pick a location from the list or post a peep there first.',
        );
      }
      lat = resolved.latitude;
      lng = resolved.longitude;
    }

    String? fcmToken;
    try {
      final userDoc =
          await _db.collection(_kUsersCollection).doc(requestedBy).get();
      fcmToken = userDoc.data()?['fcmToken'] as String?;
    } catch (e) {
      debugPrint('[CrowdsourceService] FCM token lookup error: $e');
    }

    final requestRef = _db.collection('crowdsource_requests').doc();
    final requestId = requestRef.id;
    final expiresAt = DateTime.now().add(const Duration(hours: 1));
    final defaultMessage =
        'Someone is curious about $trimmedName, would you mind sharing a peep?';

    await requestRef.set({
      'requestId': requestId,
      'requestedBy': requestedBy,
      'requesterFcmToken': fcmToken,
      if (postAuthorId != null &&
          postAuthorId.isNotEmpty &&
          postAuthorId != requestedBy)
        'postAuthorId': postAuthorId,
      'locationName': trimmedName,
      'latitude': lat,
      'longitude': lng,
      'radiusKm': radiusKm,
      'message': message ?? defaultMessage,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': 'pending',
      'targetCount': null,
      'sentAt': null,
      'source': source,
      'fulfilled': false,
    });

    await GrowthAnalyticsService.logEvent(
      'growth_peep_requested',
      {
        'requestId': requestId,
        'locationName': trimmedName,
        'userId': requestedBy,
        'source': source,
        'radiusKm': radiusKm,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    debugPrint('[CrowdsourceService] Request $requestId for $trimmedName ($source)');
    return requestId;
  }

  /// Creates a request and waits for the Cloud Function to set delivery status.
  Future<CrowdsourceDeliveryResult> createRequestAndAwaitDelivery({
    required String requestedBy,
    required String locationName,
    required double latitude,
    required double longitude,
    String? message,
    String source = 'unknown',
    String? postAuthorId,
    double radiusKm = 1,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final requestId = await createRequest(
      requestedBy: requestedBy,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      message: message,
      source: source,
      postAuthorId: postAuthorId,
      radiusKm: radiusKm,
    );

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final snap =
          await _db.collection('crowdsource_requests').doc(requestId).get();
      final data = snap.data();
      if (data == null) continue;

      final status = data['status'] as String? ?? 'pending';
      if (status != 'pending') {
        return CrowdsourceDeliveryResult(
          requestId: requestId,
          status: status,
          targetCount: (data['targetCount'] as num?)?.toInt(),
          sentCount: (data['sentCount'] as num?)?.toInt(),
        );
      }
    }

    return CrowdsourceDeliveryResult(
      requestId: requestId,
      status: 'pending',
    );
  }

  /// Records a single response and marks the parent request fulfilled.
  Future<void> fulfillRequest({
    required String requestId,
    required String responderId,
    required String responderUsername,
    required String postId,
    required String locationName,
    required int crowdingLevel,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final requestDoc =
          await _db.collection('crowdsource_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        debugPrint(
          '[CrowdsourceService] fulfillRequest: unknown requestId $requestId',
        );
        return;
      }

      final request = requestDoc.data()!;
      final requesterId = request['requestedBy'] as String? ??
          request['requesterId'] as String?;
      if (requesterId == null || requesterId == responderId) return;

      await _db.collection('crowdsource_responses').doc(requestId).set({
        'requestId': requestId,
        'requesterId': requesterId,
        'responderId': responderId,
        'responderUsername': responderUsername,
        'postId': postId,
        'locationName': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'crowdingLevel': crowdingLevel,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _db.collection('crowdsource_requests').doc(requestId).update({
        'fulfilled': true,
        'status': 'fulfilled',
      });

      await GrowthAnalyticsService.logEvent(
        'growth_peep_request_fulfilled',
        {
          'requestId': requestId,
          'responderId': responderId,
          'postId': postId,
          'locationName': locationName,
          'crowdingLevel': crowdingLevel,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[CrowdsourceService] fulfillRequest error: $e');
    }
  }

  /// When a user posts about a location, fulfill pending crowdsource requests.
  Future<void> fulfillMatchingRequests({
    required String postId,
    required String responderId,
    required String username,
    required String locationName,
    required double latitude,
    required double longitude,
    required int crowdingLevel,
  }) async {
    try {
      final pending = await _db
          .collection('crowdsource_requests')
          .where('locationName', isEqualTo: locationName)
          .where('fulfilled', isEqualTo: false)
          .where('status', whereIn: ['pending', 'sent'])
          .get();

      for (final doc in pending.docs) {
        final request = doc.data();
        final requesterId = request['requestedBy'] as String? ??
            request['requesterId'] as String?;
        if (requesterId == null || requesterId == responderId) continue;

        await fulfillRequest(
          requestId: doc.id,
          responderId: responderId,
          responderUsername: username,
          postId: postId,
          locationName: locationName,
          crowdingLevel: crowdingLevel,
          latitude: latitude,
          longitude: longitude,
        );
      }
    } catch (e) {
      debugPrint('[CrowdsourceService] fulfillMatchingRequests error: $e');
    }
  }

  /// Active (non-expired, unfulfilled) requests for a venue name.
  Stream<QuerySnapshot<Map<String, dynamic>>> getActiveRequestsForLocation(
    String locationName,
  ) {
    final trimmed = locationName.trim();
    if (trimmed.isEmpty) {
      return const Stream.empty();
    }

    try {
      return _db
          .collection('crowdsource_requests')
          .where('locationName', isEqualTo: trimmed)
          .where('status', whereIn: ['pending', 'sent'])
          .where('fulfilled', isEqualTo: false)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .snapshots()
          .handleError((Object e) {
        debugPrint(
          '[CrowdsourceService] getActiveRequestsForLocation stream error: $e',
        );
      });
    } catch (e) {
      debugPrint('[CrowdsourceService] getActiveRequestsForLocation error: $e');
      return const Stream.empty();
    }
  }
}
