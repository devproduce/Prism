# Mobile (Flutter) Authentication Implementation Guide

This guide outlines the end-to-end authentication flows required for the mobile app. The backend relies heavily on **Firebase** for identity verification and **JWTs** for stateless session management. 

> [!IMPORTANT]
> This system features a unique **Legacy User Migration** flow and a **Hybrid Forgot Password** flow that you MUST implement correctly, otherwise older users will be permanently locked out.

---

## 1. Global API Configuration & JWT Refresh (Crucial)

The backend uses short-lived Access Tokens (15 minutes) and long-lived Refresh Tokens (30 days). 

**Your Dio / HTTP Interceptor Must Do This:**
1. Attach `Authorization: Bearer <access_token>` to every request.
2. If a request fails with a `401 Unauthorized`:
   - Pause all outgoing requests.
   - Call `POST /auth/refresh` sending `{"refresh_token": "<your_saved_refresh_token>"}`.
   - If successful, save the new `access_token` and automatically **retry** the original failed request.
   - If the refresh fails (token revoked or expired), immediately log the user out and wipe local storage.

---

## 2. Face Scanning (Multi-View WebSocket)

Before completing the registration (for both Email/Password and Google), the app must capture the user's face to create their CV profile.

**WebSocket Flow:**
1. Open a connection to `wss://<YOUR_BACKEND_URL>/ws/register_multi_views`
2. Wait for the server to send: `{"status": "waiting"}`
3. The server will request a specific pose: `{"status": "request_pose", "required_pose": "front"}` (or left/right).
4. Send captured frames (as binary image Blobs/Bytes) from the mobile camera over the WebSocket.
5. The server will send real-time feedback: `{"status": "processing", "quality": 0.8}`
6. If the pose is accepted, the server requests the next pose.
7. Once all poses are captured, the server sends:
   `{"status": "completed", "face_ids": ["uuid-1", "uuid-2"]}`
8. Close the WebSocket and hold onto those `face_ids`.

---

## 3. Standard Registration & Login

### A. Register (`POST /auth/register`)
Used for standard Email/Password signups.
- **Request (Multipart Form Data):**
  - `username` (string) - Required
  - `firebase_token` (string) - Required. The generated Firebase ID token.
  - `image` (file) - Required. The user's profile picture.
  - `email` (string) - Optional but highly recommended.
  - `first_name` (string) - Optional
  - `last_name` (string) - Optional
  - `country_code` (string) - Optional (e.g., "+91")
  - `phone_number` (string) - Optional
  - `face_ids` (string) - Optional. JSON string array from WebSocket: `["uuid-1", "uuid-2"]`.
- **Response:** Returns standard session data (`token`, `refresh_token`, etc.).

### B. Google Register (`POST /auth/google-register`)
- **App Flow:** Trigger the Firebase SDK Google Sign-in popup/redirect. Once the user authenticates, obtain their Google `idToken`.
- **Request (Multipart Form Data):**
  - `id_token` (string) - Required. The token received from Google/Firebase.
  - `username` (string) - Required. A newly chosen username.
  - `image` (file) - Optional. Profile picture (backend extracts from Google if missing).
  - `face_ids` (string) - Optional. JSON array of face IDs from WebSocket.
  *(Note: This endpoint does NOT accept email, first_name, last_name, etc., because it securely extracts them directly from the Google `id_token` payload).*
- **Response:** Returns standard session data (`token`, `refresh_token`, etc.).

### C. Google Login (`POST /auth/google-login`)
- **App Flow:** Trigger the Firebase SDK Google Sign-in popup/redirect. Once authenticated, obtain the `idToken`.
- **Request (Multipart Form Data):**
  - `id_token` (string) - The token received from Google/Firebase.
- **Response:** Returns standard session data (`token`, `refresh_token`).

### D. Contacts Sync (Post-Registration)
Immediately after a successful registration (Google or Email/Password), ask the user for contacts permission.
- **API to Hit:** `POST /contacts/sync`
- **Headers:** `Authorization: Bearer <access_token>`
- **Request Body (JSON):**
  ```json
  {
    "contacts": [
      { "name": "John Doe", "phone_number": "+1234567890" }
    ]
  }
  ```

### E. Standard Login (`POST /auth/login`)
- **Request (JSON):**
  - `identifier` (string) - Can be username OR email.
  - `password` (string)
- **Response:**
  - **Case 1 (Standard):** Returns `token` and `refresh_token`. Save these and enter the app.
  - **Case 2 (Legacy User):** Returns `{"needs_migration": true, "migration_token": "..."}`. See section 3 below.

---

## 3. The Legacy User Migration Flow (Must Implement)

Before Firebase was added, users signed up with just a username and password (no email). When these "Legacy" users try to log in, the backend cannot authenticate them with Firebase. 

If `POST /auth/login` returns `needs_migration: true`, your app MUST do the following:

1. **Pause the login flow.** Do not let them into the app.
2. Show a screen asking: *"Please provide your email address to secure your account."*
3. When they submit their email, call:
   `POST /auth/verify-legacy-email`
   **Headers:** `Authorization: Bearer <the_migration_token_from_login>`
   **Body:** `{"email": "user@example.com"}`
4. If successful, the backend will auto-create their Firebase account, send them a welcome email, and return the final `token` and `refresh_token` allowing them into the app.

---

## 4. Hybrid Forgot Password Flow (Do Not Skip)

You CANNOT just call the Firebase `sendPasswordResetEmail` SDK immediately, because the user might have typed a **username** (which Firebase doesn't understand), or they might be a Legacy user (who doesn't exist in Firebase yet).

**The Correct Flow:**
1. User types their username or email and clicks "Reset Password".
2. **Call the Backend First:**
   `POST /auth/forgot-password` (Requires FormData: `identifier=...`)
3. **Backend Magic:** The backend resolves the username, checks if they are a legacy user, secretly creates their Firebase account if missing, and replies with:
   `{"message": "...", "email": "their_actual_email@example.com"}`
4. **Call Firebase SDK:**
   Now that the backend guarantees the user exists in Firebase, you extract the `email` from the backend response and pass it to the Firebase SDK:
   ```dart
   await FirebaseAuth.instance.sendPasswordResetEmail(email: response.data['email']);
   ```
5. Firebase natively sends the reset link.

*(Note: The link inside the email will send the user to the custom UI domain configured in the Firebase Console Email Templates).*

---

## 5. Account Deletion (`POST /auth/delete-account`)

The app features a 15-day grace period for account deletion.
1. Call `POST /auth/delete-account` (Requires Auth header).
2. The backend marks the account as `suspended` and starts a 15-day countdown.
3. The backend returns a success message.
4. The frontend MUST then call the Firebase SDK to delete the user from the local device and Firebase servers:
   ```dart
   await FirebaseAuth.instance.currentUser?.delete();
   ```
5. Log the user out locally.

---

## 6. Device Notifications (`POST /notifications/device/register`)

Immediately after a successful login (and after storing the access token), the mobile app must register its FCM token for push notifications.

- **Request (JSON):**
  - `device_token` (string) - The FCM token generated by Firebase Cloud Messaging.
  - `device_type` (string) - "android" or "ios"
- **Headers:** `Authorization: Bearer <access_token>`
