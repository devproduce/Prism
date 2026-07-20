import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:prism/utils/auth_constants.dart';

class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _googleInitialized = false;

  User? get currentUser => _auth.currentUser;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: kGoogleSignInServerClientId,
    );
    _googleInitialized = true;
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
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

  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email.trim());
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
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'unknown':
        final message = e.message ?? '';
        if (message.contains('CONFIGURATION_NOT_FOUND')) {
          return 'Firebase is not configured for this app build yet.';
        }
        return message.isNotEmpty
            ? message
            : 'Authentication failed. Please try again.';
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
