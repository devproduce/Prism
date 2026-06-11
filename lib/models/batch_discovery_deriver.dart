import 'package:flutter/foundation.dart';
import 'package:prism/models/contact_sync_result.dart';
import 'package:prism/models/sharing_models.dart';

/// Builds Found Contacts + Invite-to-Prism lists when the batch API returns
/// empty top-level arrays but face metadata lives on each image detected_faces.
class BatchDiscoveryDeriver {
  BatchDiscoveryDeriver._();

  static ({List<DetectedContact> contacts, List<UnknownFace> unknowns}) derive({
    required List<BatchImage> images,
    required String currentUserId,
    required Set<String> friendUserIds,
    required List<OnPlatformUser> onPlatformUsers,
    List<DetectedContact> existingContacts = const [],
    List<UnknownFace> existingUnknowns = const [],
  }) {
    final onPlatformById = {
      for (final user in onPlatformUsers) user.userId: user,
    };

    final contactsById = {
      for (final contact in existingContacts) contact.userId: contact,
    };
    final unknownsByFaceId = {
      for (final unknown in existingUnknowns) unknown.faceId: unknown,
    };

    final unknownCounts = <String, int>{};
    final unknownImageIds = <String, String>{};
    final unknownBboxes = <String, Map<String, dynamic>>{};

    for (final image in images) {
      final seenInImage = <String>{};

      for (final face in image.detectedFaces ?? const <dynamic>[]) {
        if (face is! Map) continue;
        final map = Map<String, dynamic>.from(face);
        final userId = BatchFaceParser.userId(face);
        final faceId = BatchFaceParser.faceId(face);

        if (userId != null &&
            userId.isNotEmpty &&
            userId != currentUserId &&
            !friendUserIds.contains(userId)) {
          final platformUser = onPlatformById[userId];
          final username = platformUser?.username ??
              BatchFaceParser.username(face) ??
              BatchFaceParser.displayName(face);

          if (platformUser != null || username != null) {
            contactsById[userId] = DetectedContact(
              userId: userId,
              username: username ?? 'Contact',
              profilePicId: platformUser?.profilePicId ??
                  BatchFaceParser.profilePicId(face),
            );
            seenInImage.add('contact:');
            continue;
          }
        }

        if (!_isUnknownFace(map, userId)) continue;
        if (faceId == null || faceId.isEmpty) continue;

        unknownsByFaceId.putIfAbsent(
          faceId,
          () => UnknownFace(
            faceId: faceId,
            representativeImageId:
                BatchFaceParser.representativeImageId(face) ?? image.id,
            bbox: BatchFaceParser.bbox(face),
            count: 1,
            whatsappLink: map['whatsapp_link']?.toString() ?? '',
            smsLink: map['sms_link']?.toString() ?? '',
          ),
        );

        if (seenInImage.add('unknown:')) {
          unknownCounts[faceId] = (unknownCounts[faceId] ?? 0) + 1;
        }
        unknownImageIds.putIfAbsent(faceId, () => image.id);
        final bbox = BatchFaceParser.bbox(face);
        if (bbox != null) {
          unknownBboxes[faceId] = bbox;
        }
      }
    }

    final unknowns = unknownsByFaceId.entries.map((entry) {
      final base = entry.value;
      return UnknownFace(
        faceId: base.faceId,
        representativeImageId:
            unknownImageIds[entry.key] ?? base.representativeImageId,
        bbox: unknownBboxes[entry.key] ?? base.bbox,
        count: unknownCounts[entry.key] ?? base.count,
        whatsappLink: base.whatsappLink,
        smsLink: base.smsLink,
      );
    }).toList();

    debugPrint(
      '[BatchDiscoveryDeriver] Derived  contacts, '
      ' unknowns from  image(s)',
    );

    return (
      contacts: contactsById.values.toList(),
      unknowns: unknowns,
    );
  }

  static List<UnknownFace> appendUnclassifiedImageUnknowns({
    required List<BatchImage> images,
    required String currentUserId,
    required Set<String> friendUserIds,
    required Set<String> excludeImageIds,
    required List<UnknownFace> existingUnknowns,
  }) {
    final byFaceId = {for (final u in existingUnknowns) u.faceId: u};
    final defaultWa = existingUnknowns.isNotEmpty
        ? existingUnknowns.first.whatsappLink
        : '';
    final defaultSms =
        existingUnknowns.isNotEmpty ? existingUnknowns.first.smsLink : '';

    for (final image in images) {
      if (excludeImageIds.contains(image.id)) continue;
      if (isSelfOnlyImage(image, currentUserId, friendUserIds)) continue;

      final hasUnmappedSignal = image.isExplicitlyNoFace ||
          image.detectedFaces != null ||
          image.faceIds != null;
      if (!hasUnmappedSignal) continue;

      if (existingUnknowns.any((u) => u.representativeImageId == image.id)) {
        continue;
      }

      final pseudoId = 'unclassified-';
      if (byFaceId.containsKey(pseudoId)) continue;

      byFaceId[pseudoId] = UnknownFace(
        faceId: pseudoId,
        representativeImageId: image.id,
        count: 1,
        whatsappLink: defaultWa,
        smsLink: defaultSms,
      );
    }

    final added = byFaceId.length - existingUnknowns.length;
    if (added > 0) {
      debugPrint(
        '[BatchDiscoveryDeriver] Added  unclassified image unknown(s)',
      );
    }

    return byFaceId.values.toList();
  }

  static bool _isUnknownFace(Map<String, dynamic> map, String? userId) {
    if (userId != null && userId.isNotEmpty) return false;

    if (map['is_unknown'] == true) return true;
    if (map['match_type']?.toString() == 'unknown') return true;
    if (map['category']?.toString() == 'unknown') return true;
    if (map['on_platform'] == false) return true;
    if (map['is_on_platform'] == false) return true;

    final faceId = BatchFaceParser.faceId(map);
    return faceId != null && faceId.isNotEmpty;
  }

  static bool isSelfOnlyImage(
    BatchImage image,
    String currentUserId,
    Set<String> friendUserIds,
  ) {
    final recognized = image.recognizedUserIds;
    if (recognized.isEmpty) return false;
    if (recognized.any(friendUserIds.contains)) return false;
    return recognized.contains(currentUserId);
  }
}
