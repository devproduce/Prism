import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _googleInitialized = false;

  User? get currentUser => _auth.currentUser;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<String> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No Firebase user signed in');
    }
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw StateError('Failed to obtain Firebase ID token');
    }
    return token;
  }

  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  bool get isGoogleLinked =>
      _auth.currentUser?.providerData
          .any((provider) => provider.providerId == 'google.com') ??
      false;

  Future<UserCredential> reauthenticateWithPassword({
    required String email,
    required String password,
  }) {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No Firebase user signed in');
    }
    return user.reauthenticateWithCredential(credential);
  }

  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final idToken = googleUser.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw FirebaseAuthException(code: 'google-sign-in-cancelled');
      }
      rethrow;
    }
  }

  Future<UserCredential> reauthenticateWithGoogle() async {
    await _ensureGoogleInitialized();
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final idToken = googleUser.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final user = _auth.currentUser;
      if (user == null) {
        throw StateError('No Firebase user signed in');
      }
      return user.reauthenticateWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw FirebaseAuthException(code: 'google-sign-in-cancelled');
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleInitialized) {
      await GoogleSignIn.instance.signOut();
    }
  }

  String friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Please try again.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'google-sign-in-cancelled':
        return 'Google sign-in was cancelled.';
      default:
        debugPrint('FirebaseAuth error: ${e.code} - ${e.message}');
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
