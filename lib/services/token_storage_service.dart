import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prism/utils/auth_constants.dart';

class TokenStorageService {
  TokenStorageService._();
  static final TokenStorageService instance = TokenStorageService._();

  static const _refreshTokenKey = 'prism_refresh_token';
  static const _accessTokenKey = 'prism_access_token';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: _refreshTokenKey);
  }

  Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: _accessTokenKey, value: token);
    // Native Android background service still reads from SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefAuthToken, token);
  }

  Future<String?> getAccessToken() async {
    final secureToken = await _secureStorage.read(key: _accessTokenKey);
    if (secureToken != null && secureToken.isNotEmpty) {
      return secureToken;
    }

    // Migrate legacy plaintext tokens from SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(kPrefAuthToken);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await _secureStorage.write(key: _accessTokenKey, value: legacyToken);
      return legacyToken;
    }
    return null;
  }

  Future<bool> hasRefreshToken() async {
    final token = await getRefreshToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearAll() async {
    try {
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _accessTokenKey);
    } catch (e) {
      debugPrint('TokenStorageService: failed to clear secure tokens: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kPrefAuthToken);
  }
}
