import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get userStream => _auth.authStateChanges();

  Future<void> signOut() async {
    await _auth.signOut();
  }
}