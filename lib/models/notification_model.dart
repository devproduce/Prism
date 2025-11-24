class NotificationModel {
  final String id;
  final String type; // 'friend_request', 'image_share', etc.
  final String message;
  final String? userId; // Related user (for friend requests)
  final String? username;
  final String? profilePicId;
  final Map<String, dynamic>? metadata; // Additional data
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.type,
    required this.message,
    this.userId,
    this.username,
    this.profilePicId,
    this.metadata,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Handle id as int or string
    final idRaw = json['id'] ?? json['notification_id'];
    final id = idRaw?.toString() ?? '';

    return NotificationModel(
      id: id,
      type: json['type'] ?? 'unknown',
      message: json['message'] ?? '',
      userId: json['user_id'] ?? json['related_user_id'],
      username: json['username'],
      profilePicId: json['profile_pic_id'],
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['is_read'] ?? json['read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'message': message,
      'user_id': userId,
      'username': username,
      'profile_pic_id': profilePicId,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  String get profilePictureUrl {
    if (profilePicId != null && profilePicId!.isNotEmpty) {
      return 'http://10.0.2.2:8001/images/$profilePicId';
    }
    return '';
  }

  // Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7}w ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
