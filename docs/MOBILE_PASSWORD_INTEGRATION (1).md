# Mobile Integration: Optional Password & Login Flow

## Overview

Users can optionally set a password during Google sign-up, or add one later via a PATCH endpoint. This allows login with **either** Google SSO **or** username + password.

---

## Auth Endpoints

| Method | Endpoint | Auth | Purpose |
|--------|----------|------|---------|
| POST | `/auth/google-register` | No | Register via Google (optional password) |
| POST | `/auth/login/verify` | No | Login via Google SSO |
| POST | `/auth/legacy-login` | No | Login via username + password |
| PATCH | `/auth/set-password` | Bearer | Set password post-registration (Google-only users) |

---

## 1. Google Registration

```
POST /auth/google-register
Content-Type: multipart/form-data
```

### Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id_token` | String | Yes | Google ID token from Firebase Auth SDK |
| `username` | String | Yes | Unique username |
| `image` | File | Yes | Profile photo |
| `face_ids` | String | No | JSON array: `["id1","id2","id3"]` |
| `password` | String | **No** | Min 6 chars if provided |

### Behavior

- **Without `password`** → `password` stored as `""` in DB. User can only login via Google SSO.
- **With `password`** → Password hashed + synced to Firebase. User can login via **Google SSO** or **username + password**.

### Response (200)

```json
{
  "token": "prism_access_token",
  "refresh_token": "prism_refresh_token",
  "user_id": "uuid",
  "username": "string"
}
```

### Flutter

```dart
Future<Map<String, dynamic>> googleRegister({
  required String googleIdToken,
  required String username,
  required File imageFile,
  List<String> faceIds = const [],
  String? password,
}) async {
  final request = http.MultipartRequest(
    'POST',
    Uri.parse('$BASE_URL/auth/google-register'),
  );

  request.fields['id_token'] = googleIdToken;
  request.fields['username'] = username;

  if (password != null && password.isNotEmpty) {
    request.fields['password'] = password;
  }
  if (faceIds.isNotEmpty) {
    request.fields['face_ids'] = jsonEncode(faceIds);
  }
  request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

  final response = await request.send();
  final body = await response.stream.bytesToString();

  if (response.statusCode == 200) {
    return jsonDecode(body);
  }
  throw Exception(jsonDecode(body)['detail'] ?? 'Registration failed');
}
```

---

## 2. Login via Google SSO

```
POST /auth/login/verify
Content-Type: application/json
```

### Body

```json
{
  "firebase_token": "google_id_token"
}
```

### Response (200)

```json
{
  "token": "prism_access_token",
  "refresh_token": "prism_refresh_token",
  "user_id": "uuid",
  "username": "string"
}
```

### Error

```json
{ "detail": "User not found" }
```

---

## 3. Login via Username + Password

```
POST /auth/legacy-login
Content-Type: application/json
```

### Body

```json
{
  "identifier": "username_or_email",
  "password": "user_password"
}
```

### Response (200) — Two possible shapes:

**A) User is migrated (has Firebase UID):**
```json
{
  "email": "user@email.com"
}
```
Frontend must then call Firebase `signInWithEmailAndPassword(email, password)`, get the ID token, then call `/auth/login/verify`.

**B) User is NOT migrated (legacy-only):**
```json
{
  "needs_migration": true,
  "migration_token": "jwt",
  "has_firebase_account": false
}
```

### Error (401)

```json
{ "detail": "Your account was registered with Google. Please use Google Sign-In to login." }
```

### Flutter — Legacy Login Flow

```dart
Future<Map<String, dynamic>> loginWithPassword({
  required String username,
  required String password,
}) async {
  final response = await http.post(
    Uri.parse('$BASE_URL/auth/legacy-login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'identifier': username, 'password': password}),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    // Migrated user — need Firebase sign-in
    if (data.containsKey('email')) {
      final UserCredential credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: data['email'], password: password);
      final idToken = await credential.user!.getIdToken();

      // Exchange Firebase token for Prism tokens
      final verifyResponse = await http.post(
        Uri.parse('$BASE_URL/auth/login/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'firebase_token': idToken}),
      );
      return jsonDecode(verifyResponse.body);
    }

    // Non-migrated user — handle migration flow
    return data;
  }

  throw Exception(jsonDecode(response.body)['detail'] ?? 'Login failed');
}
```

---

## 4. Set Password Post-Registration

For Google-registered users who skipped the password field during signup and want to add one later.

```
PATCH /auth/set-password
Authorization: Bearer <prism_access_token>
Content-Type: application/json
```

### Body

```json
{
  "password": "my_new_password"
}
```

### Response (200)

```json
{
  "message": "Password set successfully"
}
```

### Errors

| Status | Error | Why |
|--------|-------|-----|
| 401 | "Missing authorization header" | No Bearer token |
| 401 | "Invalid or expired token" | Token expired or tampered |
| 404 | "User not found" | User deleted before call |
| 400 | "Password already set. Cannot overwrite." | User already has a password (security guard) |
| 422 | Validation error | Password < 6 chars |

### Behavior

1. Requires a valid Prism access token in the `Authorization` header
2. Only works for users whose current `password` field is `""` (Google-only users)
3. **One-time operation** — once set, the guard prevents overwriting
4. Hashes the password (SHA-256) in DB
5. Syncs raw password to Firebase Auth via `firebase_auth.update_user()` so the Firebase `signInWithEmailAndPassword` flow works

### Flutter

```dart
Future<void> setPassword({
  required String accessToken,
  required String newPassword,
}) async {
  final response = await http.patch(
    Uri.parse('$BASE_URL/auth/set-password'),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'password': newPassword}),
  );

  if (response.statusCode == 200) {
    // Password set — user can now login with username + password
    return;
  }

  final detail = jsonDecode(response.body)['detail'];
  throw Exception(detail ?? 'Failed to set password');
}
```

---

## Login Flow — Decision Tree

```
Login Screen
  ├── Username + Password
  │     └── POST /auth/legacy-login
  │           ├── 200 + email field
  │           │     └── Firebase signInWithEmailAndPassword(email, password)
  │           │           └── POST /auth/login/verify with Firebase token
  │           │                 ├── 200 → Store Prism tokens ✓
  │           │                 └── 401 → Error
  │           ├── 200 + needs_migration
  │           │     └── Handle migration flow
  │           ├── 401 "registered with Google"
  │           │     └── Show: "Use Google Sign-In"
  │           └── 401 "Invalid credentials"
  │                 └── Show: "Wrong username or password"
  │
  └── Continue with Google
        └── Firebase GoogleSignIn → get idToken
              └── POST /auth/login/verify with Firebase token
                    ├── 200 → Store Prism tokens ✓
                    ├── 401 → Register first
                    └── 404 → Show: "No account found"


Profile / Settings
  └── "Set Password" button (only for passwordless Google users)
        └── PATCH /auth/set-password (requires Bearer token)
              ├── 200 → Success, user can now use username+password
              ├── 400 "already set" → Already has password, hide this button
              └── 422 → Password too short
```

---

## Important Notes

1. **Frontend doesn't need to know** how a user registered — just try both login methods and handle errors.

2. **Login returns email for migrated users** — frontend must complete the Firebase auth flow client-side.

3. **Password is optional only during Google registration.** Normal email/password registration (if implemented) still requires a password.

4. **Set-password is one-time** — once a password is set, the endpoint refuses to overwrite it. Security guard prevents account takeover.

5. **Token storage** — Store `token` (access) and `refresh_token` from any login method. Same storage, no difference.

6. **Show/hide "Set Password" UI** — Only show it to Google users who don't have a password yet. You can detect this by:
   - Storing `auth_provider: "google"` + `has_password: false` when registering without password
   - Or just attempt PATCH and handle the 400

---

## Error Handling Summary

| HTTP Code | `detail` | Meaning |
|-----------|----------|---------|
| 200 | — | Success |
| 400 | "Password already set. Cannot overwrite." | User already has password (PATCH only) |
| 401 | "Invalid Firebase token" | Google ID token expired/invalid |
| 401 | "registered with Google" | No password set, use Google SSO |
| 401 | "Invalid credentials" | Wrong username or password |
| 401 | "Missing authorization header" / "Invalid or expired token" | Bearer token issue (PATCH only) |
| 404 | "User not found" | Account doesn't exist |
| 409 | "username already exists" | Username taken during registration |
| 422 | Validation error | Missing field or password < 6 chars |
