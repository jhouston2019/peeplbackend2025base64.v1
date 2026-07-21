import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handles crowdsource request creation and matching responses to posts.
class CrowdsourceService {
  CrowdsourceService._();
  static final CrowdsourceService instance = CrowdsourceService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Creates a nested request document and mirrors it to the top-level
  /// collection so the existing onCrowdsourceRequest Cloud Function fires.
  Future<String?> createRequest({
    required String locationId,
    required String locationName,
    required double latitude,
    required double longitude,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      final nestedRef = _db
          .collection('crowdsource_requests')
          .doc(locationId)
          .collection('requests')
          .doc();
      final requestId = nestedRef.id;

      final data = <String, dynamic>{
        'requesterId': user.uid,
        'requesterFcmToken': token ?? '',
        'requestedBy': user.uid,
        'locationId': locationId,
        'locationName': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      };

      await nestedRef.set(data);

      // Mirror for existing Cloud Function trigger (crowdsource_requests/{requestId}).
      await _db.collection('crowdsource_requests').doc(requestId).set(data);

      debugPrint('[CrowdsourceService] Request $requestId for $locationName');
      return requestId;
    } catch (e) {
      debugPrint('[CrowdsourceService] createRequest error: $e');
      return null;
    }
  }

  /// When a user posts about a location, fulfill any pending crowdsource requests.
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
          .collectionGroup('requests')
          .where('status', isEqualTo: 'pending')
          .where('locationName', isEqualTo: locationName)
          .get();

      for (final doc in pending.docs) {
        final request = doc.data();
        final requesterId = request['requesterId'] as String?;
        if (requesterId == null || requesterId == responderId) continue;

        await _db.collection('crowdsource_responses').doc(doc.id).set({
          'requestId': doc.id,
          'requesterId': requesterId,
          'responderId': responderId,
          'responderUsername': username,
          'postId': postId,
          'locationName': locationName,
          'latitude': latitude,
          'longitude': longitude,
          'crowdingLevel': crowdingLevel,
          'timestamp': FieldValue.serverTimestamp(),
        });

        await doc.reference.update({'status': 'fulfilled'});
      }
    } catch (e) {
      debugPrint('[CrowdsourceService] fulfillMatchingRequests error: $e');
    }
  }
}
