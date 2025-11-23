import 'package:prism/models/user_model.dart';

class AuthResponse {
  final UserModel user;
  final String message;

  AuthResponse({required this.user, required this.message});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: UserModel.fromJson(json),
      message: json['message'] ?? 'Success',
    );
  }

  Map<String, dynamic> toJson() {
    return {...user.toJson(), 'message': message};
  }
}
