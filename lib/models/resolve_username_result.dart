class ResolveUsernameResult {
  final String? email;
  final bool useGoogle;
  final bool needsMigration;
  final String? migrationToken;
  final bool hasFirebaseAccount;
  final String? prefilledEmail;

  const ResolveUsernameResult({
    this.email,
    this.useGoogle = false,
    this.needsMigration = false,
    this.migrationToken,
    this.hasFirebaseAccount = false,
    this.prefilledEmail,
  });

  factory ResolveUsernameResult.fromJson(Map<String, dynamic> json) {
    final error = json['error']?.toString();
    if (error == 'USE_GOOGLE') {
      return const ResolveUsernameResult(useGoogle: true);
    }

    if (json['needs_migration'] == true) {
      return ResolveUsernameResult(
        needsMigration: true,
        migrationToken: json['migration_token'] as String?,
        hasFirebaseAccount: json['has_firebase_account'] as bool? ?? false,
        prefilledEmail: json['email'] as String?,
      );
    }

    return ResolveUsernameResult(
      email: json['email'] as String?,
      hasFirebaseAccount: json['has_firebase_account'] as bool? ?? true,
    );
  }
}