import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prism/utils/auth_constants.dart';

class TokenStorageService {
  TokenStorageService._();
  static final TokenStorageService instance = TokenStorageService._();

  static const _refreshTokenKey = 'prism_refresh_token';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: _refreshTokenKey);
  }

  Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefAuthToken, token);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kPrefAuthToken);
  }

  Future<void> clearAll() async {
    try {
      await _secureStorage.delete(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('TokenStorageService: failed to clear refresh token: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kPrefAuthToken);
  }
}
