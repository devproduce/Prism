import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prism/models/auth_gate.dart';
import 'package:prism/utils/auth_constants.dart';

class AuthSessionStore {
  AuthSessionStore._();
  static final AuthSessionStore instance = AuthSessionStore._();

  static const _migrationTokenKey = 'prism_migration_token';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool hasFirebaseAccount = false;
  String? migrationToken;
  AuthGate authGate = AuthGate.none;
  String? migrationPrefilledEmail;
  String? _sessionUserId;

  String? get sessionUserId => _sessionUserId;

  /// Restores persisted session metadata after process restart.
  Future<void> hydrate() async {
    await ensureSessionUserIdHydrated();

    final prefs = await SharedPreferences.getInstance();
    final gateName = prefs.getString(kPrefAuthGate);
    if (gateName != null && gateName.isNotEmpty) {
      authGate = AuthGate.values.firstWhere(
        (gate) => gate.name == gateName,
        orElse: () => AuthGate.none,
      );
    }

    migrationPrefilledEmail = prefs.getString(kPrefMigrationPrefilledEmail);
    migrationToken = await _secureStorage.read(key: _migrationTokenKey);

    if (_sessionUserId != null && _sessionUserId!.isNotEmpty) {
      hasFirebaseAccount =
          prefs.getBool(hasFirebaseAccountKey(_sessionUserId!)) ?? false;
    }
  }

  /// Restores in-memory session user id from SharedPreferences after hot reload
  /// or when the singleton outlives a process restart.
  Future<void> ensureSessionUserIdHydrated() async {
    if (_sessionUserId != null && _sessionUserId!.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kPrefUserId);
    if (stored != null && stored.isNotEmpty) {
      _sessionUserId = stored;
    }
  }

  Future<void> bindUser(String userId) async {
    _sessionUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefUserId, userId);
    hasFirebaseAccount =
        prefs.getBool(hasFirebaseAccountKey(userId)) ?? false;
  }

  Future<void> setHasFirebaseAccount(String userId, bool value) async {
    hasFirebaseAccount = value;
    _sessionUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasFirebaseAccountKey(userId), value);
  }

  Future<void> setMigrationToken(String? token) async {
    migrationToken = token;
    if (token == null || token.isEmpty) {
      await _secureStorage.delete(key: _migrationTokenKey);
    } else {
      await _secureStorage.write(key: _migrationTokenKey, value: token);
    }
  }

  Future<void> setMigrationPrefilledEmail(String? email) async {
    migrationPrefilledEmail = email;
    final prefs = await SharedPreferences.getInstance();
    if (email == null || email.isEmpty) {
      await prefs.remove(kPrefMigrationPrefilledEmail);
    } else {
      await prefs.setString(kPrefMigrationPrefilledEmail, email);
    }
  }

  Future<void> setAuthGate(AuthGate gate) async {
    authGate = gate;
    final prefs = await SharedPreferences.getInstance();
    if (gate == AuthGate.none) {
      await prefs.remove(kPrefAuthGate);
    } else {
      await prefs.setString(kPrefAuthGate, gate.name);
    }
  }

  Future<void> clear() async {
    if (_sessionUserId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(hasFirebaseAccountKey(_sessionUserId!));
    }
    hasFirebaseAccount = false;
    migrationToken = null;
    migrationPrefilledEmail = null;
    authGate = AuthGate.none;
    _sessionUserId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kPrefUserId);
    await prefs.remove(kPrefAuthGate);
    await prefs.remove(kPrefMigrationPrefilledEmail);
    await _secureStorage.delete(key: _migrationTokenKey);
  }
}
