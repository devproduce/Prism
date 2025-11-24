class Friend {
  final String userId;
  final String username;
  final String? profilePicId;
  final String? firstName;
  final String? lastName;
  final String? bio;

  Friend({
    required this.userId,
    required this.username,
    this.profilePicId,
    this.firstName,
    this.lastName,
    this.bio,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    // Handle id as int or string
    final userIdRaw = json['user_id'] ?? json['id'];
    final userId = userIdRaw?.toString() ?? '';

    return Friend(
      userId: userId,
      username: json['username'] ?? '',
      profilePicId: json['profile_pic_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      bio: json['bio'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'profile_pic_id': profilePicId,
      'first_name': firstName,
      'last_name': lastName,
      'bio': bio,
    };
  }

  String get displayName {
    if (firstName != null && firstName!.isNotEmpty) {
      return lastName != null && lastName!.isNotEmpty
          ? '$firstName $lastName'
          : firstName!;
    }
    return username;
  }

  String get profilePictureUrl {
    if (profilePicId != null && profilePicId!.isNotEmpty) {
      // Use the same base URL as images
      return 'http://10.0.2.2:8001/images/$profilePicId';
    }
    return '';
  }
}

class FriendRequest {
  final String friendshipId;
  final String userId; // The other user's ID (not the current user)
  final String username;
  final String? profilePicId;
  final String? firstName;
  final String? lastName;
  final DateTime? createdAt;
  final String status; // 'pending', 'accepted', 'rejected'
  final String requesterId; // Who sent the request
  final String receiverId; // Who received the request

  FriendRequest({
    required this.friendshipId,
    required this.userId,
    required this.username,
    this.profilePicId,
    this.firstName,
    this.lastName,
    this.createdAt,
    required this.status,
    required this.requesterId,
    required this.receiverId,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    // Handle friendship_id as int or string
    final friendshipIdRaw = json['friendship_id'] ?? json['id'];
    final friendshipId = friendshipIdRaw?.toString() ?? '';

    return FriendRequest(
      friendshipId: friendshipId,
      userId:
          json['user_id'] ?? json['requester_id'] ?? json['addressee_id'] ?? '',
      username: json['username'] ?? '',
      profilePicId: json['profile_pic_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      status: json['status'] ?? json['friendship_status'] ?? 'pending',
      requesterId: json['requester_id'] ?? '',
      receiverId: json['receiver_id'] ?? json['addressee_id'] ?? '',
    );
  }

  String get displayName {
    if (firstName != null && firstName!.isNotEmpty) {
      return lastName != null && lastName!.isNotEmpty
          ? '$firstName $lastName'
          : firstName!;
    }
    return username;
  }

  String get profilePictureUrl {
    if (profilePicId != null && profilePicId!.isNotEmpty) {
      // Use the same base URL as images
      return 'http://10.0.2.2:8001/images/$profilePicId';
    }
    return '';
  }
}
