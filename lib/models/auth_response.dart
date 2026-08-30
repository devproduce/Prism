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
  final bool? hasFirebaseAccount;

  AuthResponse({
    required this.user,
    required this.message,
    this.accessToken,
    this.refreshToken,
    this.phoneSynced,
    this.exists,
    this.needsMigration,
    this.migrationToken,
    this.hasFirebaseAccount,
  });

  /// Backward-compatible alias used across existing call sites.
  String? get token => accessToken;

  bool get hasAccessToken =>
      accessToken != null && accessToken!.isNotEmpty;

  /// Email already known on the login response (do not ask for it again).
  bool get hasKnownEmail => user.email.contains('@');

  /// True only for real legacy migration that still needs the Secure Account UI.
  ///
  /// Secure Account exists to *collect* an email. If the backend already returned
  /// one (Google signup / migrated users), we must not open that screen — use
  /// Firebase password exchange instead (see MOBILE_LOGIN_MIGRATION_FIX.md).
  ///
  /// Only force the Secure Account path when:
  /// - `needs_migration` + non-empty `migration_token`, AND
  /// - no usable email yet, OR backend explicitly says `has_firebase_account: false`
  ///   and Firebase sign-in is not applicable without migrate-email.
  bool get isLegacyMigrationRequired {
    if (needsMigration != true) return false;
    final token = migrationToken;
    if (token == null || token.isEmpty) return false;

    // Email already present → not an "add your email" case.
    // Caller should try Firebase first; only fall back to migrate when
    // has_firebase_account is explicitly false and Firebase fails.
    if (hasKnownEmail && hasFirebaseAccount != false) {
      return false;
    }
    return true;
  }

  /// Backend verified password and returned email for Firebase sign-in
  /// (`{ "email": "..." }` — see MOBILE_LOGIN_MIGRATION_FIX.md Response A),
  /// or a mis-tagged migration response that still includes a known email.
  bool get requiresFirebasePasswordExchange {
    if (hasAccessToken) return false;
    if (!hasKnownEmail) return false;
    // Real legacy with no Firebase yet still needs migrate-email — but only
    // after Firebase is attempted and fails (handled in AuthProvider.login).
    if (needsMigration == true &&
        hasFirebaseAccount == false &&
        migrationToken != null &&
        migrationToken!.isNotEmpty) {
      return false;
    }
    return true;
  }

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
    final needsMigration = json['needs_migration'] as bool?;
    final migrationToken = json['migration_token'] as String?;
    final hasFirebaseAccount = json['has_firebase_account'] as bool?;
    final emailOnly = json['email']?.toString().trim() ?? '';

    // Legacy migration response may only include needs_migration + migration_token.
    if (needsMigration == true) {
      return AuthResponse(
        user: UserModel(
          userId: '',
          username: '',
          email: emailOnly,
          firstName: '',
        ),
        message: json['message']?.toString() ?? 'Migration required',
        needsMigration: true,
        migrationToken: migrationToken,
        hasFirebaseAccount: hasFirebaseAccount,
      );
    }

    // Migrated / Google+password handoff: { "email": "..." } with no tokens.
    final accessToken = _extractAccessToken(json);
    final refreshToken = _extractRefreshToken(json);
    // A response that explicitly carries `exists` (e.g. google-login's
    // "Google signup required") is NOT an email handoff — it must keep its
    // `exists` flag so the caller can route new users to registration.
    final hasExistsKey = json.containsKey('exists');
    final isEmailHandoff =
        !hasExistsKey &&
        emailOnly.contains('@') &&
        (accessToken == null || accessToken.isEmpty) &&
        json['user'] == null &&
        json['user_id'] == null &&
        json['username'] == null;

    if (isEmailHandoff) {
      return AuthResponse(
        user: UserModel(
          userId: '',
          username: '',
          email: emailOnly,
          firstName: '',
        ),
        message: json['message']?.toString() ?? 'Continue with Firebase',
        accessToken: null,
        refreshToken: null,
        hasFirebaseAccount: hasFirebaseAccount ?? true,
        exists: json['exists'] as bool?,
      );
    }

    // Check if user data is nested under 'user' key
    final userData =
        (json['user'] != null && json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : json;

    return AuthResponse(
      user: UserModel.fromJson(userData),
      message: json['message']?.toString() ?? 'Success',
      accessToken: accessToken,
      refreshToken: refreshToken,
      phoneSynced: json['phone_synced'] as bool?,
      exists: json['exists'] as bool?,
      needsMigration: needsMigration,
      migrationToken: migrationToken,
      hasFirebaseAccount: hasFirebaseAccount,
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
      if (hasFirebaseAccount != null) 'has_firebase_account': hasFirebaseAccount,
    };
  }
}
