# Main Backend API Documentation

## Overview

The Main Backend is a FastAPI application that handles the core business logic, user management, and coordination with the CV microservice. It manages the database, storage, and client-facing APIs.

**Base URL:** `http://localhost:8001` (Local)

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

**Response:**
*   Returns the created user object with details:
    ```json
    {
      "user_id": "uuid",
      "user_id": "uuid",
      "username": "jdoe",
      "email": "jdoe@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "face_id": "uuid",
      "image_id": "uuid",
      "message": "User registered successfully"
    }
    ```

### Login
**POST** `/auth/login`

Authenticate a user.

**Request (JSON):**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**
*   Returns user details and session info (simplified for prototype).

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

### Reregister Face
**POST** `/users/me/face/reregister`

Update the user's face vector by uploading a new profile photo.

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

### Confirm Share
**POST** `/images/share/confirm`

Finalize the sharing process for a batch. This triggers population of the `galleries` table for both the uploader and selected recipients.

**Request (JSON):**
```json
{
  "batch_id": "uuid",
  "recipients": ["user_id_1", "user_id_2"],
  "auto_clean": true
}
```

**Parameters:**
- `auto_clean` (boolean, default: `true`): If `true`, applies Auto Clean rules to filter which images appear in galleries.

**Response (JSON):**
```json
{
  "message": "Share confirmed",
  "recipient_count": 2
}
```

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
**GET** `/notifications`

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
