class UserModel {
  final String userId;
  final String username;
  final String email;
  final String firstName;
  final String? lastName;
  final String? faceId;
  final String? imageId;
  final String? profilePicId;
  final String? pronouns;
  final String? bio;
  final DateTime? dob;
  final String? countryCode;
  final String? phoneNumber;
  final DateTime? createdAt;

  UserModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.firstName,
    this.lastName,
    this.faceId,
    this.imageId,
    this.profilePicId,
    this.pronouns,
    this.bio,
    this.dob,
    this.countryCode,
    this.phoneNumber,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] ?? json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'],
      faceId: json['face_id'],
      imageId: json['image_id'],
      profilePicId: json['profile_pic_id'],
      pronouns: json['pronouns'],
      bio: json['bio'],
      dob: json['dob'] != null ? DateTime.tryParse(json['dob']) : null,
      countryCode: json['country_code'],
      phoneNumber: json['phone_number'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'face_id': faceId,
      'image_id': imageId,
      'profile_pic_id': profilePicId,
      'pronouns': pronouns,
      'bio': bio,
      'dob': dob?.toIso8601String(),
      'country_code': countryCode,
      'phone_number': phoneNumber,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // Helper getter for profile picture URL
  String? get profilePictureUrl {
    if (profilePicId == null) return null;
    // If it's already a full URL, return it
    if (profilePicId!.startsWith('http')) return profilePicId;
    // Otherwise, construct the URL from base URL
    return 'http://10.0.2.2:8001/images/$profilePicId';
  }

  UserModel copyWith({
    String? userId,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? faceId,
    String? imageId,
    String? profilePicId,
    String? pronouns,
    String? bio,
    DateTime? dob,
    String? countryCode,
    String? phoneNumber,
    DateTime? createdAt,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      faceId: faceId ?? this.faceId,
      imageId: imageId ?? this.imageId,
      profilePicId: profilePicId ?? this.profilePicId,
      pronouns: pronouns ?? this.pronouns,
      bio: bio ?? this.bio,
      dob: dob ?? this.dob,
      countryCode: countryCode ?? this.countryCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
