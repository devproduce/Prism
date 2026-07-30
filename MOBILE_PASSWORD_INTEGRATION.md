# Mobile Integration: Optional Password & Login Flow

## Overview

Users can now optionally set a password during Google sign-up. This allows them to login with **either** Google SSO **or** username + password. No changes to existing login endpoints — just an optional `password` field on registration.

---

## Auth Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/auth/google-register` | Register via Google (optional password) |
| POST | `/auth/login/verify` | Login via Google SSO |
| POST | `/auth/legacy-login` | Login via username + password |

---

## 1. Google Registration (with optional password)

```
POST /auth/google-register
Content-Type: multipart/form-data
```

### Request Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id_token` | String | Yes | Google ID token from Firebase Auth SDK |
| `username` | String | Yes | Unique username |
| `image` | File | Yes | Profile photo |
| `face_ids` | String | No | JSON array: `["id1","id2","id3"]` |
| `password` | String | No | Min 6 chars if provided |

### Behavior

- **Without `password`** → User can only login via Google SSO
- **With `password`** → User can login via Google SSO **or** username + password

### Response (200 OK)

```json
{
  "token": "prism_access_token",
  "refresh_token": "prism_refresh_token",
  "user_id": "uuid",
  "username": "string"
}
```

### Flutter Example

```dart
Future<Map<String, dynamic>> googleRegister({
  required String googleIdToken,
  required String username,
  required File imageFile,
  List<String> faceIds = const [],
  String? password, // optional
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

  request.files.add(
    await http.MultipartFile.fromPath('image', imageFile.path),
  );

  final response = await request.send();
  final body = await response.stream.bytesToString();

  if (response.statusCode == 200) {
    return jsonDecode(body);
  } else {
    throw Exception(jsonDecode(body)['detail'] ?? 'Registration failed');
  }
}
```

---

## 2. Login via Google SSO

```
POST /auth/login/verify
Content-Type: application/json
```

### Request Body

```json
{
  "firebase_token": "google_id_token_from_firebase_sdk"
}
```

### Response (200 OK)

```json
{
  "token": "prism_access_token",
  "refresh_token": "prism_refresh_token",
  "user_id": "uuid",
  "username": "string"
}
```

### Error (401)

```json
{ "detail": "User not found" }
```

---

## 3. Login via Username + Password

```
POST /auth/legacy-login
Content-Type: application/json
```

### Request Body

```json
{
  "username": "string",
  "password": "string"
}
```

### Response (200 OK)

```json
{
  "token": "prism_access_token",
  "refresh_token": "prism_refresh_token",
  "user_id": "uuid",
  "username": "string",
  "email": "string",
  "has_image": true,
  "has_face_model": true,
  "has_faces": true,
  "is_face_model_valid": true
}
```

### Error (401)

```json
{ "detail": "Your account was registered with Google. Please use Google Sign-In to login." }
```

This error means the user registered via Google **without** setting a password. They must use Google SSO to login.

---

## Login Flow Decision Tree

```
User opens login screen
  ├── Enter username + password → POST /auth/legacy-login
  │     ├── 200 OK → Store tokens, navigate to home
  │     ├── 401 "registered with Google" → Show error, suggest Google SSO
  │     └── 401 "Invalid credentials" → Show error
  │
  └── Tap "Continue with Google" → Get Google ID token → POST /auth/login/verify
        ├── 200 OK → Store tokens, navigate to home
        └── 401 → Show error
```

---

## Important Notes

1. **Frontend doesn't need to know** how a user registered. Just show both login options and handle errors.

2. **No new API fields on login** — the existing `/auth/legacy-login` and `/auth/login/verify` endpoints work for all user types.

3. **Password is optional only on Google registration**. Normal email/password registration (if used) still requires a password.

4. **Token storage** — On successful login from either method, store `token` (access) and `refresh_token` the same way. No difference.

5. **Firebase token** — The `id_token` / `firebase_token` comes from Firebase Auth SDK on the client. Use `GoogleSignIn` plugin → get `Authentication.idToken` → send as `id_token` (registration) or `firebase_token` (login).

---

## Error Handling Summary

| HTTP Code | Error | Meaning |
|-----------|-------|---------|
| 200 | Success | Login/Register successful |
| 401 | "Invalid Firebase token" | Google token expired or invalid |
| 401 | "registered with Google" | User has no password, must use Google SSO |
| 401 | "Invalid credentials" | Wrong username or password |
| 404 | "User not found" | No account exists with that username |
| 409 | "username already exists" | Username taken during registration |
| 422 | Validation error | Missing fields or password < 6 chars |
