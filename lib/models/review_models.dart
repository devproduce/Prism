import 'package:prism/models/sharing_models.dart';

/// Sentinel id for the no-face accordion group on the review screen.
const String kReviewNoFaceGroupId = '__no_face__';

/// Sentinel id for photos that need manual recipient assignment.
const String kReviewAssignGroupId = '__assign__';

enum ReviewGroupType { friend, noFace, assignRecipients }

/// One expandable block on the review screen.
class ReviewPersonGroup {
  final String id;
  final String displayName;
  final String? subtitle;
  final String? profilePicId;
  final int photoCount;
  final List<BatchImage> images;
  final ReviewGroupType type;

  const ReviewPersonGroup({
    required this.id,
    required this.displayName,
    this.subtitle,
    this.profilePicId,
    required this.photoCount,
    required this.images,
    required this.type,
  });

  bool get isNoFace => type == ReviewGroupType.noFace;

  bool get isAssignRecipients => type == ReviewGroupType.assignRecipients;

  String get photoCountLabel {
    final n = photoCount;
    return '$n ${n == 1 ? 'PHOTO' : 'PHOTOS'}';
  }
}

/// A contact detected in the batch who is on Prism but not yet a friend.
class ReviewSuggestion {
  final String userId;
  final String username;
  final String? profilePicId;
  final String? contactName;
  final int photoCount;

  const ReviewSuggestion({
    required this.userId,
    required this.username,
    this.profilePicId,
    this.contactName,
    required this.photoCount,
  });

  String get displayName {
    final name = contactName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return username;
  }
}
