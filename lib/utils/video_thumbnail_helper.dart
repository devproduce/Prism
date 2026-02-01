import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class VideoThumbnailHelper {
  static final Map<String, String> _thumbnailCache = {};

  static Future<String?> getThumbnail(
    String videoUrl, {
    Map<String, String>? headers,
  }) async {
    if (_thumbnailCache.containsKey(videoUrl)) {
      return _thumbnailCache[videoUrl];
    }

    try {
      final fileName = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        headers: headers ?? {}, // Check consistency with library version
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight:
            256, // Specify the height of the thumbnail, let the width auto-scaled to keep the source aspect ratio
        quality: 75,
      );

      if (fileName != null) {
        _thumbnailCache[videoUrl] = fileName;
        return fileName;
      }
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
    }
    return null;
  }
}
