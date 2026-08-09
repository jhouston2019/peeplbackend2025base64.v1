import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'growth_analytics_service.dart';

const _kUsersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

/// Canonical crowdsource request/response service (Phase 7A).
class CrowdsourceService {
  CrowdsourceService._();
  static final CrowdsourceService instance = CrowdsourceService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Creates a top-level [crowdsource_requests] document using the canonical schema.
  Future<String> createRequest({
    required String requestedBy,
    required String locationName,
    required double latitude,
    required double longitude,
    String? message,
    String source = 'unknown',
    double radiusKm = 0.2,
  }) async {
    final trimmedName = locationName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(locationName, 'locationName', 'is required');
    }
    if (!latitude.isFinite || !longitude.isFinite) {
      throw ArgumentError('latitude and longitude are required');
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
      'locationName': trimmedName,
      'latitude': latitude,
      'longitude': longitude,
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
