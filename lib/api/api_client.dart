import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:prism/utils/constants.dart';
import 'package:prism/models/user_model.dart';
import 'package:prism/models/auth_response.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _client = http.Client();
  String? _authToken;

  // Set authentication token
  void setAuthToken(String token) {
    _authToken = token;
  }

  // Clear authentication token
  void clearAuthToken() {
    _authToken = null;
  }

  // Get common headers
  Map<String, String> _getHeaders({bool isMultipart = false}) {
    final headers = <String, String>{
      if (!isMultipart) 'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
    return headers;
  }

  // Handle API response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    } else {
      final errorBody = response.body.isNotEmpty
          ? json.decode(response.body)
          : {'detail': 'Unknown error'};
      final errorMessage =
          errorBody['detail'] ?? errorBody['message'] ?? 'Request failed';
      throw ApiException(errorMessage, response.statusCode);
    }
  }

  // ==================== AUTH ENDPOINTS ====================

  /// Register a new user
  /// POST /auth/register
  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    String? lastName,
    required File profileImage,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}');
      final request = http.MultipartRequest('POST', uri);

      // Add form fields
      request.fields['username'] = username;
      request.fields['email'] = email;
      request.fields['password'] = password;
      request.fields['first_name'] = firstName;
      if (lastName != null && lastName.isNotEmpty) {
        request.fields['last_name'] = lastName;
      }

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath('image', profileImage.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = _handleResponse(response);

      return AuthResponse.fromJson(data);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Registration failed: ${e.toString()}');
    }
  }

  /// Login user
  /// POST /auth/login
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}');
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({'email': email, 'password': password}),
      );

      final data = _handleResponse(response);
      return AuthResponse.fromJson(data);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Login failed: ${e.toString()}');
    }
  }

  // ==================== USER ENDPOINTS ====================

  /// Get current user details
  /// GET /users/me
  Future<UserModel> getCurrentUser(String userId) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.getCurrentUser}',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.get(uri, headers: _getHeaders());
      final data = _handleResponse(response);

      return UserModel.fromJson(data);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get user: ${e.toString()}');
    }
  }

  /// Update user profile
  /// PUT /users/me
  Future<UserModel> updateProfile({
    required String userId,
    String? username,
    String? firstName,
    String? lastName,
    String? pronouns,
    String? bio,
    DateTime? dob,
    String? countryCode,
    String? phoneNumber,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.updateProfile}',
      );
      final request = http.MultipartRequest('PUT', uri);

      request.fields['user_id'] = userId;
      if (username != null) request.fields['username'] = username;
      if (firstName != null) request.fields['first_name'] = firstName;
      if (lastName != null) request.fields['last_name'] = lastName;
      if (pronouns != null) request.fields['pronouns'] = pronouns;
      if (bio != null) request.fields['bio'] = bio;
      if (dob != null)
        request.fields['dob'] = dob.toIso8601String().split('T')[0];
      if (countryCode != null) request.fields['country_code'] = countryCode;
      if (phoneNumber != null) request.fields['phone_number'] = phoneNumber;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = _handleResponse(response);

      return UserModel.fromJson(data);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to update profile: ${e.toString()}');
    }
  }

  // Dispose method to close the client
  void dispose() {
    _client.close();
  }
}
