import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:prism/models/contact_sync_result.dart';
import 'package:prism/models/sharing_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists unknown faces detected in upload batches for the Friends screen.
class BatchUnknownFacesStore {
  BatchUnknownFacesStore._();

  static String _key(String userId) => 'batch_unknown_faces_$userId';

  static Future<List<UnknownFaceRecommendation>> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (item) => UnknownFaceRecommendation.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[BatchUnknownFacesStore] Failed to load: $e');
      return [];
    }
  }

  static Future<void> appendFromBatch({
    required String userId,
    required String batchId,
    required List<UnknownFace> unknowns,
  }) async {
    if (unknowns.isEmpty) return;

    final existing = await load(userId);
    final byFaceId = {for (final face in existing) face.faceId: face};

    for (final unknown in unknowns) {
      if (unknown.faceId.isEmpty) continue;
      byFaceId[unknown.faceId] = unknown.toRecommendation();
    }

    final merged = byFaceId.values.toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId),
      jsonEncode(merged.map(_recommendationToJson).toList()),
    );

    debugPrint(
      '[BatchUnknownFacesStore] Saved ${unknowns.length} unknown(s) from batch $batchId',
    );
  }

  static Map<String, dynamic> _recommendationToJson(
    UnknownFaceRecommendation face,
  ) {
    return {
      'face_id': face.faceId,
      'representative_image_id': face.representativeImageId,
      if (face.bbox != null) 'bbox': face.bbox,
      'appearance_count': face.appearanceCount,
      'whatsapp_link': face.whatsappLink,
      'sms_link': face.smsLink,
    };
  }
}
