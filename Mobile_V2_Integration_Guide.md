# 📱 Prism V2: Mobile Integration Guide
**Feature Set:** Phone-First Onboarding & Contact-Sync Discovery  
**Target Audience:** Android/iOS Frontend Developers  

---

## 🗺️ High-Level Architectural Shift
In V2, Prism has moved from an **Email-centric** to a **Phone-centric** identity model. Discovery is now driven by phonebook matching (E.164 normalization) rather than manual username searches.

---

## 1. Onboarding & Registration (V2)

### **A. Signup Form Changes**
The signup flow is now "Frictionless". We have removed mandatory email/names to speed up entry.

- **Mandatory Fields:**
  - `username`: (Min 3 chars)
  - `password`: (Min 6 chars)
  - `country_code`: (Numeric, e.g., "91", "1", "44")
  - `phone_number`: (The raw digits from user input)
- **Optional Fields:** `first_name`, `last_name`, `email`.
- **Face Capture:** Single profile photo (or Multi-View WebSocket scan) is still required.

### **B. Registration Response**
The backend returns a new flag: `phone_synced: boolean`.
> [!IMPORTANT]
> If `phone_synced` is `false`, it means the phone number provided was malformed and cannot be used for discovery. The app should prompt the user to correct it in **Settings**.

---

## 2. Contact Sync Engine

This is the core of V2 discovery. Mobile apps should sync the local phonebook to the server to find friends.

### **A. Fetching Local Contacts**
1. Request native OS permissions (`READ_CONTACTS` / `CNContactStore`).
2. Extract **Display Name** and **Phone Number(s)**.
3. Construct the payload for the backend.

### **B. Endpoint: `POST /contacts/sync`**
**Payload:**
```json
{
  "user_id": "UUID-OF-LOGGED-IN-USER",
  "contacts": [
    {
      "display_name": "John Doe",
      "raw_phone": "9876543210",
      "country_code": "91"
    }
  ]
}
```

**What the Backend does:**
- Normalizes all numbers to **E.164** (e.g., `+919876543210`).
- Deduplicates the list (if "John" has two identical numbers, we only store one).
- Instantly matches against existing Prism users.

---

## 3. Social Discovery UI

The sync response (and the standalone recommendations endpoint) returns two lists:

### **A. `on_platform` (People you may know)**
Registered Prism users found in the phonebook.
- **Fields to show:** `username`, `profile_pic_id`, `mutual_contact_count`.
- **Action:** "Add Friend" (Send Request).

### **B. `not_on_platform` (Invite Targets)**
Contacts who aren't on Prism yet.
- **Invite Logic:** The API provides `whatsapp_link` and `sms_link`.
- **Action:** Open these links using native Intent/Deep linking to send pre-filled invite messages.

---

## 4. API Reference for Mobile

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/auth/register` | Multipart form for Signup. |
| `POST` | `/contacts/sync` | Bulk upload phonebook for matching. |
| `GET` | `/contacts/recommendations?user_id=...` | Fetch latest friend suggestions. |
| `GET` | `/contacts/sync-status?user_id=...` | Check if user has already granted permission. |
| `PATCH` | `/contacts/sync-status` | Update permission state (e.g., "denied"). |

---

## 5. Implementation Tips

### **Normalization Safety**
The backend uses the Google `phonenumbers` library. If the mobile app sends malformed numbers, the backend will **ignore** them rather than crash. However, for the best experience, the mobile app should use its native library to format numbers before sending.

### **Authentication (IMPORTANT)**
> [!CAUTION]
> Currently, the backend uses **Security by ID**. You must pass the `user_id` (UUID) in the request. 
> **Roadmap:** We are moving to **JWT Authentication**. Prepare your networking layer to eventually send `Authorization: Bearer <token>` and stop sending `user_id` in the body.

---
**Status:** V2 Backend is Live.  
**Docs:** Link this file to the mobile team's README.
