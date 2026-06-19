import 'package:prism/models/sharing_models.dart';

class BatchReviewPartition {
  final List<BatchImage> allImages;
  final Map<String, List<BatchImage>> friendImages;
  final List<UnknownFace> unknowns;
  final List<BatchImage> assignImages;
  final List<BatchImage> noFaceImages;

  const BatchReviewPartition({
    required this.allImages,
    required this.friendImages,
    required this.unknowns,
    required this.assignImages,
    required this.noFaceImages,
  });

  static BatchReviewPartition fromBatch({
    required BatchStatusResponse batch,
    required String currentUserId,
    required Set<String> friendUserIds,
  }) {
    final images = batch.reviewIndex.images;
    if (images.isEmpty) {
      return const BatchReviewPartition(
        allImages: [],
        friendImages: {},
        unknowns: [],
        assignImages: [],
        noFaceImages: [],
      );
    }

    final selfIds = {currentUserId, if (batch.sharedBy != null) batch.sharedBy!};
    final index = batch.reviewIndex;

    final claimed = <String>{};
    final friendImages = <String, List<BatchImage>>{};

    for (final friendId in friendUserIds) {
      if (selfIds.contains(friendId)) continue;

      final matched =
          index.imagesForFriendIdExplicit(friendId, currentUserId);
      if (matched.isNotEmpty) {
        friendImages[friendId] = matched;
        claimed.addAll(matched.map((img) => img.id));
      }
    }

    final unknowns = List<UnknownFace>.from(batch.unknowns);

    final noFaceImages = images
        .where((image) {
          if (claimed.contains(image.id)) return false;
          return index.isNoFace(image.id);
        })
        .toList();
    claimed.addAll(noFaceImages.map((img) => img.id));

    final assignImages = images
        .where((image) {
          if (claimed.contains(image.id)) return false;
          if (index.isNoFace(image.id)) return false;
          return true;
        })
        .toList();

    final gridImageIds = <String>{
      ...friendImages.values.expand((list) => list.map((i) => i.id)),
      ...noFaceImages.map((i) => i.id),
      ...assignImages.map((i) => i.id),
    };
    final orphanImageIds = images
        .map((i) => i.id)
        .where((id) => !gridImageIds.contains(id))
        .toList();
    assert(
      orphanImageIds.isEmpty,
      'Every image must appear in exactly one grid bucket; orphans: $orphanImageIds',
    );

    return BatchReviewPartition(
      allImages: images,
      friendImages: friendImages,
      unknowns: unknowns,
      assignImages: assignImages,
      noFaceImages: noFaceImages,
    );
  }
}
