import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prism/utils/constants.dart';

/// Detects whether the deployed backend supports Firebase/JWT auth endpoints.
class AuthBackendCapabilities {
  static bool? _firebaseAuthEnabled;

  static bool get firebaseAuthEnabled => _firebaseAuthEnabled ?? false;
  static bool get legacyAuthEnabled => !firebaseAuthEnabled;

  static Future<void> probe() async {
    if (_firebaseAuthEnabled != null) return;

    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.resolveUsername}',
      );
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({'username': '__capability_probe__'}),
          )
          .timeout(const Duration(seconds: 8));

      // Any non-404 response means the route exists on this backend.
      _firebaseAuthEnabled = response.statusCode != 404;
    } catch (_) {
      _firebaseAuthEnabled = false;
    }
  }
}
