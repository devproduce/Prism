/// Shared auth preference keys - must stay in sync with native Android code.
const String kPrefAuthToken = 'prism_auth_token';
const String kPrefUserId = 'prism_user_id';
const String kPrefBaseUrl = 'prism_base_url';

String hasFirebaseAccountKey(String userId) =>
    'prism_has_firebase_account_$userId';