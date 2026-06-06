// Models for sharing functionality

import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      count: json['count'] as int,
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
      userId: json['user_id'] as String,
      username: json['username'] as String,
      profilePicId: json['profile_pic_id'] as String?,
    );
  }
}

class UnknownFace {
  final String faceId;
  final String imageUrl;

  UnknownFace({required this.faceId, required this.imageUrl});

  factory UnknownFace.fromJson(Map<String, dynamic> json) {
    return UnknownFace(
      faceId: json['face_id'] as String,
      imageUrl: BatchImage._ensureAbsoluteUrl(json['image_url'] as String?) ?? '',
    );
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
  });

  // Status checks
  bool get isCompleted => status == 'completed';
  bool get isProcessing => status == 'processing';
  bool get isFailed =>
      status == 'failed' || status == 'error' || status == 'timeout';
  bool get isNotStarted => status == 'not_started';

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

    // Parse recipients array (top level)
    List<DetectedRecipient> recipientsList = [];
    try {
      final recipientsJson = json['recipients'] as List<dynamic>?;
      if (recipientsJson != null) {
        recipientsList = recipientsJson
            .map((e) => DetectedRecipient.fromJson(e as Map<String, dynamic>))
            .toList();
        final seen = <String>{};
        recipientsList =
            recipientsList.where((r) => seen.add(r.userId)).toList();
      }
    } catch (e) {
      debugPrint('⚠️ [BatchStatusResponse] Error parsing recipients: $e');
    }

    // Parse contacts array (top level)
    List<DetectedContact> contactsList = [];
    try {
      final contactsJson = json['contacts'] as List<dynamic>?;
      if (contactsJson != null) {
        contactsList = contactsJson
            .map((e) => DetectedContact.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ [BatchStatusResponse] Error parsing contacts: $e');
    }

    // Parse unknowns array (top level)
    List<UnknownFace> unknownsList = [];
    try {
      final unknownsJson = json['unknowns'] as List<dynamic>?;
      if (unknownsJson != null) {
        unknownsList = unknownsJson
            .map((e) => UnknownFace.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ [BatchStatusResponse] Error parsing unknowns: $e');
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
      images: json['images'] != null ? imagesList : [],
      recipients: json['recipients'] != null ? recipientsList : [],
      contacts: json['contacts'] != null ? contactsList : [],
      unknowns: json['unknowns'] != null ? unknownsList : [],
    );
  }
}

class BatchImage {
  final String id;
  final String? url;
  final String? thumbUrl;
  final List<dynamic>? detectedFaces; // Raw detected faces data

  BatchImage({required this.id, this.url, this.thumbUrl, this.detectedFaces});

  factory BatchImage.fromJson(Map<String, dynamic> json) {
    // API returns 'image_url' but model expects 'url'
    // Support both field names
    final imageUrl = json['image_url'] ?? json['url'];
    final thumbUrl = json['thumb_url'] ?? json['thumbnail_url'];

    debugPrint('📦 BatchImage.fromJson:');
    debugPrint('   Raw json keys: ${json.keys.toList()}');
    debugPrint('   id: ${json['id']}');
    debugPrint('   image_url: ${json['image_url']}');
    debugPrint('   url: ${json['url']}');
    debugPrint('   Final URL: $imageUrl');

    return BatchImage(
      id: json['id'],
      url: _ensureAbsoluteUrl(imageUrl),
      thumbUrl: _ensureAbsoluteUrl(
        thumbUrl ?? imageUrl,
      ), // Use main image as thumb if no thumb
      detectedFaces: json['detected_faces'] as List<dynamic>?,
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
