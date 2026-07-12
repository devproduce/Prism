import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prism/utils/constants.dart';

/// Detects whether the deployed backend supports Firebase/JWT auth endpoints.
class AuthBackendCapabilities {
  static const _cacheKey = 'prism_firebase_auth_enabled';

  static bool _firebaseAuthEnabled = true;
  static bool _probeCompleted = false;

  static bool get firebaseAuthEnabled => _firebaseAuthEnabled;
  static bool get legacyAuthEnabled => !firebaseAuthEnabled;

  /// Probes the backend once per install (cached) to detect Firebase auth routes.
  static Future<void> probe() async {
    if (_probeCompleted) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_cacheKey)) {
      _firebaseAuthEnabled = prefs.getBool(_cacheKey) ?? true;
      _probeCompleted = true;
      debugPrint(
        'AuthBackendCapabilities: using cached '
        '${_firebaseAuthEnabled ? "Firebase" : "legacy"} auth',
      );
      return;
    }

    _firebaseAuthEnabled = await _detectFirebaseAuth();
    await prefs.setBool(_cacheKey, _firebaseAuthEnabled);
    _probeCompleted = true;
    debugPrint(
      'AuthBackendCapabilities: probed and cached '
      '${_firebaseAuthEnabled ? "Firebase" : "legacy"} auth',
    );
  }

  /// POST /auth/login/verify with an invalid body — route exists if we get
  /// 401/422, not 404.
  static Future<bool> _detectFirebaseAuth() async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.loginVerify}',
      );
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({'id_token': '__capability_probe__'}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        debugPrint(
          'AuthBackendCapabilities: /auth/login/verify returned 404 — legacy',
        );
        return false;
      }

      // 401/422/400 prove the route exists even with a bad token.
      if (response.statusCode == 401 ||
          response.statusCode == 422 ||
          response.statusCode == 400) {
        debugPrint(
          'AuthBackendCapabilities: /auth/login/verify exists (${response.statusCode})',
        );
        return true;
      }

      // 2xx would be unexpected for a probe token but still means Firebase auth.
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }

      debugPrint(
        'AuthBackendCapabilities: unexpected status ${response.statusCode}, assuming Firebase',
      );
      return true;
    } catch (e) {
      debugPrint(
        'AuthBackendCapabilities probe failed, assuming Firebase auth: $e',
      );
      return true;
    }
  }
}
