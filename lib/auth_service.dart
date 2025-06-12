import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up with email/password and return user UID
  Future<String?> signUpWithEmailPassword(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user?.uid;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Sign in with email/password and return user UID
  Future<String?> signInWithEmailPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user?.uid;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Get current user UID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }
}