# 📱 Prism: Flutter Contacts & Recommendations Integration Guide

This guide is prepared for the Flutter developer integrating the V2 Contacts Sync, Social Discovery, and Retroactive Sharing system with the Prism FastAPI backend.

---

## 🗺️ System & Architectural Overview

Prism V2 has migrated from an **Email-centric** identity model to a **Phone-centric** model. Social discovery is powered by scanning the user's local phonebook, normalizing numbers to the **E.164** format, and checking matches on the server.

### 🗄️ Database Table Reference
To understand where data goes, the backend manages contacts using:
1. **`phone_registry`**: Maps unique E.164 phone numbers (e.g. `+919876543210`) to registered Prism `user_id`s.
2. **`contact_uploads`**: Maps an uploader's `user_id` to the `phone_registry` ID and stores the contact's custom `display_name` as saved on their phone.
3. **`contact_sync_log`**: Tracks when a user last synchronized their phonebook and holds the count of synced contacts.
4. **`dismissed_recommendations`**: Stores pairs of `(user_id, dismissed_user_id)` to permanently hide "People You May Know" suggestions that were swiped away or closed.

---

## 🛑 Critical Mismatches & Bugs Identified

We audited the backend router code and compared it to your current Flutter frontend code. The following **critical compilation and runtime bugs** must be fixed before the contact sync system will function:

### 1. Key Mismatch in `PATCH /contacts/sync-status`
* **The Bug:** In `api_client.dart` (`updateContactSyncStatus`), the JSON payload is encoded as `{'user_id': userId, 'status': status}`.
* **The Backend Expectation:** The FastAPI endpoint expects `SyncStatusUpdateRequest`, which requires the key **`permission_status`**, not `status`.
* **The Result:** The backend rejects the request with a `422 Unprocessable Entity` or `400 Bad Request` validation error.

### 2. Missing Methods in `api_client.dart`
* **The Bug:** The providers call several methods on `ApiClient` that are completely missing:
  - `FriendsProvider` calls `_apiClient.dismissRecommendation(...)`.
  - `ActivityFeedProvider` calls `_apiClient.acceptRetroactiveShare(...)` and `_apiClient.markNotificationReadSingle(...)`.
* **The Result:** The Flutter application will fail to compile or throw runtime errors when users trigger these actions.

### 3. Non-Existent Legacy Endpoints in Client
* **The Bug:** In `api_client.dart`, there are legacy methods mapping to `/users/me/contacts` (`addContact`, `getContacts`, `addContactsBatch`). These endpoints **do not exist** on the backend router.
* **The Result:** Calling `getContacts` throws a `404 Not Found` exception.
* **The Impact:** In `contact_service.dart`, `hasContactsInBackend` calls `_apiClient.getContacts(userId: userId)`. Since that endpoint does not exist, the check will always fail.

### 4. Naming Mismatch in Providers
* **The Bug:** In `friends_provider.dart` (line 754), the provider calls `_contactService.hasContactsStoredOnBackend(userId)`. However, the method inside `contact_service.dart` is named `hasContactsInBackend(userId)`.
* **The Result:** compilation error: *Class 'ContactService' has no instance method 'hasContactsStoredOnBackend'.*

---

## 🛠️ Step-by-Step Code Corrections

Below are the complete, drop-in replacement implementations to resolve these mismatches.

### Step 1: Update the API Client (`lib/api/api_client.dart`)

Replace your V2 contact & notifications endpoints section with this corrected code. It adds the missing methods, removes the obsolete `/users/me/contacts` endpoints, and fixes the `permission_status` parameter:

```dart
  // ==================== V2 CONTACT DISCOVERY ENDPOINTS ====================

  /// Bulk upload phonebook for contact matching
  /// POST /contacts/sync
  /// Returns on_platform (Prism users) and not_on_platform (invite targets)
  Future<ContactSyncResult> syncContacts({
    required String userId,
    required List<Map<String, String>> contacts,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/contacts/sync');
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({'user_id': userId, 'contacts': contacts}),
      );

      final data = _handleResponse(response);
      return ContactSyncResult.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Contact sync failed: ${e.toString()}');
    }
  }

  /// Fetch latest friend suggestions (cached by backend from last sync)
  /// GET /contacts/recommendations?user_id=...
  Future<ContactSyncResult> getContactRecommendations({
    required String userId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/contacts/recommendations',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.get(uri, headers: _getHeaders());
      final data = _handleResponse(response);
      return ContactSyncResult.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get recommendations: ${e.toString()}');
    }
  }

  /// Check if user has already granted contacts permission and how many contacts are synced
  /// GET /contacts/sync-status?user_id=...
  Future<Map<String, dynamic>> getContactSyncStatus({
    required String userId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/contacts/sync-status',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.get(uri, headers: _getHeaders());
      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get sync status: ${e.toString()}');
    }
  }

  /// Update contacts permission state
  /// PATCH /contacts/sync-status
  /// Expects 'permission_status' key in request body
  Future<void> updateContactSyncStatus({
    required String userId,
    required String status, // 'granted', 'denied', or 'never_asked'
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/contacts/sync-status');
      final response = await _client.patch(
        uri,
        headers: _getHeaders(),
        body: json.encode({
          'user_id': userId, 
          'permission_status': status // FIXED: backend expects permission_status
        }),
      );
      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to update sync status: ${e.toString()}');
    }
  }

  /// Dismiss a recommended user so they do not show up in suggestions again
  /// POST /contacts/recommendations/dismiss
  Future<void> dismissRecommendation({
    required String userId,
    required String dismissedUserId,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/contacts/recommendations/dismiss');
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({
          'user_id': userId,
          'dismissed_user_id': dismissedUserId,
        }),
      );
      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to dismiss recommendation: ${e.toString()}');
    }
  }

  /// Accept retroactive photo sharing prompts when becoming friends with someone
  /// POST /friends/retroactive-share/accept
  Future<Map<String, dynamic>> acceptRetroactiveShare({
    required String userId,
    required String friendId,
    required List<String> contactFaceIds,
    required List<String> unknownFaceIds,
    required List<String> imageIds,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/friends/retroactive-share/accept');
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({
          'user_id': userId,
          'friend_id': friendId,
          'contact_face_ids': contactFaceIds,
          'unknown_face_ids': unknownFaceIds,
          'image_ids': imageIds,
        }),
      );
      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to accept retroactive share: ${e.toString()}');
    }
  }

  /// Mark a single notification read
  /// POST /notifications/{id}/mark-read
  Future<void> markNotificationReadSingle({
    required String notificationId,
    required String userId,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/notifications/$notificationId/mark-read');
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({'user_id': userId}),
      );
      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to mark notification as read: ${e.toString()}');
    }
  }
```

---

### Step 2: Refactor `ContactService` (`lib/services/contact_service.dart`)

We need to fix two issues here:
1. Rename the check method so `FriendsProvider` compiles.
2. Replace the call to the non-existent `/users/me/contacts` with the proper `/contacts/sync-status` API.
3. Optimize phone number payload construction. Rather than stripping country codes manually via regex (which can be fragile), send full numbers starting with `+` directly as the `raw_phone` with `country_code` empty; the backend’s Google `phonenumbers` engine handles strategy parsing.

Replace the file contents with:

```dart
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/contact_sync_result.dart';

class ContactService {
  final ApiClient _apiClient = ApiClient();

  /// Request contacts permission from the user
  Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.contacts.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      // User has permanently denied permission — direct to Settings
      await openAppSettings();
      return false;
    }

    return false;
  }

  /// Read all contacts from the phone (requires permission).
  Future<List<Contact>> getPhoneContacts() async {
    try {
      final hasPermission = await Permission.contacts.isGranted;
      if (!hasPermission) {
        debugPrint('Contacts permission not granted');
        return [];
      }
      return await FlutterContacts.getContacts(withProperties: true);
    } catch (e) {
      debugPrint('Error reading contacts: $e');
      return [];
    }
  }

  /// Convert a raw phone string to {display_name, raw_phone, country_code} maps.
  Iterable<Map<String, String>> _buildContactPayloads(Contact contact) {
    return contact.phones.map((phoneData) {
      final phone = phoneData.number.trim();
      String countryCode = '91'; // Default local region hint
      String rawPhone = phone;

      if (phone.startsWith('+')) {
        // E.164 already — send intact and empty the country code hint.
        // The backend's parser handles '+' prefixed numbers directly and perfectly.
        countryCode = '';
        rawPhone = phone;
      } else {
        // Strip non-digits for local numbers
        rawPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
        if (rawPhone.startsWith('0')) {
          rawPhone = rawPhone.substring(1);
        }
      }

      return {
        'display_name': contact.displayName,
        'raw_phone': rawPhone,
        'country_code': countryCode,
      };
    });
  }

  /// V2 Bulk sync: upload entire phonebook.
  Future<ContactSyncResult?> syncContactsToBackend(String userId) async {
    try {
      final contacts = await getPhoneContacts();

      if (contacts.isEmpty) {
        debugPrint('[ContactService] No contacts to sync');
        return ContactSyncResult(onPlatform: [], notOnPlatform: []);
      }

      final payload = contacts
          .where((c) => c.phones.isNotEmpty && c.displayName.isNotEmpty)
          .expand(_buildContactPayloads)
          .toList();

      debugPrint('[ContactService] Syncing ${payload.length} numbers via POST /contacts/sync');

      final result = await _apiClient.syncContacts(
        userId: userId,
        contacts: payload,
      );

      return result;
    } catch (e) {
      debugPrint('[ContactService] Error syncing contacts: $e');
      return null;
    }
  }

  /// Full sync flow: request permission → sync contacts → return result
  Future<ContactSyncResult?> requestPermissionAndSyncContacts(
    String userId, {
    String? accountCountryCode,
    String? accountPhone,
    String? accountDisplayName,
  }) async {
    final hasPermission = await requestContactsPermission();
    if (!hasPermission) {
      debugPrint('[ContactService] Contacts permission denied');
      return null;
    }
    return await syncContactsToBackend(userId);
  }

  /// Fetch cached recommendations from the backend (no re-read of phonebook)
  Future<ContactSyncResult?> getRecommendations(String userId) async {
    try {
      return await _apiClient.getContactRecommendations(userId: userId);
    } catch (e) {
      debugPrint('[ContactService] Error fetching recommendations: $e');
      return null;
    }
  }

  /// Check if user has contacts synced in backend.
  /// FIXED: Renamed to match the call in FriendsProvider (hasContactsStoredOnBackend)
  /// and uses the GET /contacts/sync-status endpoint to verify count.
  Future<bool> hasContactsStoredOnBackend(String userId) async {
    try {
      final status = await _apiClient.getContactSyncStatus(userId: userId);
      final count = status['contact_count'] as int? ?? 0;
      return count > 0;
    } catch (e) {
      debugPrint('Error checking backend contacts: $e');
      return false;
    }
  }

  /// Update the permission state on the backend
  Future<void> updateSyncStatus(String userId, String status) async {
    try {
      await _apiClient.updateContactSyncStatus(
        userId: userId,
        status: status,
      );
    } catch (e) {
      debugPrint('[ContactService] Error updating sync status: $e');
    }
  }
}
```

---

## 🚀 UX/UI Components Reference

Here is how the Flutter app should handle specific elements for contacts and social recommendations:

### 1. Face Bounding Box Cropping in Flutter (`CroppedFace`)
To display recurring unknown face suggestions, the backend returns a bounding box coordinate `bbox` with absolute pixel coordinates:
```json
"bbox": { "x1": 120, "y1": 80, "x2": 280, "y2": 240 }
```
To clip this face dynamically out of the full image without downloading a separate file, create a Custom Layout Delegate using the widget below:

```dart
class CroppedFace extends StatefulWidget {
  final String imageId;
  final Map<String, dynamic>? bbox;
  final double size;

  const CroppedFace({
    super.key,
    required this.imageId,
    this.bbox,
    this.size = 48.0,
  });

  @override
  State<CroppedFace> createState() => _CroppedFaceState();
}

class _CroppedFaceState extends State<CroppedFace> {
  int? _naturalWidth;
  int? _naturalHeight;
  bool _resolved = false;
  ImageStreamListener? _listener;
  ImageStream? _imageStream;

  @override
  void initState() {
    super.initState();
    _resolveImageDimensions();
  }

  @override
  void dispose() {
    if (_listener != null && _imageStream != null) {
      _imageStream!.removeListener(_listener!);
    }
    super.dispose();
  }

  void _resolveImageDimensions() {
    final url = '${ApiConstants.baseUrl}/images/${widget.imageId}';
    final image = NetworkImage(url); // Or CachedNetworkImageProvider
    _imageStream = image.resolve(const ImageConfiguration());
    _listener = ImageStreamListener((ImageInfo info, bool _) {
      if (mounted) {
        setState(() {
          _naturalWidth = info.image.width;
          _naturalHeight = info.image.height;
          _resolved = true;
        });
      }
    });
    _imageStream!.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final url = '${ApiConstants.baseUrl}/images/${widget.imageId}';

    if (widget.bbox == null || !_resolved || _naturalWidth == null || _naturalHeight == null) {
      return ClipOval(
        child: Image.network(url, width: widget.size, height: widget.size, fit: BoxFit.cover),
      );
    }

    final double x1 = (widget.bbox!['x1'] ?? 0).toDouble();
    final double y1 = (widget.bbox!['y1'] ?? 0).toDouble();
    final double x2 = (widget.bbox!['x2'] ?? 0).toDouble();
    final double y2 = (widget.bbox!['y2'] ?? 0).toDouble();

    final double boxWidth = x2 - x1;
    final double boxHeight = y2 - y1;

    return Container(
      width: widget.size,
      height: widget.size,
      child: ClipOval(
        child: CustomSingleChildLayout(
          delegate: _BBoxCroppingLayoutDelegate(
            naturalWidth: _naturalWidth!.toDouble(),
            naturalHeight: _naturalHeight!.toDouble(),
            x1: x1,
            y1: y1,
            boxWidth: boxWidth,
            boxHeight: boxHeight,
            targetSize: widget.size,
          ),
          child: Image.network(url, fit: BoxFit.fill),
        ),
      ),
    );
  }
}

class _BBoxCroppingLayoutDelegate extends SingleChildLayoutDelegate {
  final double naturalWidth, naturalHeight, x1, y1, boxWidth, boxHeight, targetSize;

  _BBoxCroppingLayoutDelegate({
    required this.naturalWidth,
    required this.naturalHeight,
    required this.x1,
    required this.y1,
    required this.boxWidth,
    required this.boxHeight,
    required this.targetSize,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final scaleX = targetSize / boxWidth;
    final scaleY = targetSize / boxHeight;
    return BoxConstraints.tightFor(
      width: naturalWidth * scaleX,
      height: naturalHeight * scaleY,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final scaleX = targetSize / boxWidth;
    final scaleY = targetSize / boxHeight;
    return Offset(-x1 * scaleX, -y1 * scaleY);
  }

  @override
  bool shouldRelayout(covariant _BBoxCroppingLayoutDelegate oldDelegate) {
    return oldDelegate.x1 != x1 || oldDelegate.y1 != y1 || oldDelegate.boxWidth != boxWidth || oldDelegate.boxHeight != boxHeight;
  }
}
```

### 2. Retroactive Sharing Notification Card
When two users become friends, the backend pushes a `retroactive_share_prompt` notification:
* **The Workflow:**
  1. Click **Prism Share** -> Calls `acceptRetroactiveShare(friendId, contactFaceIds, unknownFaceIds, imageIds)`.
  2. The backend performs the **Merge & Discard** biometric strategy, consolidating face embeddings and linking photos.
  3. On success, call `markNotificationReadSingle(notification.id)` to hide/dismiss the card from the activity feed.
  4. If the call fails with a `400 Bad Request` (indicating other uploads already claimed the biometric faces), display a friendly message: *"These memories were already shared or are no longer available."*
