import 'package:prism/models/user_model.dart';

class AuthResponse {
  final UserModel user;
  final String message;
  final String? token; // Auth token from backend (if provided)

  AuthResponse({required this.user, required this.message, this.token});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: UserModel.fromJson(json),
      message: json['message'] ?? 'Success',
      token: json['access_token'] ?? json['token'], // Try both field names
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...user.toJson(),
      'message': message,
      if (token != null) 'token': token,
    };
  }
}
