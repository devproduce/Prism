# Backend API Modifications & Integration Guide

This document outlines the recent changes to the Backend API and provides instructions for integrating them into the application.

## 1. Updated: Confirm Share Endpoint (`/images/share/confirm`)

### **What's New?**
The `Confirm Share` endpoint now accepts an optional `image_recipient_map`. This allows specific images to be explicitly shared with specific recipients, overriding the default face-detection logic.

### **New Request Structure**
**POST** `/images/share/confirm`

```json
{
  "batch_id": "uuid",
  "user_id": "uuid",
  "recipients": ["user_id_1", "user_id_2"],
  "auto_clean": true,
  "image_recipient_map": {
    "image_id_1": ["user_id_1"],
    "image_id_2": ["user_id_1", "user_id_2"]
  }
}
```

### **Integration Instructions**
*   **Frontend Share Flow:** If you implement a feature allowing users to manually select which friend gets which photo (overriding auto-detection), construct the `image_recipient_map` object.
*   **Map Format:** Keys are `image_id`s, and values are arrays of `user_id`s.
*   **Fallback:** If this map is omitted, the backend defaults to the existing behavior (assigning images based on face detection + "keep lists").

---

## 2. New: Video Upload Support

### **What's New?**
The backend now supports video uploads through the existing `/images/upload` endpoint. It automatically detects video extensions, preserves them, and extracts appropriate metadata (duration, dimensions) using OpenCV.

### **Integration Instructions**
*   **File Picker:** Update your file picker to allow video extensions (`.mp4`, `.mov`, `.avi`, etc.) alongside images.
*   **Upload Endpoint:** Continue using `/images/upload` for both images and videos. No URL change is required.
*   **Display:** When fetching galleries, check the file extension or metadata to render a video player instead of an image tag for video items.

---

## 3. New: Engagement Endpoints (`/engagement`)

A new set of public endpoints has been added to handle waitlist signups and user feedback. These do not require authentication headers if `user_id` is not present (for waitlist) or optional.

### **A. Join Waitlist**
**POST** `/engagement/waitlist`

Used for landing pages or pre-login interest.

**Request:**
```json
{
  "email": "user@example.com",
  "source": "landing_navbar"
}
```

### **B. Submit Feedback**
**POST** `/engagement/feedback`

Used for bug reports, feature requests, or general feedback from within the app or landing page.

**Request:**
```json
{
  "email": "user@example.com", 
  "user_id": "uuid (optional, if logged in)",
  "feedback_type": "feature_request",
  "category": "ui",
  "message": "Please add dark mode toggle",
  "source": "dashboard"
}
```

*   **`feedback_type` options:** `bug_report`, `feature_request`, `general`, `complaint`, `praise`
*   **`category` options:** `ui`, `performance`, `feature`, `other`

### **Integration Instructions**
*   **Waitlist Form:** Connect your landing page email input to the Waitlist endpoint.
*   **Feedback Widget:** Create a "Send Feedback" modal or screen in the app settings. 
    *   Auto-fill `user_id` if the user is logged in.
    *   Allow the user to select the `type` and `category` via dropdowns.
