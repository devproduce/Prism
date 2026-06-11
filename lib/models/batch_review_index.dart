
import 'package:flutter/foundation.dart';
import 'package:prism/models/sharing_models.dart';

/// Unified per-image face assignments and no-face classification for the review screen.
class BatchReviewIndex {
  final List<BatchImage> images;
  final Map<String, Set<String>> imageToUserIds;
  /// Face-linked assignments only (never greedy count reconciliation).
  final Map<String, Set<String>> explicitImageToUserIds;
  final Set<String> noFaceImageIds;
  final Set<String> unknownFaceImageIds;

  const BatchReviewIndex({
    required this.images,
    required this.imageToUserIds,
    Map<String, Set<String>>? explicitImageToUserIds,
    required this.noFaceImageIds,
    this.unknownFaceImageIds = const {},
  }) : explicitImageToUserIds = explicitImageToUserIds ?? imageToUserIds;

  List<BatchImage> get noFaceImages =>
      images.where((img) => noFaceImageIds.contains(img.id)).toList();

  List<BatchImage> imagesForUserId(String userId) => images
      .where((img) => imageToUserIds[img.id]?.contains(userId) ?? false)
      .toList();

  Set<String> friendUserIdsForImage(String imageId, String currentUserId) {
    return imageToUserIds[imageId]
            ?.where((id) => id != currentUserId)
            .toSet() ??
        {};
  }

  List<BatchImage> imagesForFriendId(String friendUserId, String currentUserId) {
    return imagesForFriendIdExplicit(friendUserId, currentUserId);
  }

  /// Photos explicitly linked to [friendUserId] via CV / API maps (no reconcile).
  List<BatchImage> imagesForFriendIdExplicit(
    String friendUserId,
    String currentUserId,
  ) {
    if (friendUserId == currentUserId) return const [];

    return images
        .where((img) {
          if (unknownFaceImageIds.contains(img.id)) return false;
          return explicitImageToUserIds[img.id]?.contains(friendUserId) ?? false;
        })
        .toList();
  }

  Set<String> explicitFriendUserIdsForImage(
    String imageId,
    String currentUserId,
  ) {
    if (unknownFaceImageIds.contains(imageId)) return const {};
    return explicitImageToUserIds[imageId]
            ?.where((id) => id != currentUserId)
            .toSet() ??
        {};
  }

  bool isNoFace(String imageId) => noFaceImageIds.contains(imageId);

  /// True when CV found any face in this image (including self-only matches).
  bool hasFaceDetection(String imageId) {
    final image = images.where((img) => img.id == imageId).firstOrNull;
    if (image == null) return false;
    return _hasFaceDetection(image, imageToUserIds, unknownFaceImageIds);
  }

  static BatchReviewIndex build({
    required Map<String, dynamic> rawJson,
    required List<BatchImage> images,
    Map<String, dynamic>? result,
    List<UnknownFace> unknowns = const [],
    List<DetectedRecipient> recipients = const [],
  }) {
    final enriched = _enrichImages(images, result, rawJson);
    final imageToUserIds = <String, Set<String>>{};

    void assign(String imageId, String userId) {
      if (imageId.isEmpty || userId.isEmpty) return;
      imageToUserIds.putIfAbsent(imageId, () => {}).add(userId);
    }

    // Web parity: only per-image detected_faces user_id (no recipient lists / reconcile).
    for (final image in enriched) {
      for (final face in image.detectedFaces ?? const <dynamic>[]) {
        final userId = BatchFaceParser.userId(face);
        if (userId != null) assign(image.id, userId);
      }
    }

    final unknownFaceImageIds = _imageIdsWithUnknownFaces(enriched, unknowns);

    for (final imageId in unknownFaceImageIds) {
      imageToUserIds.remove(imageId);
    }

    final explicitImageToUserIds = {
      for (final entry in imageToUserIds.entries)
        entry.key: Set<String>.from(entry.value),
    };

    final noFaceImageIds = <String>{};

    for (final image in enriched) {
      if (_hasFaceDetection(image, imageToUserIds, unknownFaceImageIds)) {
        continue;
      }
      if (image.detectedFaces == null && image.faceIds == null) {
        noFaceImageIds.add(image.id);
      }
    }

    debugPrint('[BatchReviewIndex] Built review index:');
    debugPrint('   Images: ${enriched.length}');
    debugPrint('   Assigned images: ${imageToUserIds.length}');
    debugPrint('   No-face images: ${noFaceImageIds.length}');
    debugPrint('   Unknown-face images: ${unknownFaceImageIds.length}');
    for (final recipient in recipients) {
      final count = imageToUserIds.entries
          .where((entry) => entry.value.contains(recipient.userId))
          .length;
      debugPrint(
        '   ${recipient.username}: api=${recipient.count} mapped=$count',
      );
    }

    return BatchReviewIndex(
      images: enriched,
      imageToUserIds: imageToUserIds,
      explicitImageToUserIds: explicitImageToUserIds,
      noFaceImageIds: noFaceImageIds,
      unknownFaceImageIds: unknownFaceImageIds,
    );
  }

  /// Any face signal: assignments (incl. self), unknowns, face_ids, or face records.
  static bool _hasFaceDetection(
    BatchImage image,
    Map<String, Set<String>> imageToUserIds,
    Set<String> unknownFaceImageIds,
  ) {
    if (unknownFaceImageIds.contains(image.id)) return true;

    final assigned = imageToUserIds[image.id];
    if (assigned != null && assigned.isNotEmpty) return true;

    if (image.hasFaceSignals) return true;

    for (final face in image.detectedFaces ?? const <dynamic>[]) {
      if (face is Map && face.isNotEmpty) return true;
      if (BatchFaceParser.faceId(face) != null) return true;
      if (BatchFaceParser.userId(face) != null) return true;
    }

    return false;
  }

  static List<BatchImage> _enrichImages(
    List<BatchImage> images,
    Map<String, dynamic>? result,
    Map<String, dynamic> rawJson,
  ) {
    final byId = <String, BatchImage>{for (final image in images) image.id: image};

    void mergeFromRaw(dynamic raw) {
      if (raw is! List) return;
      for (final item in raw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final parsed = BatchImage.fromJson(map);
        final id = parsed.id;
        if (id.isEmpty) continue;

        final existing = byId[id];
        byId[id] = existing == null ? parsed : existing.mergeWith(parsed);
      }
    }

    mergeFromRaw(result?['images']);
    mergeFromRaw(rawJson['images']);

    final orderedIds = images.map((image) => image.id).toList();
    final ordered = <BatchImage>[];
    final seen = <String>{};

    for (final id in orderedIds) {
      final image = byId[id];
      if (image != null && seen.add(id)) {
        ordered.add(image);
      }
    }

    for (final entry in byId.entries) {
      if (seen.add(entry.key)) {
        ordered.add(entry.value);
      }
    }

    return ordered;
  }

  static Set<String> _imageIdsWithUnknownFaces(
    List<BatchImage> images,
    List<UnknownFace> unknowns,
  ) {
    final ids = <String>{};
    for (final unknown in unknowns) {
      final rep = unknown.representativeImageId;
      if (rep != null && rep.isNotEmpty) {
        ids.add(rep);
      }
    }
    return ids;
  }
}
