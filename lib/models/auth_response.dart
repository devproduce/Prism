import 'package:prism/models/user_model.dart';

class AuthResponse {
  final UserModel user;
  final String message;
  final String? token; // Auth token from backend (if provided)
  final bool? phoneSynced; // V2: false = phone number was malformed

  AuthResponse({
    required this.user,
    required this.message,
    this.token,
    this.phoneSynced,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Check if user data is nested under 'user' key
    final userData =
        (json['user'] != null && json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : json;

    return AuthResponse(
      user: UserModel.fromJson(userData),
      message: json['message'] ?? 'Success',
      token: json['access_token'] ?? json['token'], // Try both field names
      phoneSynced: json['phone_synced'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...user.toJson(),
      'message': message,
      if (token != null) 'token': token,
      if (phoneSynced != null) 'phone_synced': phoneSynced,
    };
  }
}
