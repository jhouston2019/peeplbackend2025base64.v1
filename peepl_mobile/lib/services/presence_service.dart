// FIRESTORE RULES NEEDED (add manually in Firebase Console):
// match /presence/{userId} {
//   allow read: if request.auth != null;
//   allow write: if request.auth != null &&
//                   request.auth.uid == userId;
// }
// match /crowdsource_requests/{docId} {
//   allow create: if request.auth != null;
//   allow read: if request.auth != null;
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PresenceService {
  PresenceService._();
  static final PresenceService _instance = PresenceService._();
  static PresenceService get instance => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Simple 6-char geohash sufficient for 150m queries.
  String _geohash(double lat, double lng) {
    final latInt = ((lat + 90) * 10000).round();
    final lngInt = ((lng + 180) * 10000).round();
    return '${latInt}_$lngInt';
  }

  Future<void> recordArrival(
      String locationName, double latitude, double longitude) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    try {
      await _db.collection('presence').doc(uid).set(
        {
          'locationName': locationName,
          'latitude': latitude,
          'longitude': longitude,
          'geohash': _geohash(latitude, longitude),
          'arrivedAt': FieldValue.serverTimestamp(),
          'uid': uid,
          'expiresAt': Timestamp.fromDate(
            DateTime.now().toUtc().add(const Duration(minutes: 15)),
          ),
        },
        SetOptions(merge: false),
      );
      debugPrint('[PresenceService] Recorded arrival at $locationName for $uid');
    } catch (e) {
      debugPrint('[PresenceService] recordArrival error: $e');
    }
  }

  Future<void> clearPresence() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('presence').doc(uid).delete();
      debugPrint('[PresenceService] Cleared presence for $uid');
    } catch (e) {
      debugPrint('[PresenceService] clearPresence error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getActivePresence(
      double latitude, double longitude) async {
    const double delta = 0.00135; // ~150m in degrees
    final minLat = latitude - delta;
    final maxLat = latitude + delta;
    final minLng = longitude - delta;
    final maxLng = longitude + delta;

    try {
      final snapshot = await _db
          .collection('presence')
          .where('latitude', isGreaterThanOrEqualTo: minLat)
          .where('latitude', isLessThanOrEqualTo: maxLat)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .limit(50)
          .get();

      return snapshot.docs
          .where((doc) {
            final lng = (doc.data()['longitude'] as num?)?.toDouble();
            return lng != null && lng >= minLng && lng <= maxLng;
          })
          .map((doc) => {...doc.data(), 'uid': doc.id})
          .toList();
    } catch (e) {
      debugPrint('[PresenceService] getActivePresence error: $e');
      return [];
    }
  }

  Future<int> getPresenceCount(double latitude, double longitude) async {
    final results = await getActivePresence(latitude, longitude);
    return results.length;
  }

  Future<void> sendCrowdsourceRequest({
    required String locationName,
    required double latitude,
    required double longitude,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('crowdsource_requests')
          .add({
        'requestedBy': uid,
        'locationName': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'geohash': _geohash(latitude, longitude),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('[PresenceService] sendCrowdsourceRequest error: $e');
    }
  }
}
