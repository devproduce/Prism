# 📱 Prism V2.2: Contacts Recommendations & Retroactive Sharing
**Mobile Integration Specification Guide**  
**Target Audience:** Flutter (Android/iOS) Frontend Developers  
**Reference Design System:** Glassmorphism Dark Theme (`PrismColors.voidBlack`, `PrismColors.prismYellow`, `PrismColors.surfaceGray`)

---

## 🗺️ Architectural Context

Prism V2.2 enhances the contact-discovery social flywheel. When contacts sync or batches are uploaded, the backend performs facial recognition to find matching registered users, unregistered contacts, and recurring unknown faces. 

This guide details the integration requirements for:
1. **Registered Suggestion Dismissal** (`POST /contacts/recommendations/dismiss`)
2. **Unknown Face Recommendations** (with native, dynamic face cropping using face `bbox`)
3. **Retroactive Sharing Cards** inside the Activity Log notification screen
4. **Granular Notification Read-State Management** (marking single notifications read via `POST /notifications/{id}/mark-read`)

---

## 1. API Changes Reference

### A. Fetch Recommendations (Updated Response Schema)
`GET` `/contacts/recommendations?user_id={user_id}`

The response payload has been extended to return a third list: `unknown_face_recommendations`.

#### **Response JSON Payload (`200 OK`)**
```json
{
  "on_platform": [
    {
      "user_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
      "username": "johndoe",
      "profile_pic_id": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
      "mutual_contact_count": 3
    }
  ],
  "not_on_platform": [
    {
      "display_name": "Jane Smith",
      "phone_number": "+919876543211",
      "whatsapp_link": "https://wa.me/919876543211?text=Join%20Prism...",
      "sms_link": "sms:+919876543211?body=Join%20Prism..."
    }
  ],
  "unknown_face_recommendations": [
    {
      "face_id": "f8c8d8b8-d8c8-4b4b-b8b8-d8c8d8b8d8c8",
      "representative_image_id": "c1a2b3c4-d5e6-7f8a-9b0c-1d2e3f4a5b6c",
      "bbox": {
        "x1": 120,
        "y1": 80,
        "x2": 280,
        "y2": 240
      },
      "appearance_count": 8,
      "whatsapp_link": "https://wa.me/?text=Hey!%20I%20found%208%20photos%20of%20you%20on%20Prism.%20Check%20them%20out...",
      "sms_link": "sms:?body=Hey!%20I%20found%208%20photos%20of%20you%20on%20Prism.%20Check%20them%20out..."
    }
  ]
}
```

> [!NOTE]
> `bbox` coordinates represent absolute pixel coordinates `(x1, y1, x2, y2)` corresponding to the face's position in the original image. If `bbox` is null, fall back to displaying the full representative image.

---

### B. Dismiss Registered Suggestion
`POST` `/contacts/recommendations/dismiss`

Call this endpoint when the user swipes away or clicks the dismiss button on a "People You May Know" recommendation card. This writes to the `dismissed_recommendations` table to permanently filter out this contact.

#### **Request Body**
```json
{
  "user_id": "UUID-OF-LOGGED-IN-USER",
  "dismissed_user_id": "UUID-OF-RECOMMENDED-USER"
}
```

#### **Response JSON Payload (`200 OK`)**
```json
{
  "status": "success",
  "message": "Recommendation dismissed"
}
```

---

### C. Accept Retroactive Memory Share
`POST` `/friends/retroactive-share/accept`

Call this endpoint to link historical, previously uploaded photo matches when two users become friends on the platform.

#### **Request Body**
```json
{
  "user_id": "UUID-OF-LOGGED-IN-USER",
  "friend_id": "UUID-OF-NEW-FRIEND",
  "contact_face_ids": ["face-id-1", "face-id-2"],
  "unknown_face_ids": ["unknown-face-id-1"],
  "image_ids": ["image-uuid-1", "image-uuid-2"]
}
```

#### **Response JSON Payload (`200 OK`)**
```json
{
  "message": "Retroactive memories shared successfully",
  "shared_count": 2
}
```

> [!IMPORTANT]
> **Biometric & Ownership Validation Rejection (`400 Bad Request`)**  
> If the backend detects that the provided `unknown_face_ids` do not biometrically match the target friend's face templates above the threshold, or if the faces have already been claimed/assigned (`user_id IS NOT NULL`), the backend will filter them out. If no valid faces/images survive this verification, the request is rejected with `400 Bad Request` and detail `"No valid pending memories/faces found to share after validation and biometric filtering"`. The mobile application must handle this error code gracefully.

---

### D. Mark Single Notification as Read
`POST` `/notifications/{notification_id}/mark-read`

Marks an individual notification log entry as read without altering other notifications in the user's history list.

#### **Request Body**
```json
{
  "user_id": "UUID-OF-LOGGED-IN-USER"
}
```

#### **Response JSON Payload (`200 OK`)**
```json
{
  "status": "success",
  "message": "Notification marked as read"
}
```

---

## 2. Dynamic Bounding Box Face Cropping in Flutter

To display unknown face recommendations cleanly, the mobile application must crop the face thumbnail out of the full image using the absolute `bbox` coordinates. 

Since the original image may be loaded in a scaled down container, using `CustomSingleChildLayout` is the most efficient approach. It resolves the image's natural dimensions, computes scaling ratios, and offsets the child widget to clip the face.

### Flutter `CroppedFace` Widget Implementation

Create this widget in `lib/widgets/cropped_face.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/utils/constants.dart';

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
  void didUpdateWidget(CroppedFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageId != widget.imageId) {
      _cleanupListener();
      _resolved = false;
      _resolveImageDimensions();
    }
  }

  @override
  void dispose() {
    _cleanupListener();
    super.dispose();
  }

  void _cleanupListener() {
    if (_listener != null && _imageStream != null) {
      _imageStream!.removeListener(_listener!);
    }
  }

  void _resolveImageDimensions() {
    final url = '${ApiConstants.baseUrl}/images/${widget.imageId}';
    final image = CachedNetworkImageProvider(url);
    
    _imageStream = image.resolve(const ImageConfiguration());
    _listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _naturalWidth = info.image.width;
            _naturalHeight = info.image.height;
            _resolved = true;
          });
        }
      },
      onError: (exception, stackTrace) {
        debugPrint('[CroppedFace] Error resolving image size: $exception');
      },
    );
    _imageStream!.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final url = '${ApiConstants.baseUrl}/images/${widget.imageId}';

    // Fallback if no bbox is provided or image dimensions are not resolved
    if (widget.bbox == null || !_resolved || _naturalWidth == null || _naturalHeight == null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            errorWidget: (context, _, __) => const Icon(
              Icons.person_rounded, 
              color: Colors.white60,
              size: 20,
            ),
          ),
        ),
      );
    }

    final bbox = widget.bbox!;
    final double x1 = (bbox['x1'] ?? 0).toDouble();
    final double y1 = (bbox['y1'] ?? 0).toDouble();
    final double x2 = (bbox['x2'] ?? 0).toDouble();
    final double y2 = (bbox['y2'] ?? 0).toDouble();

    final double boxWidth = x2 - x1;
    final double boxHeight = y2 - y1;

    // Safety fallback for degenerate/zero-size boxes
    if (boxWidth <= 0 || boxHeight <= 0) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
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
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }
}

class _BBoxCroppingLayoutDelegate extends SingleChildLayoutDelegate {
  final double naturalWidth;
  final double naturalHeight;
  final double x1;
  final double y1;
  final double boxWidth;
  final double boxHeight;
  final double targetSize;

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
    return oldDelegate.naturalWidth != naturalWidth ||
        oldDelegate.naturalHeight != naturalHeight ||
        oldDelegate.x1 != x1 ||
        oldDelegate.y1 != y1 ||
        oldDelegate.boxWidth != boxWidth ||
        oldDelegate.boxHeight != boxHeight ||
        oldDelegate.targetSize != targetSize;
  }
}
```

---

## 3. Unknown Face Recommendations Integration

Display the list of unknown faces under the **INVITE TO PRISM** contact section in the **Friends Screen**.

### UI Integration Requirements
1. **Container Styling**: Dark container matching `PrismColors.surfaceGray`.
2. **Display Elements**:
   - Left side: Cropped face thumbnail using the `<CroppedFace>` widget.
   - Middle: Label showing `"Unknown contact (${item.appearanceCount} photos)"`.
   - Right side: Standard circular icon buttons to trigger **WhatsApp Share** or **SMS Invite**.
3. **Invite Link Triggering**: Use `url_launcher` to deep link into target chat clients.

```dart
// Example widget implementation for Unknown Face Recommendation Card
class UnknownFaceRecommendationCard extends StatelessWidget {
  final String faceId;
  final String representativeImageId;
  final Map<String, dynamic>? bbox;
  final int appearanceCount;
  final String whatsappLink;
  final String smsLink;

  const UnknownFaceRecommendationCard({
    super.key,
    required this.faceId,
    required this.representativeImageId,
    this.bbox,
    required this.appearanceCount,
    required this.whatsappLink,
    required this.smsLink,
  });

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CroppedFace(
            imageId: representativeImageId,
            bbox: bbox,
            size: 44.0,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unknown Match',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Found in $appearanceCount photos',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.message_rounded, color: Colors.green),
            onPressed: () => _launchUrl(whatsappLink),
          ),
          IconButton(
            icon: const Icon(Icons.sms_rounded, color: Colors.blue),
            onPressed: () => _launchUrl(smsLink),
          ),
        ],
      ),
    );
  }
}
```

---

## 4. Notification Screen Upgrade

Three notification schemas must be integrated into `lib/screens/notification_screen.dart` and `lib/widgets/notification_card.dart`.

### A. New Notification Type: `contact_found_in_batch`
*   **Context**: A registered user in the uploader's contacts list has been identified in a recently analyzed photo batch.
*   **Behavior**: High-Priority Friend Request card style.
*   **Actions**:
    *   **Add Friend**: Calls `POST /friends/request` with body `{"user_id": currentUserId, "username": targetUsername}`.
    *   **Dismiss**: Calls `POST /notifications/{notification_id}/mark-read`.

### B. New Notification Type: `retroactive_share_prompt`
*   **Context**: The logged-in user just became friends with a user who previously uploaded photos containing them.
*   **Aesthetic Guidelines**: 
    - Full width card layout matching the Next.js `RetroactiveSharePrompt` component.
    - Gold accent borders (`PrismColors.prismYellow`).
    - Multi-image grid displaying thumbnails of the first 3 matching photos.
    - If there are more than 3 matches, display a `+N more` text overlay on the 3rd thumbnail.
*   **Actions**:
    *   **Prism Share**: Calls `POST /friends/retroactive-share/accept` using all metadata IDs, then immediately fires `POST /notifications/{notification_id}/mark-read` to clean up the card.
    *   **Skip**: Only calls `POST /notifications/{notification_id}/mark-read`.
*   **Lifecycle & Feed Filtering**: Once a retroactive share prompt is read/acted on (`is_read` becomes `true`), it must be immediately filtered out and removed from the notifications log list view to prevent re-activation or re-submission errors.

#### **Retroactive Card Widget Flow (Dart)**
```dart
class RetroactiveShareCard extends StatelessWidget {
  final NotificationModel notification;
  final String currentUserId;
  final VoidCallback onDismiss;

  const RetroactiveShareCard({
    super.key,
    required this.notification,
    required this.currentUserId,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = notification.metadata ?? {};
    final List<dynamic> imageIds = metadata['image_ids'] ?? [];
    final List<dynamic> contactFaceIds = metadata['contact_face_ids'] ?? [];
    final List<dynamic> unknownFaceIds = metadata['unknown_face_ids'] ?? [];
    final String friendId = metadata['friend_id'] ?? '';
    final String friendUsername = notification.username ?? 'your friend';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(
          left: BorderSide(color: PrismColors.prismYellow, width: 3),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: PrismColors.prismYellow, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You & $friendUsername are friends!',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'We found ${imageIds.length} shared memories with them.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          
          // Image Grid
          if (imageIds.isNotEmpty)
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: imageIds.length > 3 ? 3 : imageIds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final imageId = imageIds[index];
                  final isLast = index == 2 && imageIds.length > 3;

                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: '${ApiConstants.baseUrl}/images/$imageId',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (isLast)
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+${imageIds.length - 3} more',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded, size: 14, color: Colors.black),
                label: const Text('Prism Share', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PrismColors.prismYellow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () async {
                  // Link retroactive match
                  await Provider.of<NotificationsProvider>(context, listen: false)
                      .acceptRetroactiveShare(
                    friendId: friendId,
                    contactFaceIds: List<String>.from(contactFaceIds),
                    unknownFaceIds: List<String>.from(unknownFaceIds),
                    imageIds: List<String>.from(imageIds),
                  );
                  // Dismiss/read notification
                  await Provider.of<NotificationsProvider>(context, listen: false)
                      .markAsReadSingle(notification.id);
                  onDismiss();
                },
              ),
              const SizedBox(width: 12),
              TextButton(
                child: const Text('Skip', style: TextStyle(color: Colors.white54)),
                onPressed: () async {
                  await Provider.of<NotificationsProvider>(context, listen: false)
                      .markAsReadSingle(notification.id);
                  onDismiss();
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}
```

---

## 5. Dart Integration Steps Checklist

1. **Update Models**:
   Ensure `NotificationModel`'s `fromJson` parser correctly parses the nested `metadata` maps for `friend_id`, `contact_face_ids`, `unknown_face_ids`, and `image_ids`.
2. **Implement API Client Calls**:
   Add new endpoints in `lib/api/api_client.dart`:
   - `Future<void> dismissRecommendation({required String userId, required String dismissedUserId})`
   - `Future<void> acceptRetroactiveShare({required String userId, required String friendId, required List<String> contactFaceIds, required List<String> unknownFaceIds, required List<String> imageIds})`
   - `Future<void> markNotificationReadSingle({required String notificationId, required String userId})`
3. **Update State Providers**:
   - `NotificationsProvider`: Add a `markAsReadSingle(String id)` method calling `/notifications/{id}/mark-read`. Add `acceptRetroactiveShare(...)`.
   - `FriendsProvider`: Add `dismissRecommendation(String recommendedUserId)` which calls the dismiss endpoint and removes the card locally from the state list.
4. **Update UI Widgets**:
   - Render the `RetroactiveShareCard` inside `NotificationCard`'s type router if type is `retroactive_share_prompt`.
   - Implement the `UnknownFaceRecommendationCard` inside `FriendsScreen`'s discover sliver.
5. **Handle OS Permission Intent Routing**:
   Ensure WhatsApp and SMS deep-links safely delegate requests using `url_launcher` without blocking page interactions.

---
**Status:** Feature Set Specifications Confirmed.  
**Platform Versioning**: Prism-Backend V2.2.0-Alpha.  
