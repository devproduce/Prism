# Mobile Login Flow: Fixing "Migration Session Expired" Error

## The Bug

When a user logs in with **username + password**, the mobile app shows the "Secure Your Account" page (migration flow) and then fails with **"Migration session expired. Please login again"** on submit.

**Root cause:** The app treats every legacy-login response as "needs migration" — but for **already-migrated users**, the backend returns a completely different response that requires a different flow.

---

## The Two Legacy-Login Responses

`POST /auth/legacy-login` with `{ "identifier": "vaibhavGala262", "password": "..." }` returns **one of two shapes**:

### Response A — User already migrated (has Firebase account):

```json
{
  "email": "vaibhavgala.work25@gmail.com"
}
```

⚠️ **NO `needs_migration`, NO `migration_token`.**

This user already has a Firebase account. The app must **NOT** show the "Secure Account" page.

### Response B — User NOT migrated (legacy-only account):

```json
{
  "needs_migration": true,
  "migration_token": "jwt_token_here",
  "has_firebase_account": false
}
```

This user needs the "Secure Account" flow.

---

## The Bug In Detail

The mobile app currently does:

```
POST /auth/legacy-login
    ↓
{ "email": "..." }          ← migrated user, BUT app treats this as needs-migration
    ↓
Shows "Secure Your Account" page asking for email
    ↓
User enters email, taps submit
    ↓
POST /auth/migrate-email  with NO valid migration_token (one was never issued!)
    ↓
Backend: "Invalid or expired migration token"
    ↓
App shows: "Migration session expired. Please login again"
```

The app tries to run the migration flow for a user who doesn't need migration. Since no `migration_token` was issued, the `/auth/migrate-email` call fails.

---

## The Fix — Correct Branching Logic

```dart
final response = await http.post(
  Uri.parse('$BASE_URL/auth/legacy-login'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'identifier': username, 'password': password}),
);

final data = jsonDecode(response.body);

if (data.containsKey('needs_migration')) {
  // ===== Flow 1: User is NOT migrated → show "Secure Your Account" =====
  // Collect email → call migrate-email
  final migrateResponse = await http.post(
    Uri.parse('$BASE_URL/auth/migrate-email'),
    headers: {'Content-Type': 'multipart/form-data'}, // ← FORM DATA, not JSON!
    body: {
      'migration_token': data['migration_token'],
      'email': userEmail,
      'password': password,
    },
  );
  // handle 200 → store Prism tokens, navigate home

} else if (data.containsKey('email')) {
  // ===== Flow 2: User IS migrated → SKIP "Secure Account" page =====
  // Go straight to Firebase password sign-in
  final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: data['email'],
    password: password,
  );
  final idToken = await credential.user!.getIdToken();

  // Exchange Firebase token for Prism tokens
  final verifyResponse = await http.post(
    Uri.parse('$BASE_URL/auth/login/verify'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'firebase_token': idToken}),
  );
  // handle 200 → store Prism tokens, navigate home

} else {
  // Handle errors (USE_GOOGLE, 401, 404, etc.)
}
```

---

## Critical Notes

### 1. Migrate-email uses FORM DATA, not JSON

`POST /auth/migrate-email` expects `multipart/form-data`:

| Field | Value |
|-------|-------|
| `migration_token` | From legacy-login response |
| `email` | User's email |
| `password` | User's password |

Sending JSON instead returns a **422 validation error** ("Field required").

### 2. Migrated users skip the Secure Account page entirely

If the user already has a Firebase account (`is_migrated`), there is **no** migration flow. The app should:
1. Take `email` from the response
2. Call Firebase `signInWithEmailAndPassword(email, password)` client-side
3. Call `/auth/login/verify` with the resulting Firebase ID token

### 3. The migration_token is short-lived

It expires in **15 minutes**. Complete the migrate-email call promptly after legacy-login.

### 4. The "Migration session expired" message is misleading

The backend's actual error is `"Invalid or expired migration token"`. The app should differentiate:
- **Missing/invalid token** → flow bug (app shouldn't be showing migration for this user)
- **Token expired (>15 min)** → genuine timeout, ask user to login again

---

## Correct Login Flow (Full)

```
User enters username + password
    ↓
POST /auth/legacy-login
    ↓
Check response shape:

├── has "needs_migration": true
│     └── Show "Secure Your Account" page (collect email)
│           └── POST /auth/migrate-email (FORM DATA)
│                 └── 200 → Store Prism tokens → Home
│                 └── 401 "Invalid or expired migration token"
│                       ├── If flow was fast → token missing (bug in app logic)
│                       └── If >15 min → genuine expiry → re-login
│
├── has "email": "..."  (no needs_migration)
│     └── User already migrated — NO Secure Account page
│           └── Firebase signInWithEmailAndPassword(email, password)
│                 └── POST /auth/login/verify with Firebase token
│                       └── 200 → Store Prism tokens → Home
│
└── has "error": "USE_GOOGLE"
      └── Show "This account uses Google Sign-In" → route to Google flow
```

---

## Verification (tested on production 30-Jul-2026)

- `vaibhavGala262` + `vaib@1603` → legacy-login returns `{ "email": "vaibhavgala.work25@gmail.com" }` (migrated user)
- No `migration_token` is returned for this user
- Calling migrate-email without a valid token → rejected
- Correct fix: use the Firebase email+password sign-in path for this user
