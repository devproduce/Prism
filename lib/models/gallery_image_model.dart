import 'package:prism/utils/constants.dart';

class GalleryImage {
  final ImageData image;
  final List<FaceData> faces;
  final GalleryMeta galleryMeta;
  final String? type; // 'sent' or 'received' from shared gallery API

  GalleryImage({
    required this.image,
    required this.faces,
    required this.galleryMeta,
    this.type,
  });

  factory GalleryImage.fromJson(Map<String, dynamic> json) {
    try {
      return GalleryImage(
        image: ImageData.fromJson(json['image'] as Map<String, dynamic>),
        faces:
            (json['faces'] as List?)
                ?.map((face) => FaceData.fromJson(face as Map<String, dynamic>))
                .toList() ??
            [],
        galleryMeta: GalleryMeta.fromJson(
          json['gallery_meta'] as Map<String, dynamic>? ?? {},
        ),
        type: json['type']?.toString(),
      );
    } catch (e) {
      print('Error parsing GalleryImage: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'image': image.toJson(),
      'faces': faces.map((face) => face.toJson()).toList(),
      'gallery_meta': galleryMeta.toJson(),
      if (type != null) 'type': type,
    };
  }
}

class ImageData {
  final String id;
  final String storagePath;
  final String imageUrl;
  final DateTime? takenAt;
  final int? width;
  final int? height;
  final Map<String, dynamic>? metadata;

  ImageData({
    required this.id,
    required this.storagePath,
    required this.imageUrl,
    this.takenAt,
    this.width,
    this.height,
    this.metadata,
  });

  factory ImageData.fromJson(Map<String, dynamic> json) {
    try {
      return ImageData(
        id: json['id']?.toString() ?? '',
        storagePath: json['storage_path']?.toString() ?? '',
        imageUrl: _ensureAbsoluteUrl(json['image_url']?.toString()),
        takenAt: json['taken_at'] != null
            ? DateTime.tryParse(json['taken_at'].toString())
            : null,
        width: json['width'] is int ? json['width'] : null,
        height: json['height'] is int ? json['height'] : null,
        metadata: json['metadata'] is Map
            ? json['metadata'] as Map<String, dynamic>
            : null,
      );
    } catch (e) {
      print('Error parsing ImageData: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storage_path': storagePath,
      'image_url': imageUrl,
      'taken_at': takenAt?.toIso8601String(),
      'width': width,
      'height': height,
      'metadata': metadata,
    };
  }

  // Helper to ensure URLs are absolute for new cloud providers
  static String _ensureAbsoluteUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '${ApiConstants.baseUrl}$url';
    return '${ApiConstants.baseUrl}/$url';
  }

  // Helper to determine media type from URL extension
  String get mediaType {
    if (imageUrl.isEmpty) return 'image/jpeg';
    // Remove query parameters if present (e.g. signed URLs)
    final cleanUrl = imageUrl.split('?').first;
    final ext = cleanUrl.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) {
      return 'video/$ext';
    }
    return 'image/jpeg';
  }

  /// Check if the presigned URL is expired (for AWS S3/Supabase URLs)
  bool get isUrlExpired {
    try {
      final uri = Uri.parse(imageUrl);
      final dateParam = uri.queryParameters['X-Amz-Date'];
      final expiresParam = uri.queryParameters['X-Amz-Expires'];

      if (dateParam == null || expiresParam == null) {
        // Not a signed URL, assume it's valid
        return false;
      }

      // Parse the date (format: 20251128T081108Z)
      final year = int.parse(dateParam.substring(0, 4));
      final month = int.parse(dateParam.substring(4, 6));
      final day = int.parse(dateParam.substring(6, 8));
      final hour = int.parse(dateParam.substring(9, 11));
      final minute = int.parse(dateParam.substring(11, 13));
      final second = int.parse(dateParam.substring(13, 15));

      final urlDate = DateTime.utc(year, month, day, hour, minute, second);
      final expiresInSeconds = int.parse(expiresParam);
      final expiryDate = urlDate.add(Duration(seconds: expiresInSeconds));

      return DateTime.now().toUtc().isAfter(expiryDate);
    } catch (e) {
      // If we can't parse the URL, assume it's not expired
      return false;
    }
  }
}

class FaceData {
  final String id;
  final String? userId;
  final String? username;

  FaceData({required this.id, this.userId, this.username});

  factory FaceData.fromJson(Map<String, dynamic> json) {
    return FaceData(
      id: json['id'] ?? '',
      userId: json['user_id'],
      username: json['username'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'user_id': userId, 'username': username};
  }
}

class GalleryMeta {
  final bool favourite;
  final bool archive;
  final bool bin;

  GalleryMeta({
    required this.favourite,
    required this.archive,
    required this.bin,
  });

  factory GalleryMeta.fromJson(Map<String, dynamic> json) {
    try {
      return GalleryMeta(
        favourite: json['favourite'] == true || json['favourite'] == 1,
        archive: json['archive'] == true || json['archive'] == 1,
        bin: json['bin'] == true || json['bin'] == 1,
      );
    } catch (e) {
      print('Error parsing GalleryMeta: $e');
      print('JSON data: $json');
      return GalleryMeta(favourite: false, archive: false, bin: false);
    }
  }

  Map<String, dynamic> toJson() {
    return {'favourite': favourite, 'archive': archive, 'bin': bin};
  }
}
