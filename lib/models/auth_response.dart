import 'package:prism/models/user_model.dart';

class AuthResponse {
  final UserModel user;
  final String message;
  final String? accessToken;
  final String? refreshToken;
  final bool? phoneSynced; // V2: false = phone number was malformed
  final bool? exists; // Google login: false = needs registration

  AuthResponse({
    required this.user,
    required this.message,
    this.accessToken,
    this.refreshToken,
    this.phoneSynced,
    this.exists,
  });

  /// Backward-compatible alias used across existing call sites.
  String? get token => accessToken;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Check if user data is nested under 'user' key
    final userData =
        (json['user'] != null && json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : json;

    return AuthResponse(
      user: UserModel.fromJson(userData),
      message: json['message'] ?? 'Success',
      accessToken: json['access_token'] ?? json['token'],
      refreshToken: json['refresh_token'] as String?,
      phoneSynced: json['phone_synced'] as bool?,
      exists: json['exists'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...user.toJson(),
      'message': message,
      if (accessToken != null) 'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (phoneSynced != null) 'phone_synced': phoneSynced,
      if (exists != null) 'exists': exists,
    };
  }
}
