/// Shared auth preference keys - must stay in sync with native Android code.
const String kPrefAuthToken = 'prism_auth_token';
const String kPrefUserId = 'prism_user_id';
const String kPrefBaseUrl = 'prism_base_url';
const String kPrefAuthGate = 'prism_auth_gate';
const String kPrefMigrationPrefilledEmail = 'prism_migration_prefilled_email';

/// Web OAuth client ID from google-services.json (client_type: 3).
/// Required as [serverClientId] for Google Sign-In to return a Firebase idToken on Android.
const String kGoogleSignInServerClientId =
    '90565753841-s1nvb0ssinh2a000h2tgj45q897bmts5.apps.googleusercontent.com';

String hasFirebaseAccountKey(String userId) =>
    'prism_has_firebase_account_$userId';