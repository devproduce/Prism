import 'package:prism/utils/constants.dart';

/// Result from POST /contacts/sync or GET /contacts/recommendations
class ContactSyncResult {
  final List<OnPlatformUser> onPlatform;
  final List<NotOnPlatformContact> notOnPlatform;
  final List<UnknownFaceRecommendation> unknownFaceRecommendations;

  ContactSyncResult({
    required this.onPlatform,
    required this.notOnPlatform,
    this.unknownFaceRecommendations = const [],
  });

  factory ContactSyncResult.fromJson(Map<String, dynamic> json) {
    final onPlatformJson = json['on_platform'] as List<dynamic>? ?? [];
    final notOnPlatformJson = json['not_on_platform'] as List<dynamic>? ?? [];
    final unknownFacesJson =
        json['unknown_face_recommendations'] as List<dynamic>? ?? [];

    return ContactSyncResult(
      onPlatform: onPlatformJson
          .map((e) => OnPlatformUser.fromJson(e as Map<String, dynamic>))
          .toList(),
      notOnPlatform: notOnPlatformJson
          .map((e) => NotOnPlatformContact.fromJson(e as Map<String, dynamic>))
          .toList(),
      unknownFaceRecommendations: unknownFacesJson
          .map(
            (e) => UnknownFaceRecommendation.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  bool get isEmpty =>
      onPlatform.isEmpty &&
      notOnPlatform.isEmpty &&
      unknownFaceRecommendations.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

/// A Prism user found via phonebook matching
class OnPlatformUser {
  final String userId;
  final String username;
  final String? profilePicId;
  final int mutualContactCount;
  final String? contactName;

  OnPlatformUser({
    required this.userId,
    required this.username,
    this.profilePicId,
    required this.mutualContactCount,
    this.contactName,
  });

  factory OnPlatformUser.fromJson(Map<String, dynamic> json) {
    return OnPlatformUser(
      userId: json['user_id'] ?? json['id'] ?? '',
      username: json['username'] ?? '',
      profilePicId: json['profile_pic_id'] as String?,
      mutualContactCount: (json['mutual_contact_count'] as num?)?.toInt() ?? 0,
      contactName: json['contact_name'] as String?,
    );
  }

  /// Profile picture URL constructed from base URL
  String get profilePictureUrl {
    if (profilePicId != null && profilePicId!.isNotEmpty) {
      return '${ApiConstants.baseUrl}/images/$profilePicId';
    }
    return '';
  }
}

/// A phone contact who is NOT on Prism yet — invite target
class NotOnPlatformContact {
  final String displayName;
  final String whatsappLink;
  final String smsLink;

  NotOnPlatformContact({
    required this.displayName,
    required this.whatsappLink,
    required this.smsLink,
  });

  factory NotOnPlatformContact.fromJson(Map<String, dynamic> json) {
    return NotOnPlatformContact(
      displayName: json['display_name'] ?? json['name'] ?? 'Unknown',
      whatsappLink: json['whatsapp_link'] ?? '',
      smsLink: json['sms_link'] ?? '',
    );
  }
}

/// Recurring unknown face cluster from uploaded photos (V2.2)
class UnknownFaceRecommendation {
  final String faceId;
  final String representativeImageId;
  final Map<String, dynamic>? bbox;
  final int appearanceCount;
  final String whatsappLink;
  final String smsLink;

  UnknownFaceRecommendation({
    required this.faceId,
    required this.representativeImageId,
    this.bbox,
    required this.appearanceCount,
    required this.whatsappLink,
    required this.smsLink,
  });

  factory UnknownFaceRecommendation.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? bbox;
    final bboxRaw = json['bbox'];
    if (bboxRaw is Map) {
      bbox = Map<String, dynamic>.from(bboxRaw);
    }

    return UnknownFaceRecommendation(
      faceId: json['face_id']?.toString() ?? '',
      representativeImageId: json['representative_image_id']?.toString() ?? '',
      bbox: bbox,
      appearanceCount: (json['appearance_count'] as num?)?.toInt() ?? 0,
      whatsappLink: json['whatsapp_link']?.toString() ?? '',
      smsLink: json['sms_link']?.toString() ?? '',
    );
  }
}
