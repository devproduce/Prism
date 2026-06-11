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
    final unknownRepImageIds = {
      for (final unknown in batch.unknowns)
        if (unknown.representativeImageId != null &&
            unknown.representativeImageId!.isNotEmpty)
          unknown.representativeImageId!,
    };

    final claimed = <String>{};
    final friendImages = <String, List<BatchImage>>{};

    for (final friendId in friendUserIds) {
      if (selfIds.contains(friendId)) continue;

      final matched = <BatchImage>[];
      for (final image in images) {
        if (unknownRepImageIds.contains(image.id)) continue;
        if (!_imageHasUserId(image, friendId)) continue;
        matched.add(image);
        claimed.add(image.id);
      }

      if (matched.isNotEmpty) {
        friendImages[friendId] = matched;
      }
    }

    final unknowns = <UnknownFace>[];
    for (final unknown in batch.unknowns) {
      final rep = unknown.representativeImageId;
      if (rep != null && rep.isNotEmpty) {
        claimed.add(rep);
      }
      unknowns.add(unknown);
    }

    final noFaceImages = images
        .where((image) {
          if (claimed.contains(image.id)) return false;
          return batch.reviewIndex.isNoFace(image.id);
        })
        .toList();
    claimed.addAll(noFaceImages.map((img) => img.id));

    final assignImages = images
        .where((image) {
          if (claimed.contains(image.id)) return false;
          if (unknownRepImageIds.contains(image.id)) return false;
          if (batch.reviewIndex.isNoFace(image.id)) return false;
          return true;
        })
        .toList();

    return BatchReviewPartition(
      allImages: images,
      friendImages: friendImages,
      unknowns: unknowns,
      assignImages: assignImages,
      noFaceImages: noFaceImages,
    );
  }

  static bool _imageHasUserId(BatchImage image, String userId) {
    for (final face in image.detectedFaces ?? const <dynamic>[]) {
      if (BatchFaceParser.userId(face) == userId) return true;
    }
    return false;
  }
}
