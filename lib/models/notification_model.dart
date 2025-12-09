import 'dart:convert';
import 'package:prism/utils/constants.dart';

class NotificationModel {
  final String id;
  final String type; // 'friend_request', 'batch_share', 'friend_req_accepted', etc.
  final String message; // Display message (from 'title' or 'message' field)
  final String? userId; // Related user (for friend requests)
  final String? username;
  final String? profilePicId;
  final String? resourceId; // batch_id, friendship_id, etc.
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
    this.resourceId,
    this.metadata,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Handle id as int or string
    final idRaw = json['id'] ?? json['notification_id'];
    final id = idRaw?.toString() ?? '';

    // Handle metadata safely
    Map<String, dynamic>? metadata;
    if (json['metadata'] is Map) {
      metadata = Map<String, dynamic>.from(json['metadata']);
    } else if (json['metadata'] is String) {
      try {
        final decoded = jsonDecode(json['metadata']);
        if (decoded is Map) {
          metadata = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }

    // Backend returns 'title' field, not 'message'
    final displayMessage = json['title'] ?? json['message'] ?? '';

    return NotificationModel(
      id: id,
      type: json['type'] ?? 'unknown',
      message: displayMessage,
      userId: json['user_id'],
      username: json['username'],
      profilePicId: json['profile_pic_id'],
      resourceId: json['resource_id'],
      metadata: metadata,
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
      return '${ApiConstants.baseUrl}/images/$profilePicId';
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
