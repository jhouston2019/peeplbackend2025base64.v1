import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Growth funnel events written to Firestore `growth_events`.
/// Never throws — failures are swallowed.
class GrowthAnalyticsService {
  GrowthAnalyticsService._();

  /// Keep in sync with pubspec.yaml version.
  static const String appVersion = '1.0.0+116';

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> logEvent(
    String eventName,
    Map<String, dynamic> properties,
  ) async {
    if (!_shouldWrite()) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await _db.collection('growth_events').add({
        'eventName': eventName,
        'properties': properties,
        'userId': uid,
        'timestamp': FieldValue.serverTimestamp(),
        'appVersion': appVersion,
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      debugPrint('[GrowthAnalytics] logEvent failed: $e');
    }
  }

  static bool _shouldWrite() {
    if (kDebugMode) return true;
    // Production default: always sample (write all events).
    return true;
  }
}
