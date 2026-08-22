import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get userStream => _auth.authStateChanges();

  Future<void> signOut() async {
    try {
      await NotificationService.instance.onUserSignedOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('[AuthService] signOut error: $e');
    }
  }
}
