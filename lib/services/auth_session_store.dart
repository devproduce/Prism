import 'package:shared_preferences/shared_preferences.dart';
import 'package:prism/models/auth_gate.dart';
import 'package:prism/utils/auth_constants.dart';

class AuthSessionStore {
  AuthSessionStore._();
  static final AuthSessionStore instance = AuthSessionStore._();

  bool hasFirebaseAccount = false;
  String? migrationToken;
  AuthGate authGate = AuthGate.none;
  String? _sessionUserId;

  Future<void> bindUser(String userId) async {
    _sessionUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    hasFirebaseAccount =
        prefs.getBool(hasFirebaseAccountKey(userId)) ?? false;
  }

  Future<void> setHasFirebaseAccount(String userId, bool value) async {
    hasFirebaseAccount = value;
    _sessionUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasFirebaseAccountKey(userId), value);
  }

  void setMigrationToken(String? token) {
    migrationToken = token;
  }

  void setAuthGate(AuthGate gate) {
    authGate = gate;
  }

  Future<void> clear() async {
    if (_sessionUserId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(hasFirebaseAccountKey(_sessionUserId!));
    }
    hasFirebaseAccount = false;
    migrationToken = null;
    authGate = AuthGate.none;
    _sessionUserId = null;
  }
}