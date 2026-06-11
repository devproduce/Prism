// Models for sharing functionality

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:prism/models/batch_discovery_deriver.dart';
import 'package:prism/models/batch_review_index.dart';
import 'package:prism/models/contact_sync_result.dart';
import 'package:prism/utils/constants.dart';

class BatchUploadResponse {
  final String batchId;
  final String status;

  BatchUploadResponse({required this.batchId, required this.status});

  factory BatchUploadResponse.fromJson(Map<String, dynamic> json) {
    return BatchUploadResponse(
      batchId: json['batch_id'] as String,
      status: json['status'] as String,
    );
  }
}

class DetectedRecipient {
  final String userId;
  final String username;
  final String? profilePicId;
  final int count;
  bool isSelected;

  DetectedRecipient({
    required this.userId,
    required this.username,
    this.profilePicId,
    required this.count,
    this.isSelected = true,
  });

  String get profilePictureUrl {
    if (profilePicId == null) return '';
    return '${ApiConstants.baseUrl}/images/$profilePicId';
  }

  factory DetectedRecipient.fromJson(Map<String, dynamic> json) {
    return DetectedRecipient(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      profilePicId: json['profile_pic_id'] as String?,
      count: (json['count'] as num?)?.toInt() ?? 0,
      isSelected: true,
    );
  }
}

class DetectedContact {
  final String userId;
  final String username;
  final String? profilePicId;

  DetectedContact({
    required this.userId,
    required this.username,
    this.profilePicId,
  });

  String get profilePictureUrl {
    if (profilePicId == null) return '';
    return '${ApiConstants.baseUrl}/images/$profilePicId';
  }

  factory DetectedContact.fromJson(Map<String, dynamic> json) {
    return DetectedContact(
      userId: (json['user_id'] ?? json['id']).toString(),
      username: (json['username'] ?? json['contact_name'] ?? 'Contact')
          .toString(),
      profilePicId: json['profile_pic_id'] as String?,
    );
  }
}

class UnknownFace {
  final String faceId;
  final String? imageUrl;
  final String? representativeImageId;
  final Map<String, dynamic>? bbox;
  final int count;
  final String whatsappLink;
  final String smsLink;

  UnknownFace({
    required this.faceId,
    this.imageUrl,
    this.representativeImageId,
    this.bbox,
    this.count = 1,
    this.whatsappLink = '',
    this.smsLink = '',
  });

  factory UnknownFace.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? bbox;
    final bboxRaw = json['bbox'];
    if (bboxRaw is Map) {
      bbox = Map<String, dynamic>.from(bboxRaw);
    }

    return UnknownFace(
      faceId: json['face_id']?.toString() ?? '',
      imageUrl: BatchImage._ensureAbsoluteUrl(
        json['image_url'] ?? json['url'],
      ),
      representativeImageId: json['representative_image_id']?.toString(),
      bbox: bbox,
      count: (json['count'] as num?)?.toInt() ??
          (json['appearance_count'] as num?)?.toInt() ??
          1,
      whatsappLink: json['whatsapp_link']?.toString() ?? '',
      smsLink: json['sms_link']?.toString() ?? '',
    );
  }

  UnknownFaceRecommendation toRecommendation() {
    return UnknownFaceRecommendation(
      faceId: faceId,
      representativeImageId: representativeImageId ?? _representativeImageIdFromUrl(),
      bbox: bbox,
      appearanceCount: count,
      whatsappLink: whatsappLink,
      smsLink: smsLink,
    );
  }

  String _representativeImageIdFromUrl() {
    final url = imageUrl;
    if (url == null || url.isEmpty) return '';
    final segments = url.split('/');
    final last = segments.isNotEmpty ? segments.last : '';
    return last.split('?').first;
  }
}

class BatchStatusResponse {
  final String batchId;
  final String status;
  final String? sharedBy;
  final String? errorMessage;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final Map<String, dynamic>? result;
  final bool autoClean;
  final List<BatchImage> images;
  final List<DetectedRecipient> recipients;
  final List<DetectedContact> contacts;
  final List<UnknownFace> unknowns;
  final BatchReviewIndex reviewIndex;

  BatchStatusResponse({
    required this.batchId,
    required this.status,
    this.sharedBy,
    this.errorMessage,
    this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.result,
    required this.autoClean,
    this.images = const [],
    this.recipients = const [],
    this.contacts = const [],
    this.unknowns = const [],
    BatchReviewIndex? reviewIndex,
  }) : reviewIndex = reviewIndex ??
            BatchReviewIndex(
              images: images,
              imageToUserIds: const {},
              noFaceImageIds: const {},
              unknownFaceImageIds: const {},
            );

  // Status checks
  bool get isCompleted => status == 'completed';
  bool get isProcessing => status == 'processing';
  bool get isFailed =>
      status == 'failed' || status == 'error' || status == 'timeout';
  bool get isNotStarted => status == 'not_started';

  BatchStatusResponse copyWith({
    List<DetectedContact>? contacts,
    List<UnknownFace>? unknowns,
    BatchReviewIndex? reviewIndex,
  }) {
    return BatchStatusResponse(
      batchId: batchId,
      status: status,
      sharedBy: sharedBy,
      errorMessage: errorMessage,
      createdAt: createdAt,
      startedAt: startedAt,
      finishedAt: finishedAt,
      result: result,
      autoClean: autoClean,
      images: images,
      recipients: recipients,
      contacts: contacts ?? this.contacts,
      unknowns: unknowns ?? this.unknowns,
      reviewIndex: reviewIndex ?? this.reviewIndex,
    );
  }

  /// Merges API contacts/unknowns with faces discovered in image metadata.
  BatchStatusResponse enrichDiscovery({
    required String currentUserId,
    required Set<String> friendUserIds,
    required List<OnPlatformUser> onPlatformUsers,
    Map<String, dynamic>? rawJson,
  }) {
    final derived = BatchDiscoveryDeriver.derive(
      images: images,
      currentUserId: currentUserId,
      friendUserIds: friendUserIds,
      onPlatformUsers: onPlatformUsers,
      existingContacts: contacts,
      existingUnknowns: unknowns,
    );

    var mergedContacts = _mergeContacts(contacts, derived.contacts);
    final mergedUnknowns = _mergeUnknownFaces(unknowns, derived.unknowns);

    if (_sameContactLists(mergedContacts, contacts) &&
        _sameUnknownLists(mergedUnknowns, unknowns)) {
      return this;
    }

    final enrichedIndex = rawJson == null
        ? reviewIndex
        : BatchReviewIndex.build(
            rawJson: rawJson,
            images: images,
            result: result,
            unknowns: mergedUnknowns,
            recipients: recipients,
          );

    return copyWith(
      contacts: mergedContacts,
      unknowns: mergedUnknowns,
      reviewIndex: enrichedIndex,
    );
  }

  static List<DetectedContact> _mergeContacts(
    List<DetectedContact> primary,
    List<DetectedContact> extra,
  ) {
    final byId = {for (final c in primary) c.userId: c};
    for (final contact in extra) {
      byId.putIfAbsent(contact.userId, () => contact);
    }
    return byId.values.toList();
  }

  static List<UnknownFace> _mergeUnknownFaces(
    List<UnknownFace> primary,
    List<UnknownFace> extra,
  ) {
    final byId = {for (final u in primary) u.faceId: u};
    for (final unknown in extra) {
      byId.putIfAbsent(unknown.faceId, () => unknown);
    }
    return byId.values.toList();
  }

  static bool _sameContactLists(
    List<DetectedContact> a,
    List<DetectedContact> b,
  ) {
    if (a.length != b.length) return false;
    final aIds = a.map((c) => c.userId).toSet();
    return b.every((c) => aIds.contains(c.userId));
  }

  static bool _sameUnknownLists(List<UnknownFace> a, List<UnknownFace> b) {
    if (a.length != b.length) return false;
    final aIds = a.map((u) => u.faceId).toSet();
    return b.every((u) => aIds.contains(u.faceId));
  }

  factory BatchStatusResponse.fromJson(Map<String, dynamic> json) {
    // Parse result - it can be null, a Map, or a JSON string
    Map<String, dynamic>? resultData;
    final resultRaw = json['result'];
    if (resultRaw != null) {
      if (resultRaw is String) {
        // Backend returns result as JSON string, need to decode it
        try {
          resultData = jsonDecode(resultRaw) as Map<String, dynamic>;
        } catch (e) {
          debugPrint(
            '⚠️ [BatchStatusResponse] Failed to parse result string: $e',
          );
          resultData = null;
        }
      } else if (resultRaw is Map<String, dynamic>) {
        resultData = resultRaw;
      }
    }

    // Parse images array (top level)
    List<BatchImage> imagesList = [];
    try {
      final imagesJson = json['images'] as List<dynamic>?;
      if (imagesJson != null) {
        imagesList = imagesJson
            .map((e) => BatchImage.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ [BatchStatusResponse] Error parsing images: $e');
    }

    // Parse recipients array (top level + nested result)
    List<DetectedRecipient> recipientsList = [];
    try {
      void ingestRecipients(dynamic raw) {
        if (raw is! List) return;
        for (final item in raw) {
          if (item is! Map) continue;
          recipientsList.add(
            DetectedRecipient.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }

      ingestRecipients(json['recipients']);
      if (resultData != null) {
        ingestRecipients(resultData['recipients']);
      }

      final seen = <String>{};
      recipientsList =
          recipientsList.where((r) => seen.add(r.userId)).toList();
    } catch (e) {
      debugPrint('⚠️ [BatchStatusResponse] Error parsing recipients: $e');
    }

    // Parse contacts (top level + nested result aliases)
    final contactsList = _parseDetectedContacts(json, resultData);

    var unknownsList = _parseUnknownFaces(json, resultData, imagesList);

    final reviewIndex = BatchReviewIndex.build(
      rawJson: json,
      images: imagesList,
      result: resultData,
      unknowns: unknownsList,
      recipients: recipientsList,
    );

    if (contactsList.isEmpty && unknownsList.isEmpty) {
      for (final image in reviewIndex.images) {
        final faces = image.detectedFaces ?? const [];
        debugPrint(
          '🧪 [BatchStatusResponse] Image ${image.id}: ${faces.length} detected_face(s)',
        );
        for (final face in faces) {
          debugPrint(
            '     user=${BatchFaceParser.userId(face)} '
            'face=${BatchFaceParser.faceId(face)}',
          );
        }
      }
    }

    return BatchStatusResponse(
      batchId:
          json['batch_id'] as String? ??
          json['id'] as String, // Support both field names
      status: json['status'] as String,
      sharedBy: json['shared_by'] as String?,
      errorMessage: json['error_message'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'] as String)
          : null,
      result: resultData,
      autoClean: json['auto_clean'] as bool? ?? false,
      images: reviewIndex.images,
      recipients: json['recipients'] != null ? recipientsList : [],
      contacts: contactsList,
      unknowns: unknownsList,
      reviewIndex: reviewIndex,
    );
  }
}

class BatchImage {
  final String id;
  final String? url;
  final String? thumbUrl;
  final List<String>? faceIds;
  final List<dynamic>? detectedFaces; // Raw detected faces data

  BatchImage({
    required this.id,
    this.url,
    this.thumbUrl,
    this.faceIds,
    this.detectedFaces,
  });

  /// True when this image belongs in the no-face bucket (see [BatchReviewIndex]).
  bool get hasNoFaces => isExplicitlyNoFace && !hasFaceSignals;

  /// Non-empty face metadata on the image payload.
  bool get hasFaceSignals {
    final hasDetectedFaceEntries =
        detectedFaces != null && detectedFaces!.isNotEmpty;
    final hasFaceIds = faceIds != null && faceIds!.isNotEmpty;
    return hasDetectedFaceEntries || hasFaceIds;
  }

  /// CV explicitly reported empty face arrays (not merely missing fields).
  bool get isExplicitlyNoFace {
    final emptyFaces = detectedFaces != null && detectedFaces!.isEmpty;
    final emptyIds = faceIds != null && faceIds!.isEmpty;
    return emptyFaces && (faceIds == null || emptyIds);
  }

  BatchImage mergeWith(BatchImage other) {
    return BatchImage(
      id: id,
      url: other.url ?? url,
      thumbUrl: other.thumbUrl ?? thumbUrl,
      faceIds: other.faceIds?.isNotEmpty == true ? other.faceIds : faceIds,
      detectedFaces: other.detectedFaces?.isNotEmpty == true
          ? other.detectedFaces
          : detectedFaces,
    );
  }

  /// User IDs recognized in this image from [detectedFaces] metadata.
  Set<String> get recognizedUserIds {
    final ids = <String>{};
    for (final face in detectedFaces ?? const []) {
      final userId = BatchFaceParser.userId(face);
      if (userId != null) ids.add(userId);
    }
    return ids;
  }

  factory BatchImage.fromJson(Map<String, dynamic> json) {
    // API returns 'image_url' but model expects 'url'
    // Support both field names
    final imageUrl = json['image_url'] ?? json['url'];
    final thumbUrl = json['thumb_url'] ?? json['thumbnail_url'];

    List<String>? parsedFaceIds;
    final faceIdsRaw = json['face_ids'];
    if (faceIdsRaw is List) {
      parsedFaceIds = faceIdsRaw.map((e) => e.toString()).toList();
    } else if (faceIdsRaw is String && faceIdsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(faceIdsRaw);
        if (decoded is List) {
          parsedFaceIds = decoded.map((e) => e.toString()).toList();
        }
      } catch (e) {
        debugPrint('⚠️ [BatchImage] Failed to parse face_ids string: $e');
      }
    }

    debugPrint('📦 BatchImage.fromJson:');
    debugPrint('   Raw json keys: ${json.keys.toList()}');
    debugPrint('   id: ${json['id']}');
    debugPrint('   image_url: ${json['image_url']}');
    debugPrint('   url: ${json['url']}');
    debugPrint('   Final URL: $imageUrl');
    debugPrint('   face_ids: $parsedFaceIds');

    final rawId = json['id'] ?? json['image_id'];
    return BatchImage(
      id: rawId?.toString() ?? '',
      url: _ensureAbsoluteUrl(imageUrl),
      thumbUrl: _ensureAbsoluteUrl(
        thumbUrl ?? imageUrl,
      ), // Use main image as thumb if no thumb
      faceIds: parsedFaceIds,
      detectedFaces: BatchFaceParser.parseFaceList(
        json['detected_faces'] ?? json['faces'],
      ),
    );
  }

  static String? _ensureAbsoluteUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '${ApiConstants.baseUrl}$url';
    return '${ApiConstants.baseUrl}/$url';
  }

  // Helper to determine media type from URL extension
  String get mediaType {
    if (url == null) return 'image/jpeg';
    // Remove query parameters if present
    final cleanUrl = url!.split('?').first;
    final ext = cleanUrl.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) {
      return 'video/$ext';
    }
    return 'image/jpeg';
  }
}

List<UnknownFace> _parseUnknownFaces(
  Map<String, dynamic> json,
  Map<String, dynamic>? result,
  List<BatchImage> images,
) {
  final unknowns = <UnknownFace>[];
  final seen = <String>{};

  void ingest(dynamic raw, String source) {
    if (raw is! List) return;
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        final face = UnknownFace.fromJson(Map<String, dynamic>.from(item));
        if (face.faceId.isEmpty) continue;
        if (seen.add(face.faceId)) {
          unknowns.add(face);
        }
      } catch (e) {
        debugPrint(
          '⚠️ [BatchStatusResponse] Error parsing unknown from $source: $e',
        );
      }
    }
  }

  ingest(json['unknowns'], 'unknowns');
  ingest(json['unknown_faces'], 'unknown_faces');
  ingest(json['invite_targets'], 'invite_targets');
  if (result != null) {
    ingest(result['unknowns'], 'result.unknowns');
    ingest(result['unknown_faces'], 'result.unknown_faces');
    ingest(result['invite_targets'], 'result.invite_targets');
  }

  _ingestUnknownsFromImageFaces(images, unknowns, seen);

  debugPrint('👤 [BatchStatusResponse] Parsed ${unknowns.length} unknown faces');
  return unknowns;
}

void _ingestUnknownsFromImageFaces(
  List<BatchImage> images,
  List<UnknownFace> unknowns,
  Set<String> seen,
) {
  for (final image in images) {
    for (final face in image.detectedFaces ?? const <dynamic>[]) {
      if (face is! Map) continue;
      final map = Map<String, dynamic>.from(face);
      final userId = BatchFaceParser.userId(face);
      if (userId != null && userId.isNotEmpty) continue;

      final faceId = BatchFaceParser.faceId(face);
      if (faceId == null || faceId.isEmpty) continue;
      if (!seen.add(faceId)) continue;

      unknowns.add(
        UnknownFace(
          faceId: faceId,
          representativeImageId:
              BatchFaceParser.representativeImageId(face) ?? image.id,
          bbox: BatchFaceParser.bbox(face),
          count: (map['count'] as num?)?.toInt() ??
              (map['appearance_count'] as num?)?.toInt() ??
              1,
          whatsappLink: map['whatsapp_link']?.toString() ?? '',
          smsLink: map['sms_link']?.toString() ?? '',
        ),
      );
    }
  }
}

List<DetectedContact> _parseDetectedContacts(
  Map<String, dynamic> json,
  Map<String, dynamic>? result,
) {
  final contacts = <DetectedContact>[];
  final seen = <String>{};

  void ingest(dynamic raw, String source) {
    if (raw is! List) return;
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        final contact = DetectedContact.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (seen.add(contact.userId)) {
          contacts.add(contact);
        }
      } catch (e) {
        debugPrint(
          '⚠️ [BatchStatusResponse] Error parsing contact from $source: $e',
        );
      }
    }
  }

  ingest(json['contacts'], 'contacts');
  ingest(json['found_contacts'], 'found_contacts');
  ingest(json['detected_contacts'], 'detected_contacts');
  ingest(json['new_connections'], 'new_connections');
  if (result != null) {
    ingest(result['contacts'], 'result.contacts');
    ingest(result['found_contacts'], 'result.found_contacts');
    ingest(result['detected_contacts'], 'result.detected_contacts');
    ingest(result['contact_suggestions'], 'result.contact_suggestions');
    ingest(result['recommended_contacts'], 'result.recommended_contacts');
    ingest(result['new_connections'], 'result.new_connections');
  }

  debugPrint('📇 [BatchStatusResponse] Parsed ${contacts.length} batch contacts');
  return contacts;
}

/// Parses face metadata from batch image payloads.
class BatchFaceParser {
  BatchFaceParser._();

  static List<dynamic>? parseFaceList(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) return raw;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
      } catch (e) {
        debugPrint('⚠️ [BatchFaceParser] Failed to parse face list string: $e');
      }
    }
    return null;
  }

  static String? userId(dynamic face) {
    if (face is Map) {
      for (final key in const [
        'user_id',
        'friend_id',
        'matched_user_id',
        'recipient_id',
      ]) {
        final value = face[key];
        if (value != null && value.toString().isNotEmpty) {
          return value.toString();
        }
      }

      for (final nestedKey in const ['user', 'friend', 'matched_user']) {
        final nested = face[nestedKey];
        if (nested is Map) {
          final nestedId = nested['id'] ?? nested['user_id'];
          if (nestedId != null && nestedId.toString().isNotEmpty) {
            return nestedId.toString();
          }
        }
      }
    }
    return null;
  }

  static String? faceId(dynamic face) {
    if (face is Map) {
      for (final key in const ['face_id', 'faceId', 'id']) {
        final value = face[key];
        if (value != null && value.toString().isNotEmpty) {
          return value.toString();
        }
      }
    }
    return null;
  }

  static String? username(dynamic face) {
    if (face is! Map) return null;
    for (final key in const ['username', 'user_name']) {
      final value = face[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    for (final nestedKey in const ['user', 'matched_user']) {
      final nested = face[nestedKey];
      if (nested is Map) {
        final name = nested['username'];
        if (name != null && name.toString().isNotEmpty) {
          return name.toString();
        }
      }
    }
    return null;
  }

  static String? displayName(dynamic face) {
    if (face is! Map) return null;
    for (final key in const [
      'display_name',
      'contact_name',
      'first_name',
      'name',
    ]) {
      final value = face[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  static String? profilePicId(dynamic face) {
    if (face is! Map) return null;
    for (final key in const ['profile_pic_id', 'profilePicId']) {
      final value = face[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    final user = face['user'];
    if (user is Map) {
      final pic = user['profile_pic_id'];
      if (pic != null && pic.toString().isNotEmpty) {
        return pic.toString();
      }
    }
    return null;
  }

  static String? representativeImageId(dynamic face) {
    if (face is! Map) return null;
    for (final key in const [
      'representative_image_id',
      'image_id',
      'source_image_id',
    ]) {
      final value = face[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  static Map<String, dynamic>? bbox(dynamic face) {
    if (face is! Map) return null;
    final raw = face['bbox'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }
}
