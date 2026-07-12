import 'package:prism/models/user_model.dart';

class AuthResponse {
  final UserModel user;
  final String message;
  final String? accessToken;
  final String? refreshToken;
  final bool? phoneSynced; // V2: false = phone number was malformed
  final bool? exists; // Google login: false = needs registration
  final bool? needsMigration;
  final String? migrationToken;

  AuthResponse({
    required this.user,
    required this.message,
    this.accessToken,
    this.refreshToken,
    this.phoneSynced,
    this.exists,
    this.needsMigration,
    this.migrationToken,
  });

  /// Backward-compatible alias used across existing call sites.
  String? get token => accessToken;

  static String? extractAccessToken(Map<String, dynamic> json) =>
      _extractAccessToken(json);

  static String? extractRefreshToken(Map<String, dynamic> json) =>
      _extractRefreshToken(json);

  static String? _readTokenField(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static String? _extractAccessToken(Map<String, dynamic> json) {
    for (final key in ['access_token', 'token', 'accessToken', 'jwt']) {
      final value = _readTokenField(json, key);
      if (value != null) return value;
    }

    final nested = json['tokens'];
    if (nested is Map<String, dynamic>) {
      for (final key in ['access_token', 'token', 'accessToken', 'jwt']) {
        final value = _readTokenField(nested, key);
        if (value != null) return value;
      }
    }

    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return _extractAccessToken(data);
    }

    return null;
  }

  static String? _extractRefreshToken(Map<String, dynamic> json) {
    for (final key in ['refresh_token', 'refreshToken']) {
      final value = _readTokenField(json, key);
      if (value != null) return value;
    }

    final nested = json['tokens'];
    if (nested is Map<String, dynamic>) {
      for (final key in ['refresh_token', 'refreshToken']) {
        final value = _readTokenField(nested, key);
        if (value != null) return value;
      }
    }

    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return _extractRefreshToken(data);
    }

    return null;
  }

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Check if user data is nested under 'user' key
    final userData =
        (json['user'] != null && json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : json;

    return AuthResponse(
      user: UserModel.fromJson(userData),
      message: json['message']?.toString() ?? 'Success',
      accessToken: _extractAccessToken(json),
      refreshToken: _extractRefreshToken(json),
      phoneSynced: json['phone_synced'] as bool?,
      exists: json['exists'] as bool?,
      needsMigration: json['needs_migration'] as bool?,
      migrationToken: json['migration_token'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...user.toJson(),
      'message': message,
      if (accessToken != null) 'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (phoneSynced != null) 'phone_synced': phoneSynced,
      if (exists != null) 'exists': exists,
      if (needsMigration != null) 'needs_migration': needsMigration,
      if (migrationToken != null) 'migration_token': migrationToken,
    };
  }
}
