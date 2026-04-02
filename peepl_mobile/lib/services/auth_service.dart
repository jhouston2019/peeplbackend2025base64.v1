import 'package:firebase_auth/firebase_auth.dart';
import 'push_notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get userStream => _auth.authStateChanges();

  Future<void> signOut() async {
    await PushNotificationService.instance.onUserSignedOut();
    await _auth.signOut();
  }
}