import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Writes diagnostic events to Firestore so they can be read from the
/// Firebase console during TestFlight QA (print() is not readable on
/// device from a Windows machine).
/// TODO: gate behind a remote config flag or strip before public launch.
class DebugLogService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const bool enabled = true; // flip to false to silence all logging

  static Future<void> log(String tag, String message,
      {Map<String, dynamic>? data}) async {
    if (!enabled) return;
    try {
      await _db.collection('debug_logs').add({
        'tag': tag,
        'message': message,
        'data': data ?? {},
        'uid': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        'timestamp': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });
    } catch (_) {
      // Logging must never crash or block the UI.
    }
  }
}
