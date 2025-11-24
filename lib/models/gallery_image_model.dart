class GalleryImage {
  final ImageData image;
  final List<FaceData> faces;
  final GalleryMeta galleryMeta;

  GalleryImage({
    required this.image,
    required this.faces,
    required this.galleryMeta,
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
        imageUrl: json['image_url']?.toString() ?? '',
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
