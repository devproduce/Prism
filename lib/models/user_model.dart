import 'package:prism/utils/constants.dart';

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
  final String? archivePin;
  final String? authProvider;
  final DateTime? deletionScheduledAt;

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
    this.archivePin,
    this.authProvider,
    this.deletionScheduledAt,
  });

  bool get isDeletionPending => deletionScheduledAt != null;

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
      archivePin: json['archive_pin'],
      authProvider: json['auth_provider'] as String?,
      deletionScheduledAt: _parseDeletionScheduledAt(json),
    );
  }

  static DateTime? _parseDeletionScheduledAt(Map<String, dynamic> json) {
    for (final key in [
      'deletion_scheduled_at',
      'scheduled_deletion_at',
      'account_deletion_at',
    ]) {
      final value = json[key];
      if (value == null) continue;
      if (value is bool) return value ? DateTime.now() : null;
      final parsed = DateTime.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    if (json['deletion_pending'] == true || json['account_deletion_pending'] == true) {
      return DateTime.now();
    }
    return null;
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
      'archive_pin': archivePin,
      'auth_provider': authProvider,
      if (deletionScheduledAt != null)
        'deletion_scheduled_at': deletionScheduledAt!.toIso8601String(),
    };
  }

  // Helper getter for profile picture URL
  String? get profilePictureUrl {
    // Priority: imageId > profilePicId
    final picId = imageId ?? profilePicId;
    if (picId == null || picId.isEmpty) return null;

    // If it's already a full URL, return it
    if (picId.startsWith('http')) return picId;

    // Otherwise, construct the URL from base URL
    return '${ApiConstants.baseUrl}/images/$picId';
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
    String? archivePin,
    String? authProvider,
    DateTime? deletionScheduledAt,
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
      archivePin: archivePin ?? this.archivePin,
      authProvider: authProvider ?? this.authProvider,
      deletionScheduledAt: deletionScheduledAt ?? this.deletionScheduledAt,
    );
  }
}
