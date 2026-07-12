import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detects whether the deployed backend supports Firebase/JWT auth endpoints.
class AuthBackendCapabilities {
  static const _cacheKey = 'prism_firebase_auth_enabled';

  static bool _firebaseAuthEnabled = true;
  static bool _probeCompleted = false;

  static bool get firebaseAuthEnabled => _firebaseAuthEnabled;
  static bool get legacyAuthEnabled => !firebaseAuthEnabled;

  /// Ensures Firebase/JWT auth is active for this app build.
  static Future<void> probe() async {
    if (_probeCompleted) return;

    _firebaseAuthEnabled = true;
    _probeCompleted = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cacheKey, true);
    debugPrint('AuthBackendCapabilities: Firebase auth enabled');
  }
}
