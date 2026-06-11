import 'package:prism/models/review_models.dart';
import 'package:prism/models/sharing_models.dart';
import 'package:prism/models/batch_review_partition.dart';

/// Section layout for the review screen. Each image appears in at most one bucket.
class ReviewLayout {
  final List<BatchImage> allImages;
  final List<ReviewPersonGroup> friendGroups;
  final ReviewPersonGroup? noFaceGroup;
  final ReviewPersonGroup? assignRecipientsGroup;

  const ReviewLayout({
    required this.allImages,
    required this.friendGroups,
    this.noFaceGroup,
    this.assignRecipientsGroup,
  });

  static const empty = ReviewLayout(allImages: [], friendGroups: []);

  static ReviewLayout fromBatch(
    BatchStatusResponse batch,
    String currentUserId, {
    required Set<String> friendUserIds,
  }) {
    final partition = BatchReviewPartition.fromBatch(
      batch: batch,
      currentUserId: currentUserId,
      friendUserIds: friendUserIds,
    );

    if (partition.allImages.isEmpty) return empty;

    final friendGroups = <ReviewPersonGroup>[];

    for (final entry in partition.friendImages.entries) {
      final friendId = entry.key;
      final images = entry.value;
      if (images.isEmpty) continue;

      DetectedRecipient? recipient;
      for (final r in batch.recipients) {
        if (r.userId == friendId) {
          recipient = r;
          break;
        }
      }

      friendGroups.add(
        ReviewPersonGroup(
          id: friendId,
          displayName: recipient?.username ?? 'Friend',
          profilePicId: recipient?.profilePicId,
          photoCount: images.length,
          images: images,
          type: ReviewGroupType.friend,
        ),
      );
    }

    friendGroups.sort((a, b) => b.photoCount.compareTo(a.photoCount));

    return ReviewLayout(
      allImages: partition.allImages,
      friendGroups: friendGroups,
      noFaceGroup: partition.noFaceImages.isEmpty
          ? null
          : ReviewPersonGroup(
              id: kReviewNoFaceGroupId,
              displayName: 'No faces detected',
              photoCount: partition.noFaceImages.length,
              images: partition.noFaceImages,
              type: ReviewGroupType.noFace,
            ),
      assignRecipientsGroup: partition.assignImages.isEmpty
          ? null
          : ReviewPersonGroup(
              id: kReviewAssignGroupId,
              displayName: 'Assign recipients',
              subtitle: 'Tap a photo to choose who receives it',
              photoCount: partition.assignImages.length,
              images: partition.assignImages,
              type: ReviewGroupType.assignRecipients,
            ),
    );
  }

  List<ReviewPersonGroup> get orderedSections {
    final sections = <ReviewPersonGroup>[];
    sections.addAll(friendGroups);
    if (assignRecipientsGroup != null) sections.add(assignRecipientsGroup!);
    if (noFaceGroup != null) sections.add(noFaceGroup!);
    return sections;
  }

  ReviewPersonGroup? get defaultExpandedGroup {
    if (friendGroups.isNotEmpty) return friendGroups.first;
    if (assignRecipientsGroup != null) return assignRecipientsGroup;
    if (noFaceGroup != null) return noFaceGroup;
    return null;
  }

  bool get hasPhotos => allImages.isNotEmpty;
}
