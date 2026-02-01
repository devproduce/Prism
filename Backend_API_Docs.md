# Main Backend API Documentation

## Overview

The Main Backend is a FastAPI application that handles the core business logic, user management, and coordination with the CV microservice. It manages the database, storage, and client-facing APIs.

**Base URL:** `http://localhost:8001` (Local) 'https://prism-main-fastapi-backend.onrender.com' (Production)

## Robustness & Error Handling
The API implements strict error handling to prevent runtime crashes:
- **Database Failures:** All critical database operations (creates/updates) are checked for success. If a record cannot be created, the API immediately returns a `500 Internal Server Error` rather than propagating invalid state.
- **Type Safety:** The codebase uses strict type hinting (`Optional`, `List`, etc.) to ensure data integrity.
- **Timezones:** All timestamps are stored and returned in UTC (`datetime.now(timezone.utc)`).


## Authentication (`/auth`)

### Register User
**POST** `/auth/register`

Register a new user with a profile photo.

**Request (Multipart/Form-Data):**
*   `username` (str): User's display name.
*   `email` (str): User's email address.
*   `password` (str): User's password.
*   `first_name` (str): User's first name.
*   `last_name` (str, optional): User's last name.
*   `image` (File): Profile photo file.
*   `face_ids` (str, optional): JSON stringified list of face IDs from multi-view registration.

**Response:**
*   Returns the created user object with details:
    ```json
    {
      "user_id": "uuid",
      "username": "jdoe",
      "email": "jdoe@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "profile_pic_id": "uuid",
      "face_id": "uuid",
      "image_id": "uuid",
      "message": "User registered successfully"
    }
    ```
*   The `profile_pic_id` points to a default SVG avatar based on the user's first name initial (A-Z).



### Multi-View Registration
**POST** `/auth/multi-view-register`

Internal endpoint called by the CV service to save face descriptors captured during the multi-view registration process.

**Request (JSON):**
```json
{
  "faces": [
    {
      "descriptor": [...], // 512-float vector
      "pose": { "pitch": 0.0, "yaw": 0.0, "roll": 0.0 },
      "quality": 0.95,
      "view": "center"
    },
    ...
  ]
}
```

**Response:**
*   Returns a list of created face IDs.
    ```json
    {
      "face_ids": ["uuid1", "uuid2", ...]
    }
    ```

### Login
**POST** `/auth/login`

Authenticate a user with username or email.

**Request (JSON):**
```json
{
  "identifier": "username OR user@example.com",
  "password": "password123"
}
```

**Response:**
*   Returns user details including profile information needed for frontend state:
    ```json
    {
      "user_id": "uuid",
      "username": "jdoe",
      "email": "jdoe@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "profile_pic_id": "uuid-or-null"
    }
    ```
*   The `profile_pic_id` field is critical for displaying user avatars in notifications and UI components.

### Check Availability
**GET** `/auth/check-availability`

Check if a username or email is available for registration. Used for real-time validation during signup.

**Query Parameters:**
*   `type` (str): Either `"username"` or `"email"`.
*   `value` (str): The username or email to check.

**Response (JSON):**
```json
{
  "available": true
}
```

**Implementation:**
*   Queries `users` table using indexed lookups (`get_user_by_username`, `get_user_by_email`).
*   Returns `false` if the value exists, `true` if available.
*   Debounced on frontend (500ms) to minimize server load.

### Verify Password
**POST** `/auth/verify-password`

Verify a user's password without returning user data. Used for hidden archive unlock via the header searchbar.

**Request (Form Data):**
*   `user_id` (str): ID of the user.
*   `password` (str): Password to verify.

**Response (JSON):**
```json
{
  "valid": true
}
```

**Implementation:**
*   Hashes the provided password and compares it against the stored hash.
*   Returns `true` if password matches, `false` otherwise.
*   Used by the frontend to unlock the hidden archive when user types their password in the searchbar and presses Enter.

## Users (`/users`)

### Get Current User
**GET** `/users/me`

Get details of the currently authenticated user.

**Query Parameters:**
*   `user_id` (str): ID of the user.

**Response (JSON):**
```json
{
  "id": "uuid",
  "username": "jdoe",
  "email": "jdoe@example.com",
  "created_at": "timestamp",
  ...
}
```

### Get User By ID
**GET** `/users/{user_id}`

Get user details by user ID.

**Path Parameters:**
*   `user_id` (str): ID of the user.

**Response (JSON):**
```json
{
  "id": "uuid",
  "username": "jdoe",
  "email": "jdoe@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "pronouns": "he/him",
  "bio": "User bio text",
  "dob": "1990-01-01",
  "profile_pic_id": "uuid",
  "country_code": "+1",
  "phone_number": "1234567890",
  "created_at": "2024-01-15T10:30:00Z",
  "photos_count": 42,
  "friends_count": 15
}
```

**Error Responses:**
*   `404 Not Found`: User with the specified ID does not exist.

### Update Profile
**PUT** `/users/me`

Update user profile information.

**Request (Form Data):**
*   `user_id` (str): ID of the user.
*   `username` (str, optional)
*   `first_name` (str, optional)
*   `last_name` (str, optional)
*   `pronouns` (str, optional)
*   `bio` (str, optional)
*   `dob` (date string, optional)
*   `country_code` (str, optional)
*   `phone_number` (str, optional)

**Note:** Email is NOT editable via this endpoint. It is a read-only field tied to authentication.

### Upload Profile Picture
**POST** `/users/me/profile-picture`

Upload a profile picture without CV processing (avatar only, not face ID).

**Request (Multipart/Form-Data):**
*   `user_id` (str): ID of the user.
*   `image` (File): Profile picture file.

**Business Logic:**
*   Uploads image to S3 root directory.
*   Creates `images` table record.
*   Updates `users.profile_pic_id` with new image ID.
*   **Does not** trigger CV face detection or update biometric data.

### Reset Profile Picture
**DELETE** `/users/me/profile-picture`

Reset the user's profile picture to their default avatar (based on first name initial).

**Request (Form Data):**
*   `user_id` (str): ID of the user.

**Business Logic:**
*   Looks up the default avatar SVG based on the user's first name initial.
*   Updates `users.profile_pic_id` to point to the default avatar image.

**Response (JSON):**
```json
{
  "message": "Profile picture reset to default",
  "profile_pic_id": "uuid-of-default-avatar"
}
```

> **Note:** The default avatar system uses pre-generated SVG images stored in S3 under `default-profile-pics/`. Each SVG displays a capitalized letter (A-Z, 0-9, or #) with the Prism Yellow color (#F3E68F) on a dark background (#121212). These avatars are assigned automatically during user registration and when resetting the profile picture.

### Reregister Face
**POST** `/users/me/face/reregister`

Update the user's face vector by uploading a new profile photo. This updates biometric data for face recognition only—**it does not change the profile picture**.

**Request (Multipart/Form-Data):**
*   `user_id` (str): ID of the user.
*   `image` (File): New profile photo.

### Add Contact
**POST** `/users/me/contacts`

Add a new contact for the user.

**Request (Form Data):**
*   `user_id` (str)
*   `full_name` (str)
*   `phone_number` (str)
*   `country_code` (str, optional)

### Get Contacts
**GET** `/users/me/contacts`

Get a list of the user's contacts.

**Query Parameters:**
*   `user_id` (str)

### Add Contacts Batch
**POST** `/users/me/contacts/batch`

Add multiple contacts in a single request for efficient syncing.

**Request (Form Data):**
*   `user_id` (str): ID of the user.
*   `contacts` (str): JSON stringified array of contact objects.

**Example:**
```json
{
  "user_id": "uuid",
  "contacts": "[{\"full_name\": \"John Doe\", \"phone_number\": \"1234567890\", \"country_code\": \"+1\"}, {\"full_name\": \"Jane Smith\", \"phone_number\": \"9876543210\", \"country_code\": \"+1\"}]"
}
```

**Response:**
```json
{
  "success_count": 500,
  "failed_count": 0,
  "failed_items": []
}
```

**Business Logic:**
- Accepts an array of contacts and inserts them in a single database transaction
- Significantly reduces network overhead compared to individual requests
- Ideal for syncing phone contacts when user has hundreds of contacts


## Friends (`/friends`)

### Search Friends
**GET** `/friends/search`

Search for users by username.

**Query Parameters:**
*   `username` (str)
*   `user_id` (str): ID of the requesting user (to exclude self).

### Send Friend Request
**POST** `/friends/request`

Send a friend request to another user.

**Request (JSON):**
```json
{
  "user_id": "uuid",
  "username": "target_username"
}
```

### Get Friends
**GET** `/friends`

Get a list of accepted friends.

**Query Parameters:**
*   `user_id` (str)

### Get Sent Requests
**GET** `/friends/sent`

Get a list of pending requests sent by the user. Used to populate "Pending" status in UI.

**Query Parameters:**
*   `user_id` (str)

### Accept Friend Request
**POST** `/friends/{friendship_id}/accept`

Accept a received friend request.

**Request (JSON):**
```json
{
  "user_id": "uuid"
}
```

### Reject Friend Request
**POST** `/friends/{friendship_id}/reject`

Reject/Decline a received friend request.

**Request (JSON):**
```json
{
  "user_id": "uuid"
}
```

## Images (`/images`)

### Upload Images (Batch)
**POST** `/images/upload`

Upload a batch of images for processing.

**Request (Multipart/Form-Data):**
*   `user_id` (str)
*   `description` (str, optional)
*   `images` (List[File]): List of image files.

**Response:**
```json
{
  "batch_id": "uuid",
  "status": "processing_started"
}
```

### Get Gallery
**GET** `/images/gallery`

Get all images in the user's personal gallery. Images are filtered through the **Galleries Table**, which acts as a junction table controlling which images appear in which user's gallery based on:
- Images the user uploaded
- Images containing the user's face
- Auto Clean rules (if enabled during sharing)

**Query Parameters:**
*   `user_id` (str)
*   `favourite` (bool, optional): Filter by favorite status.
*   `archive` (bool, optional): Filter by archive status.
*   `bin` (bool, optional): Filter by bin status.

**Response:**
Returns an array of gallery items, each containing:
```json
[
  {
    "image": {
      "id": "uuid",
      "storage_path": "filename.jpg",
      "image_url": "https://presigned-url",
      "taken_at": "2024-01-15T10:30:00Z",
      "width": 1920,
      "height": 1080,
      "metadata": {...}
    },
    "faces": [...],
    "gallery_meta": {
      "favourite": false,
      "archive": false,
      "bin": false
    }
  }
]
```

**Implementation Notes:**
- Uses **presigned URLs** from S3 for secure image access
- Includes EXIF metadata (taken_at, dimensions) extracted during upload
- Bulk fetches faces to avoid N+1 queries

### Toggle Image Status
**POST** `/images/{image_id}/toggle/{field}`

Toggle a status flag for an image in the user's gallery.

**Path Parameters:**
*   `image_id` (str): ID of the image.
*   `field` (str): The field to toggle (`favourite`, `archive`, `bin`).

**Request (Form Data):**
*   `user_id` (str)

**Response:**
*   Returns the updated boolean value of the field.

### Batch Update Status
**POST** `/images/batch/update`

Update the status of multiple images at once.

**Request (JSON):**
```json
{
  "user_id": "uuid",
  "image_ids": ["uuid1", "uuid2"],
  "field": "favourite",
  "value": true
}
```

### Empty Bin
**POST** `/images/bin/empty`

Delete all images in the user's bin (removes them from the gallery, does not delete files).

**Request (Form Data):**
*   `user_id` (str)

### Batch Delete (Permanent)
**POST** `/images/batch/delete`

Permanently remove specific images from the user's gallery.

**Request (JSON):**
```json
{
  "user_id": "uuid",
  "image_ids": ["uuid1", "uuid2"]
}
```

### Update Image Description
**PATCH** `/images/{image_id}/description`

Update the description of an image (uploader only).

**Path Parameters:**
*   `image_id` (str): ID of the image.

**Request (Form Data):**
*   `user_id` (str)
*   `description` (str)

**Response:**
*   Returns the updated image object.

### Get Shared Gallery
**GET** `/images/friend/{friend_id}`

Get images shared between the current user and a friend.

**Query Parameters:**
*   `user_id` (str)

### Check Batch Status
**GET** `/images/batch/{batch_id}`

Check the status of a background processing batch.

**Authorization:**
- Required. `user_id` query parameter must match the batch's `shared_by` field.
- Returns `403 Forbidden` if the requesting user does not own the batch.

**Query Parameters:**
- `user_id` (str, required): UUID of the requesting user for authorization.

**Response (JSON):**
```json
{
  "batch_id": "uuid",
  "status": "completed",
  "images": [
    {
      "id": "uuid",
      "url": "https://..."
    }
  ],
  "recipients": [
    {
      "user_id": "uuid",
      "username": "friend_name",
      "count": 3
    }
  ],
  "contacts": [
    {
      "user_id": "uuid",
      "username": "contact_name"
    }
  ],
  "unknowns": [
    {
      "face_id": "uuid",
      "image_url": "https://..."
    }
  ]
}
```

### Cancel Batch
**DELETE** `/images/batch/{batch_id}/cancel`

Cancel a batch upload and permanently delete all associated data ("zombie" cleanup).

**Authorization:**
- Required. `user_id` form parameter must match the batch's `shared_by` field.
- Returns `403 Forbidden` if the requesting user does not own the batch.

**Body (FormData):**
- `user_id` (str, required): UUID of the authenticated user.

**Response (JSON):**
```json
{
  "message": "Batch cancelled and data cleaned up",
  "deleted_images": 3,
  "deleted_s3_files": 3
}
```

**Business Logic:**
- Verifies batch ownership before deletion
- Performs cascading deletion in the following order:
  1. Delete S3 objects for all images in the batch
  2. Delete `image_faces` records linking images to faces
  3. Delete `batch_share_faces` records
  4. Delete `batch_share_images` records
  5. Delete orphaned `faces` records (only unassigned faces created in this batch)
  6. Delete `images` records
  7. Delete the `batch_shares` record itself
- Prevents "zombie data" accumulation when users abandon the share flow

### Confirm Share
**POST** `/images/share/confirm`

Finalize the sharing process for a batch. This triggers population of the `galleries` table for both the uploader and selected recipients.

**Authorization:**
- Required. `user_id` in request body must match the batch's `shared_by` field.
- Returns `403 Forbidden` if the requesting user does not own the batch.

**Request (JSON):**
```json
{
  "batch_id": "uuid",
  "user_id": "uuid",
  "recipients": ["user_id_1", "user_id_2"],
  "auto_clean": true,
  "image_recipient_map": {
    "image_id_1": ["user_id_1", "favourite"],
    "image_id_2": ["user_id_1", "user_id_2", "archive", "bin"]
  }
}
```

**Parameters:**
- `user_id` (str, required): UUID of the authenticated user (for authorization).
- `recipients` (array, required): List of user IDs who are globally enabled to receive images.
- `auto_clean` (boolean, default: `true`): If `true`, applies Auto Clean rules to filter which images appear in galleries.
- `image_recipient_map` (object, optional): Per-image assignment map. Keys are image IDs, values are arrays containing:
  - User IDs for recipient overrides
  - Album flags: `"favourite"`, `"archive"`, `"bin"` (special strings, not UUIDs)
  - When album flags are present, they are applied to the uploader's gallery entry for that image

**Response (JSON):**
```json
{
  "message": "Share confirmed",
  "recipient_count": 2
}
```

**Business Logic:**
- Album flags (`favourite`, `archive`, `bin`) are extracted from `image_recipient_map` values and applied to the uploader's gallery entry.
- Remaining entries (user IDs) are used for recipient gallery population.
- If `image_recipient_map` is provided, uses explicit image-to-recipient mappings instead of relying solely on face detection.
- Each image is added to a recipient's gallery only if: (1) the recipient is in the image's override list OR (2) no override exists and the recipient's face was detected in the image.
- Maintains backward compatibility: if `image_recipient_map` is not provided, falls back to legacy face-based detection.
- Auto Clean rules still apply to the uploader's gallery regardless of override settings.

## Galleries Table Logic

The `galleries` table is a junction table that controls image visibility for each user. It populates automatically during the share confirmation process.

### Auto Clean Rules

When `auto_clean` is enabled, images are filtered as follows:

**For the Uploader:**
1. **No faces detected** → Keep (landscape/object photos)
2. **User is in the image** → Keep
3. **Any person in the user's "keep list" is in the image** → Keep
4. **Otherwise** → Don't add to gallery

**For Recipients:**
- Recipients only get images where **their face appears**

**"Keep List" Definition:**
The keep list contains user IDs of friends based on the `friendships` table's `keep` field:
- `NULL`: No special rules
- `requester`: Requester marked addressee as "keep"
- `addressee`: Addressee marked requester as "keep"
- `both`: Both marked each other

When `auto_clean` is disabled, **all images** from the batch are added to the uploader's gallery regardless of faces.

## Friends (`/friends`)

### Search Users
**GET** `/friends/search`

Search for other users by username.

**Query Parameters:**
*   `username` (str): Search query.
*   `user_id` (str): ID of the requesting user (to exclude self).

### Send Friend Request
**POST** `/friends/request`

Send a friend request to another user.

**Request (JSON):**
```json
{
  "user_id": "requester_uuid",
  "username": "target_username"
}
```

### Get Friends
**GET** `/friends`

Get a list of accepted friends.

**Query Parameters:**
*   `user_id` (str)

### Get Pending Requests
**GET** `/friends/pending`

Get a list of pending friend requests.

**Query Parameters:**
*   `user_id` (str)

## Notifications (`/notifications`)

### Get Notifications
**GET** `/notifications` (No trailing slash)

*Note: This endpoint is strictly configured to accept paths without a trailing slash to prevent HTTP 307 redirects when running behind SSL proxies.*

Get user notifications (e.g., friend requests).

**Query Parameters:**
*   `user_id` (str)

### Accept Friend Request
**POST** `/notifications/{notification_id}/accept`

Accept a friend request notification.

**Request (JSON):**
```json
{
  "user_id": "uuid"
}
```

### Reject Friend Request
**POST** `/notifications/{notification_id}/reject`

Reject a friend request notification.

**Request (JSON):**
```json
{
  "user_id": "uuid"
}
```

### Mark Notifications Read
**POST** `/notifications/mark-read`

Mark all notifications as read for the current user.

**Request (JSON):**
```json
{
  "user_id": "uuid"
}
```

## Notification Service Logic

The `NotificationService` handles the creation and retrieval of user notifications.

**Key Features:**
- **Hybrid Fetching:** `get_user_notifications` combines persisted notifications (from `notifications` table) with live pending friend requests (from `friendships` table) to provide a unified activity feed.
- **Auto-Generation:** Notifications are automatically generated for:
    - Friend Request Accepted (`friend_req_accepted`)
    - Batch Shared (`batch_shared`)
    - Batch Received (`batch_received`)
- **Smart Filtering:** The service filters out duplicate "friend request received" notifications if a live pending request already exists, preventing clutter.

---

## Video Upload Support

The backend supports uploading and processing videos alongside images through the existing `/images/upload` endpoint.

### Storage Service Changes (`services/storage.py`)

The `upload_image()` method now accepts an optional `original_filename` parameter:
```python
def upload_image(self, file: BytesIO, user_id: str, folder: str = "images", original_filename: str = "") -> str:
```

**Behavior:**
- Preserves original file extension (`.mp4`, `.mov`, etc.) instead of forcing `.jpg`
- Uses `mimetypes.guess_type()` for correct Content-Type headers
- Videos stored in `videos/` subfolder: `videos/uuid_timestamp.mp4`

### Metadata Extraction (`utils/metadata.py`)

The `extract_metadata()` function now detects file type by extension:
```python
def extract_metadata(file_bytes: BytesIO, filename: str = "") -> Dict[str, Any]:
```

**Behavior:**
- Images: Standard PIL/EXIF extraction
- Videos: OpenCV extraction (dimensions, duration) with graceful fallback
- `VIDEO_EXTENSIONS = {'.mp4', '.avi', '.mov', '.mkv', '.webm', '.m4v', '.wmv', '.flv'}`

### CV Client (`services/cv_client.py`)

The `process_batch()` method uses `media_data` parameter for unified pipeline:
```python
data = {
    "batch_id": batch_id,
    "user_id": user_id,
    "media_data": json.dumps(media_data),  # Supports images and videos
    "known_faces": json.dumps(known_faces)
}
```

## Engagement (`/engagement`)

Public endpoints for collecting waitlist signups and user feedback. No authentication required.

### Join Waitlist
**POST** `/engagement/waitlist`

Add an email to the waitlist for early access.

**Request (JSON):**
```json
{
  "email": "user@example.com",
  "source": "landing_navbar"
}
```

**Response (JSON):**
```json
{
  "success": true,
  "message": "Successfully joined the waitlist!"
}
```

**Error Responses:**
- `409 Conflict`: Email already enrolled in waitlist.
- `422 Unprocessable Entity`: Invalid email format.

**Implementation:**
- Captures `ip_address` and `user_agent` from request headers automatically.
- Source field tracks where the submission originated (`landing_navbar`, `landing_cta`).

---

### Submit Feedback
**POST** `/engagement/feedback`

Submit feedback from landing page or dashboard.

**Request (JSON):**
```json
{
  "email": "user@example.com",
  "user_id": null,
  "feedback_type": "feature_request",
  "category": "ui",
  "message": "Please add dark mode toggle",
  "source": "landing_cta"
}
```

**Parameters:**
- `email` (string, optional): Required if `user_id` not provided.
- `user_id` (string, optional): Required if `email` not provided. Auto-populated from auth context in dashboard.
- `feedback_type` (string, required): One of `bug_report`, `feature_request`, `general`, `complaint`, `praise`.
- `category` (string, optional): One of `ui`, `performance`, `feature`, `other`.
- `message` (string, required): The feedback content.
- `source` (string, optional): Where the feedback originated (`landing_cta`, `dashboard`).

**Response (JSON):**
```json
{
  "success": true,
  "id": 123,
  "message": "Thank you for your feedback!"
}
```

**Error Responses:**
- `400 Bad Request`: Neither email nor user_id provided, or invalid feedback_type/category.

**Implementation:**
- Captures `ip_address` and `user_agent` from request headers automatically.
- Sets initial `status` to `new` for admin triage.

---

## Database Tables (Engagement)

### `waitlist` Table
| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| email | VARCHAR(255) | Unique, not null |
| source | VARCHAR(50) | Where signup originated |
| ip_address | INET | Client IP |
| user_agent | TEXT | Browser/client info |
| created_at | TIMESTAMPTZ | Signup timestamp |
| converted_at | TIMESTAMPTZ | When user registered (nullable) |
| user_id | UUID | FK to users if converted (nullable) |

### `feedback` Table
| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| user_id | UUID | FK to users (nullable for anonymous) |
| email | VARCHAR(255) | Email if no user_id |
| feedback_type | feedback_type | Enum: bug_report, feature_request, general, complaint, praise |
| category | VARCHAR(50) | Optional category |
| message | TEXT | Feedback content |
| source | VARCHAR(50) | Where feedback originated |
| priority | feedback_priority | Enum: low, medium, high, critical |
| status | feedback_status | Enum: new, in_progress, resolved, closed |
| ip_address | INET | Client IP |
| user_agent | TEXT | Browser/client info |
| created_at | TIMESTAMPTZ | Submission timestamp |
| metadata | JSONB | Additional context |
