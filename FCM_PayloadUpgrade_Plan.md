# FCM Contextual Deep-Linking Payload Upgrade

Enrich every FCM push notification with structured contextual metadata so that tapping a notification on any client (Flutter, Web) deep-links the user to the exact screen, tab, and entity.

---

## Current State (Code + Schema Audit)

### Notification Types — DB Enum vs Actual Usage

The `notifications.type` column is a **PostgreSQL ENUM** (`notification_type`), not free text:

```sql
-- Current enum values (from DB.md L224):
notification_type = batch_share | friend_req_accepted | recommendation | system_alert | account_deletion
```

| Type Value | Used in Code? | FCM Push? | Notes |
|---|---|---|---|
| `batch_share` | ✅ Used for **both** uploader AND recipient | ✅ | Bug: should be split |
| `friend_req_accepted` | ✅ | ✅ | Works correctly |
| `recommendation` | ❌ Defined but unused | — | Future use |
| `system_alert` | ❌ Defined but unused | — | Future use |
| `account_deletion` | ❌ Defined but unused | — | Future use |

### Current FCM `data` Payload (All Types)

```json
{"type": "...", "resource_id": "...", "click_action": "FLUTTER_NOTIFICATION_CLICK"}
```

**Three fields total. No routing, no sender context, no screen targets.**

### Problems

1. **No routing context** — Clients cannot deep-link to any specific screen/tab
2. **`batch_share` used for both uploader AND recipient** — Client can't distinguish "you shared" from "X shared with you"
3. **No FCM push for friend requests** — Addressee only sees it when they open the app
4. **No web click-through** — Service worker shows notification but doesn't handle clicks
5. **`batch_received` not in enum** — Adding it requires a DB migration

---

## DB Migration Required

> [!IMPORTANT]
> The `notification_type` enum must be extended before the backend code changes. This is a **non-destructive** operation — existing rows are unaffected.

```sql
-- Migration: Add new notification types to the enum
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'batch_received';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'friend_request_received';
```

> [!NOTE]
> `friend_request_received` is added to the enum for future-proofing even though the current plan uses it as push-only (no DB row). If we later want to persist friend request notifications instead of constructing them virtually, the enum is ready.

---

## FCM 4KB Payload Budget

FCM enforces a **4096-byte limit** on the `data` payload.

**Largest payload estimate (`batch_received`):**

```json
{
  "type": "batch_received",
  "click_action": "FLUTTER_NOTIFICATION_CLICK",
  "route": "/friend_profile",
  "route_tab": "received",
  "sender_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "sender_username": "twentycharacteruname",
  "resource_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "photo_count": "999",
  "timestamp": "2026-05-10T18:00:00Z"
}
```

**~380 bytes** → **9.3% of 4KB limit**. Safe.

The `notification` block (title/body for OS display) has its own separate limit. We keep payloads as pure routing instructions — rich data (profile pics, galleries) is fetched client-side after navigation.

---

## Notification Payload Contract

### Universal Fields (every FCM `data` payload)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | `string` | ✅ | Notification type enum |
| `click_action` | `string` | ✅ | Always `"FLUTTER_NOTIFICATION_CLICK"` |
| `route` | `string` | ✅ | Target screen route for deep-linking |
| `route_tab` | `string` | ❌ | Tab/section within screen (empty string if N/A) |
| `sender_id` | `string` | ✅ | User ID of the person who triggered it |
| `sender_username` | `string` | ✅ | Display name (avoids extra API call for display) |
| `resource_id` | `string` | ✅ | Primary entity ID (batch_id, friendship_id, user_id) |
| `timestamp` | `string` | ✅ | ISO 8601 event time |

> [!WARNING]
> **All `data` values MUST be strings.** Firebase rejects non-string values. Numbers sent as `"5"` not `5`. Flutter parses with `int.parse()`.

### Per-Type Schemas

---

#### 1. `batch_share` — Uploader self-notification ("You shared 12 images")

| Field | Value |
|-------|-------|
| `type` | `"batch_share"` |
| `route` | `"/home"` |
| `route_tab` | `"gallery"` |
| `sender_id` | Uploader's own user_id |
| `sender_username` | Uploader's username |
| `resource_id` | batch_id |
| `photo_count` | Image count (string) |

**Flutter:** Navigate to Home → Gallery tab.

---

#### 2. `batch_received` — Recipient notification ("Alice shared 5 images with you")

| Field | Value |
|-------|-------|
| `type` | `"batch_received"` |
| `route` | `"/friend_profile"` |
| `route_tab` | `"received"` |
| `sender_id` | Uploader's user_id |
| `sender_username` | Uploader's username |
| `resource_id` | batch_id |
| `photo_count` | Image count for this recipient (string) |

**Flutter:** Navigate to sender's UserProfileScreen → "Received" tab.

---

#### 3. `friend_request_received` — New friend request (🆕 push-only)

| Field | Value |
|-------|-------|
| `type` | `"friend_request_received"` |
| `route` | `"/notifications"` |
| `route_tab` | `"requests"` |
| `sender_id` | Requester's user_id |
| `sender_username` | Requester's username |
| `resource_id` | friendship_id (as string) |

**Flutter:** Navigate to Notification screen → Friend Requests tab with Accept/Reject visible.

> [!NOTE]
> **Push-only — no DB row.** The existing `get_user_notifications` already constructs virtual `friend_request_received` entries from the `friendships` table. A DB row would cause duplicates. The push is ephemeral (notification shade only).

---

#### 4. `friend_req_accepted` — Request accepted ("Bob accepted your request")

| Field | Value |
|-------|-------|
| `type` | `"friend_req_accepted"` |
| `route` | `"/friend_profile"` |
| `route_tab` | `""` (default tab) |
| `sender_id` | The other user's ID |
| `sender_username` | The other user's username |
| `resource_id` | The other user's ID |

**Flutter:** Navigate to new friend's UserProfileScreen.

---

### Future Notification Types (Already in Enum)

These enum values exist but are unused. Payloads defined here for future use:

#### 5. `account_deletion` — Deletion scheduled/cancelled

| Field | Value |
|-------|-------|
| `type` | `"account_deletion"` |
| `route` | `"/settings"` |
| `route_tab` | `""` |
| `sender_id` | User's own ID |
| `sender_username` | User's username |
| `resource_id` | User's own ID |

**Flutter:** Navigate to Settings screen (informational — "Your account will be deleted in 15 days").

#### 6. `system_alert` — Platform announcements

| Field | Value |
|-------|-------|
| `type` | `"system_alert"` |
| `route` | `"/notifications"` |
| `route_tab` | `""` |
| `sender_id` | `"system"` |
| `sender_username` | `"Prism"` |
| `resource_id` | `""` |

**Flutter:** Navigate to Notifications screen.

---

## Flutter Routing Table (Complete Handover Reference)

| `type` | `route` | `route_tab` | Flutter Screen | Key Arguments |
|--------|---------|-------------|----------------|---------------|
| `batch_share` | `/home` | `gallery` | `HomeScreen` | `initialTab: 'gallery'` |
| `batch_received` | `/friend_profile` | `received` | `UserProfileScreen` | `userId: sender_id`, `initialTab: 'received'` |
| `friend_request_received` | `/notifications` | `requests` | `NotificationScreen` | `initialTab: 'requests'` |
| `friend_req_accepted` | `/friend_profile` | _(default)_ | `UserProfileScreen` | `userId: sender_id` |
| `account_deletion` | `/settings` | — | `SettingsScreen` | — |
| `system_alert` | `/notifications` | — | `NotificationScreen` | — |

**Yes — with this contract, your Flutter developer has everything needed to implement notification tap routing.** Each notification carries the exact screen route, the tab to focus, and the entity IDs needed to load the right data.

---

## Changes Implemented

### Database Migration

#### [NEW] [notification_type_migration.sql]

```sql
-- Extend notification_type enum with new values
-- Non-destructive: existing rows are unaffected
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'batch_received';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'friend_request_received';
```

Run on Supabase SQL Editor before deploying backend changes.

---

### Backend — Notification Service

#### [MODIFY] [notification.py]

**1. `create_batch_upload_notification` (L14-38):**
- Add sender context and routing fields to both DB `metadata` and FCM `data`
- Needs new param: `uploader_username` (fetched by caller)

**2. `create_batch_received_notification` (L40-64):**
- Change DB `type` from `"batch_share"` → `"batch_received"` (L47)
- Change FCM `data.type` from `"batch_share"` → `"batch_received"` (L62)
- Add routing + sender context to FCM `data`
- Needs new param: `uploader_id`

**3. `create_friend_accepted_notifications` (L66-108):**
- Add `route`, `sender_id`, `sender_username`, `timestamp` to FCM `data` for both participants

**4. [NEW] `create_friend_request_notification`:**
- Push-only method (no DB insert)
- Sends FCM with `type: "friend_request_received"`, `route: "/notifications"`, `route_tab: "requests"`

---

### Backend — Friend Service

#### [MODIFY] [friend.py]

**`send_friend_request` (L20-45):**
After friendship creation (L42), dispatch push via `notification_service.create_friend_request_notification()`. The `notification_service` is already injected (L12).

---

### Backend — Image Service

#### [MODIFY] [image.py]

**`process_batch_upload` (L196-235):**
- Fetch uploader username and pass to `create_batch_upload_notification`

**`confirm_share` (L519-534):**
- Pass `uploader_id` to `create_batch_received_notification`

---

### Backend — FCM Service

#### [MODIFY] [fcm.py]

**`send_multicast` (L50-70):**
Add string coercion safety net:
```python
if data:
    data = {k: str(v) for k, v in data.items() if v is not None}
```

---

### Flutter App (Handover — NOT implemented)

#### Integration Points for Flutter Developer:

**1. Handle all three FCM entry points:**
- `FirebaseMessaging.onMessageOpenedApp` (background tap)
- `FirebaseMessaging.instance.getInitialMessage()` (cold start tap)  
- `onDidReceiveNotificationResponse` (foreground tap via flutter_local_notifications)

**2. Implement `_handleNotificationRoute(data)` using the routing table above**

**3. Register named routes in `main.dart` for deep-linkable screens:**
- `/user_profile` → `UserProfileScreen(userId, initialTab)`
- `/notification_screen` → `NotificationScreen(initialTab)`

**4. (Stretch) Android notification actions for friend requests** — Accept/Reject buttons directly in the notification shade using `AndroidNotificationAction`

---