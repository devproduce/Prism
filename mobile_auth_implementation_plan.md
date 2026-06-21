# Mobile Auth Migration: End-to-End Implementation Plan

This document outlines the step-by-step implementation plan to sync the mobile application with the new Firebase-based backend authentication architecture. 

## Backend Clarifications & Gaps Addressed

Before starting, here are the direct answers to your questions regarding backend behavior:

> **Q:** For mobile clients, is `refresh_token` returned in the JSON response body (not as a cookie)? Confirm the exact response shape.
**Backend Answer:** YES. The backend explicitly returns the `refresh_token` alongside the `access_token` inside the JSON response body for all authentication endpoints (`/login/verify`, `/register`, `/google-register`, `/google-login`, `/migrate-email`, `/refresh`). Mobile must extract it from the JSON body and store it securely.

> **Q:** Token refresh flow: is `refresh_token` sent in the body or header?
**Backend Answer:** It must be sent in the JSON body. The endpoint is `POST /auth/refresh` with the payload: `{ "refresh_token": "<your_stored_token>" }`.

> **Q:** Is there any "silent" migration path anymore?
**Backend Answer:** NO. All silent migration logic has been completely stripped from the backend. Every single legacy user must explicitly pass through the "Secure Your Account" screen to create a Firebase identity.

> **Q:** Legacy users not yet migrated: do they still use the old password verification endpoint for account deletion?
**Backend Answer:** NO. Legacy users are **hard-blocked** from accessing the `DELETE /auth/delete-account` endpoint. The global backend middleware requires a valid Firebase JWT with `email_verified: true` for all protected routes. A legacy user attempting to delete their account will be hit with a 403 Forbidden and forced to complete the email migration and verification flow *before* they can delete their account.

---

## Phase 1: Networking Layer Overhaul

This is the foundation. Complete this before touching any UI screens.

### 1. Secure Token Storage Setup
- Implement a secure storage wrapper (e.g., `react-native-keychain` or `expo-secure-store`).
- **Rules:**
  - `access_token` -> Can be kept in memory or standard async storage (expires in 15 mins).
  - `refresh_token` -> **MUST** be stored in iOS Keychain / Android Keystore.

### 2. Global Request Interceptor (Auth Header Migration)
- Audit all existing API calls. Remove `user_id` from request bodies, query params, and paths where it was used for auth.
- Inject `Authorization: Bearer <access_token>` into every protected request.

### 3. Global 401 (Token Expiry) Interceptor
- **Mutex / Promise Queueing (Critical):** Implement a single in-flight Promise to prevent simultaneous 401 failures from triggering multiple refresh calls.
- When a request returns `401 Unauthorized`:
  1. Check a local `isRefreshing` lock. If true, append this request to a `refreshSubscribers` array and wait. If false, set `isRefreshing = true` and proceed.
  2. Retrieve `refresh_token` from Secure Storage.
  3. Call `POST /auth/refresh` with `{ "refresh_token": "..." }`.
  4. If successful: Save new tokens, update the queue with the new `access_token`, retry all queued requests, and release the lock.
  5. If failed (refresh revoked/expired): Clear secure storage, flush queue, and force logout to the login screen.

### 4. Global 429 (Rate Limiting) Handling
- Intercept `429 Too Many Requests`.
- Emit a global event or return a standardized error to trigger a UI toast: *"Too many attempts, please wait a moment and try again"*.
- Do NOT auto-retry in a loop.

### 5. Global 403 "Email Not Verified" Handling
- **State Scoping (Critical):** `has_firebase_account` is returned during `/auth/legacy-login` and `/auth/resolve-username`. It must be stored in local session state (scoped to the logged-in user, NOT globally). Upon successful `/auth/migrate-email`, immediately mutate this local state to `true`. On logout or account switch, this flag MUST be wiped.
- Intercept `403 Forbidden`. If the error message is specifically `"Email not verified"`:
  1. Check local user state: `has_firebase_account`.
  2. If `has_firebase_account === false`: Force redirect to **Phase 3: Secure Your Account (Migration)**.
  3. If `has_firebase_account === true`: Force redirect to **Phase 2: Verify Your Email**.

---

## Phase 2: Registration Screens

### 1. Classic Registration
- Ensure the registration form includes `email`, `username`, and `password`.
- Note: Face scan/multi-view logic remains unchanged, but the final submission goes to `POST /auth/register`.
- Upon success, save tokens and redirect to "Verify Your Email".

### 2. Google Registration
- **Step 1:** Trigger native Google Sign-In SDK; extract Firebase `idToken`.
- **Step 2:** Call `POST /auth/google-login { id_token }`.
- **Step 3:** If backend returns `{ exists: false }`, navigate to a new "Complete Profile" screen (Username Picker + Face Scan).
- **Step 4:** Submit `POST /auth/google-register { id_token, username, face_data }`. Save tokens. (Skips email verification).

### 3. New "Verify Your Email" Screen
- **Triggered when:** Exclusively triggered by the **Global 403 Interceptor** (Phase 1). After registration/login, the app should simply assume success and try to load the home feed. The backend will reject it with a 403, and the interceptor will drop the user here. This ensures a single source of truth and DRY routing.
- **Auto-Resume Flow:** If the user closes the app unverified and reopens it days later, the app will attempt to fetch data using the stored token, immediately receive a 403, and self-heal by instantly dropping the user exactly back onto this "Verify Your Email" screen.
- **UI:** Show *"Check your inbox to verify your email."* Include a "Resend Email" button calling `POST /auth/resend-verification`.
- **Action:** An "I've Verified" button. When tapped:
  1. Call `currentUser.reload()` via Firebase SDK.
  2. If `currentUser.emailVerified === true`, fetch a fresh `idToken`, call `POST /auth/login/verify`, save new tokens, and enter the app.

---

## Phase 3: Login Screens

### 1. Classic Login Flow
- User enters `username`. Call `POST /auth/resolve-username`.
- **Branch A (Classic):** Returns `{ email }`. Show password field. Use `signInWithEmailAndPassword(auth, email, password)`. Get `idToken`, send to `/auth/login/verify`.
- **Branch B (Google):** Returns `{ error: "USE_GOOGLE" }`. Show UI prompting Google Sign-In.
- **Branch C (Legacy):** Returns `{ needs_migration: true, migration_token, has_firebase_account: false }`. Proceed to Migration Flow.

### 2. Google Login
- Trigger native Google Sign-In SDK. Send `idToken` to `POST /auth/google-login`.
- If user doesn't exist, route to Google Registration (Phase 2).

### 3. New "Secure Your Account" (Migration) Screen
- **Triggered by:** Branch C above, or global 403 interceptor.
- **UI:**
  - Pre-fill email field if the backend provided one, but ensure it is **editable**. 
  - Add a password field (can be their old password or a new one).
- **Action:** Submit to `POST /auth/migrate-email { migration_token, email, password }`. 
- **Next Step:** Save tokens and route to "Verify Your Email" screen.

---

## Phase 4: Forgot Password

### 1. API Update
- Update UI to accept either a username or an email.
- Call `POST /auth/forgot-password { identifier }`.
- **Crucial:** Always display a generic success message: *"If that account exists, a reset link has been sent."* Do not display API errors indicating user not found.

### 2. Mobile Handling
- There is no in-app flow for resetting the password. The user clicks the email link, which opens a browser webpage. 
- Ensure the app provides a button to return to the Login screen so the user can log in with their newly reset password.

---

## Phase 5: Account Deletion Re-Auth

### 1. Pre-Deletion Authentication Wall
- Before calling `DELETE /auth/delete-account`, check `user.auth_provider`.
- **If Classic:**
  - Prompt for password.
  - Call `reauthenticateWithCredential(currentUser, EmailAuthProvider.credential(email, password))`.
- **If Google:**
  - Prompt user to tap "Re-authenticate with Google".
  - Trigger Google Sign-In SDK to get fresh credentials and call `reauthenticateWithCredential`.
- **If successful:** Proceed with API call.
- **If Legacy:** (Addressed above in Backend Clarifications) They will never reach this screen without migrating first.

### 2. Cancel Deletion
- This remains unchanged regarding the 15-day grace period logic.
- **Crucial Backend Confirmation:** The backend API (`POST /auth/cancel-deletion`) has officially been updated and strictly expects `{ "firebase_token": "<token>" }`. It no longer accepts a plaintext password. The mobile app must trigger the same Firebase re-authentication popup/flow as `delete-account` to fetch an `idToken` to pass as the `firebase_token`.
