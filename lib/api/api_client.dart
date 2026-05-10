import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:prism/utils/constants.dart';
import 'package:prism/models/user_model.dart';
import 'package:prism/models/auth_response.dart';
import 'package:prism/models/contact_sync_result.dart';

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

  // Get authentication token
  String? get token => _authToken;

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
      try {
        return json.decode(response.body);
      } catch (e) {
        print('Failed to parse JSON response: ${response.body}');
        throw ApiException('Invalid response format from server');
      }
    } else {
      // Extract a clean, human-readable message from the error response.
      // Never expose raw JSON to the user.
      final message = _extractErrorMessage(response.body, response.statusCode);
      throw ApiException(message, response.statusCode);
    }
  }

  /// Safely extracts a human-readable error message from a backend response body.
  /// Checks multiple common error field names and falls back gracefully.
  static String _extractErrorMessage(String body, int statusCode) {
    if (body.isEmpty) {
      return _statusCodeFallback(statusCode);
    }

    try {
      final decoded = json.decode(body);
      if (decoded is Map) {
        // Check the most common backend error fields in priority order
        for (final key in ['detail', 'message', 'error', 'msg']) {
          final value = decoded[key];
          if (value != null && value.toString().isNotEmpty) {
            return value.toString();
          }
        }
        // Django-style field validation errors: {"username": ["This field is required."]}
        final firstKey = decoded.keys.first;
        final firstValue = decoded[firstKey];
        if (firstValue is List && firstValue.isNotEmpty) {
          return firstValue.first.toString();
        }
        if (firstValue is String && firstValue.isNotEmpty) {
          return firstValue;
        }
      } else if (decoded is String && decoded.isNotEmpty) {
        return decoded;
      } else if (decoded is List && decoded.isNotEmpty) {
        return decoded.first.toString();
      }
    } catch (_) {
      // Body is not JSON — if it's short plain text, use it directly
      if (body.length < 200 && !body.trimLeft().startsWith('<')) {
        return body.trim();
      }
    }

    return _statusCodeFallback(statusCode);
  }

  static String _statusCodeFallback(int statusCode) {
    switch (statusCode) {
      case 400: return 'Invalid request. Please check your input.';
      case 401: return 'Your session has expired. Please log in again.';
      case 403: return 'You do not have permission to perform this action.';
      case 404: return 'The requested resource was not found.';
      case 409: return 'A conflict occurred. Please try again.';
      case 429: return 'Too many requests. Please wait a moment and try again.';
      case 500: return 'Something went wrong on our end. Please try again later.';
      case 502:
      case 503:
      case 504: return 'Server is temporarily unavailable. Please try again.';
      default:  return 'An error occurred. Please try again.';
    }
  }

  // ==================== AUTH ENDPOINTS ====================

  /// Check if username is available
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/auth/check-availability?type=username&value=$username');
      final response = await _client.get(
        uri,
        headers: _getHeaders(),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        return data['available'] == true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Error checking username availability: $e');
      return false; // Fail safe
    }
  }

  /// Register device token for FCM
  Future<void> registerDeviceToken({
    required String userId,
    required String deviceId,
    required String fcmToken,
    required String platform,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/notifications/device/register');
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({
          'user_id': userId,
          'device_id': deviceId,
          'fcm_token': fcmToken,
          'platform': platform,
        }),
      );

      _handleResponse(response);
    } catch (e) {
      debugPrint('Error in registerDeviceToken API: $e');
      throw ApiException('Failed to register device token: $e');
    }
  }

  /// Register a new user (V2 — phone-first)
  /// POST /auth/register
  /// phone fields are mandatory; email & firstName are optional
  Future<AuthResponse> register({
    required String username,
    required String password,
    required String countryCode,
    required String phoneNumber,
    String? email,
    String? firstName,
    String? lastName,
    File? profileImage,
    List<String>? faceIds,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}');
      final request = http.MultipartRequest('POST', uri);

      // Mandatory fields
      request.fields['username'] = username;
      request.fields['password'] = password;
      // Strip leading '+' — backend expects numeric country code e.g. "91"
      request.fields['country_code'] = countryCode.replaceAll('+', '').trim();
      request.fields['phone_number'] = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // Optional fields
      if (email != null && email.isNotEmpty) {
        request.fields['email'] = email;
      }
      if (firstName != null && firstName.isNotEmpty) {
        request.fields['first_name'] = firstName;
      }
      if (lastName != null && lastName.isNotEmpty) {
        request.fields['last_name'] = lastName;
      }

      // Add face_ids if provided (multi-view registration)
      if (faceIds != null && faceIds.isNotEmpty) {
        request.fields['face_ids'] = json.encode(faceIds);
        debugPrint('✓ Including ${faceIds.length} face IDs in registration');
      }

      // Add image file if provided
      if (profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', profileImage.path),
        );
      }

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
  /// Now accepts either username OR email as identifier
  Future<AuthResponse> login({
    required String identifier, // Changed from 'email' to 'identifier'
    required String password,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}');
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({
          'identifier': identifier, // Changed from 'email' to 'identifier'
          'password': password,
        }),
      );

      final data = _handleResponse(response);
      return AuthResponse.fromJson(data);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Login failed: ${e.toString()}');
    }
  }

  /// Verify password for archive unlock
  /// POST /auth/verify-password
  Future<bool> verifyPassword({
    required String userId,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/auth/verify-password');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_getHeaders(isMultipart: true));
      request.fields['user_id'] = userId;
      request.fields['password'] = password;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = _handleResponse(response);

      return data['valid'] as bool;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Password verification failed: ${e.toString()}');
    }
  }

  /// Forgot password
  /// POST /auth/forgot-password
  Future<void> forgotPassword(String email) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/auth/forgot-password');
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({'email': email}),
      );

      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to send reset link: ${e.toString()}');
    }
  }

  /// Delete account
  /// DELETE /auth/delete-account
  Future<void> deleteAccount({
    required String userId,
    required String password,
    required String reason,
    String? feedback,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/auth/delete-account');
      final response = await _client.delete(
        uri,
        headers: _getHeaders(),
        body: json.encode({
          'user_id': userId,
          'password': password,
          'reason': reason,
          if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
        }),
      );

      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to delete account: ${e.toString()}');
    }
  }

  /// Check username or email availability
  /// GET /auth/check-availability
  Future<bool> checkAvailability({
    required String type, // 'username' or 'email'
    required String value,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/auth/check-availability',
      ).replace(queryParameters: {'type': type, 'value': value});

      final response = await _client.get(uri, headers: _getHeaders());
      final data = _handleResponse(response);
      return data['available'] as bool;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to check availability: ${e.toString()}');
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

  /// Get user by ID
  /// GET /users/{user_id}
  Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/users/$userId');
      debugPrint('GET request to: $uri');
      debugPrint('Fetching user with ID: $userId');

      final response = await _client.get(uri, headers: _getHeaders());
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error in getUserById: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get user by ID: ${e.toString()}');
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
      request.headers.addAll(_getHeaders(isMultipart: true));

      request.fields['user_id'] = userId;
      if (username != null) request.fields['username'] = username;
      if (firstName != null) request.fields['first_name'] = firstName;
      if (lastName != null) request.fields['last_name'] = lastName;
      if (pronouns != null) request.fields['pronouns'] = pronouns;
      if (bio != null) request.fields['bio'] = bio;
      if (dob != null) {
        request.fields['dob'] = dob.toIso8601String().split('T')[0];
      }
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

  /// Upload/Update profile picture
  /// PUT /users/me/profile-picture
  Future<UserModel> uploadProfilePicture({
    required String userId,
    required File profileImage,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.uploadProfilePicture}',
      );
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_getHeaders(isMultipart: true));

      request.fields['user_id'] = userId;
      request.files.add(
        await http.MultipartFile.fromPath('image', profileImage.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = _handleResponse(response);

      return UserModel.fromJson(data);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to upload profile picture: ${e.toString()}');
    }
  }

  /// Reset profile picture to default avatar
  /// DELETE /users/me/profile-picture
  Future<Map<String, dynamic>> resetProfilePicture({
    required String userId,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/users/me/profile-picture');
      // Use MultipartRequest for form data
      final request = http.MultipartRequest('DELETE', uri);
      request.headers.addAll(_getHeaders(isMultipart: true));
      request.fields['user_id'] = userId;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = _handleResponse(response);

      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to reset profile picture: ${e.toString()}');
    }
  }

  // ==================== GALLERY ENDPOINTS ====================

  /// Get user's gallery images
  /// GET /images/gallery
  Future<List<dynamic>> getGallery({
    required String userId,
    bool? favourite,
    bool? archive,
    bool? bin,
  }) async {
    try {
      final queryParams = <String, String>{'user_id': userId};
      if (favourite != null) queryParams['favourite'] = favourite.toString();
      if (archive != null) queryParams['archive'] = archive.toString();
      if (bin != null) queryParams['bin'] = bin.toString();

      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.getGallery}',
      ).replace(queryParameters: queryParams);

      print('Gallery API Request: $uri');
      final response = await _client.get(uri, headers: _getHeaders());
      print('Gallery API Status Code: ${response.statusCode}');
      print('Gallery API Response Body: ${response.body}');

      // Handle empty response
      if (response.body.isEmpty || response.body == '[]') {
        print('Gallery API returned empty response');
        return [];
      }

      final data = _handleResponse(response);
      print('Gallery API Parsed Data Type: ${data.runtimeType}');

      // Ensure we have a list
      if (data == null) {
        print('Gallery API data is null');
        return [];
      }

      if (data is! List) {
        print('Gallery API data is not a list: $data');
        throw ApiException('Expected list but got ${data.runtimeType}');
      }

      print('Gallery API Data Length: ${data.length}');
      return data;
    } catch (e) {
      print('Gallery API Error: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get gallery: ${e.toString()}');
    }
  }

  /// Toggle image status (favourite, archive, bin)
  /// POST /images/{image_id}/toggle/{field}
  Future<bool> toggleImageStatus({
    required String imageId,
    required String userId,
    required String field,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.toggleImageStatus}$imageId/toggle/$field',
      );

      print('Toggle API Request: $uri');
      print('Toggle field: $field for image: $imageId');

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_getHeaders(isMultipart: true));
      request.fields['user_id'] = userId;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Toggle API Status: ${response.statusCode}');
      print('Toggle API Response: ${response.body}');

      // Check for error status codes
      if (response.statusCode >= 400) {
        final errorMsg = response.body.isNotEmpty
            ? response.body
            : 'Server error (${response.statusCode})';
        throw ApiException(errorMsg, response.statusCode);
      }

      final data = _handleResponse(response);

      // Backend may return the full object or just the boolean
      if (data is bool) {
        return data;
      } else if (data is Map<String, dynamic>) {
        // Extract the field value from the returned object
        return data[field] == true || data[field] == 1;
      } else {
        // Fallback: assume toggle succeeded
        print('Toggle succeeded (fallback)');
        return true;
      }
    } catch (e) {
      print('Toggle API Error: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Failed to toggle status: ${e.toString()}');
    }
  }

  /// Get shared gallery with a friend
  /// GET /images/friend/{friend_id}
  Future<List<dynamic>> getSharedGallery({
    required String userId,
    required String friendId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.getSharedGallery}$friendId',
      ).replace(queryParameters: {'user_id': userId});

      print('Shared Gallery API Request: $uri');
      final response = await _client.get(uri, headers: _getHeaders());
      print('Shared Gallery API Status Code: ${response.statusCode}');

      if (response.body.isEmpty || response.body == '[]') {
        print('Shared Gallery returned empty');
        return [];
      }

      final data = _handleResponse(response);

      if (data == null) return [];
      if (data is! List) {
        throw ApiException('Expected list but got ${data.runtimeType}');
      }

      print('Shared Gallery Data Length: ${data.length}');
      return data;
    } catch (e) {
      print('Shared Gallery API Error: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get shared gallery: ${e.toString()}');
    }
  }

  /// Update image description
  /// PATCH /images/{image_id}/description
  Future<Map<String, dynamic>> updateImageDescription({
    required String imageId,
    required String userId,
    required String description,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.updateImageDescription}$imageId/description',
      );
      final request = http.MultipartRequest('PATCH', uri);
      request.headers.addAll(_getHeaders(isMultipart: true));
      request.fields['user_id'] = userId;
      request.fields['description'] = description;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = _handleResponse(response);

      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to update description: ${e.toString()}');
    }
  }

  /// Batch update image status
  /// POST /images/batch/update
  Future<void> batchUpdateStatus({
    required String userId,
    required List<String> imageIds,
    required String field,
    required bool value,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.batchUpdateStatus}',
      );
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({
          'user_id': userId,
          'image_ids': imageIds,
          'field': field,
          'value': value,
        }),
      );

      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to batch update: ${e.toString()}');
    }
  }

  // ==================== CONTACT ENDPOINTS ====================

  /// Add a contact
  /// POST /users/me/contacts
  Future<void> addContact({
    required String userId,
    required String fullName,
    required String phoneNumber,
    String? countryCode,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/users/me/contacts');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_getHeaders(isMultipart: true));
      request.fields['user_id'] = userId;
      request.fields['full_name'] = fullName;
      request.fields['phone_number'] = phoneNumber;
      if (countryCode != null && countryCode.isNotEmpty) {
        request.fields['country_code'] = countryCode;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to add contact: ${e.toString()}');
    }
  }

  /// Get user contacts
  /// GET /users/me/contacts
  Future<List<dynamic>> getContacts({required String userId}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/users/me/contacts',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.get(uri, headers: _getHeaders());
      final data = _handleResponse(response);

      if (data is List) {
        return data;
      } else {
        return [];
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get contacts: ${e.toString()}');
    }
  }

  /// Add contacts in batch
  /// POST /users/me/contacts/batch
  Future<Map<String, dynamic>> addContactsBatch({
    required String userId,
    required List<Map<String, dynamic>> contacts,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/users/me/contacts/batch');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_getHeaders(isMultipart: true));
      request.fields['user_id'] = userId;
      request.fields['contacts'] = json.encode(contacts);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = _handleResponse(response);

      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to add contacts batch: ${e.toString()}');
    }
  }

  // ==================== FRIENDS ENDPOINTS ====================

  /// Get list of all friendships (accepted and pending)
  /// GET /friends
  /// Returns all friendships where user is either requester or receiver
  Future<List<dynamic>> getFriends({required String userId}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.get(uri, headers: _getHeaders());
      final data = _handleResponse(response);
      return data as List<dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get friends: ${e.toString()}');
    }
  }

  /// Search users by username
  /// GET /friends/search
  Future<List<dynamic>> searchUsers({
    required String username,
    required String userId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/search',
      ).replace(queryParameters: {'username': username, 'user_id': userId});

      final response = await _client.get(uri, headers: _getHeaders());
      final data = _handleResponse(response);
      return data as List<dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to search users: ${e.toString()}');
    }
  }

  /// Send friend request
  /// POST /friends/request
  Future<Map<String, dynamic>> sendFriendRequest({
    required String userId,
    required String targetUsername,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/friends/request');
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({'user_id': userId, 'username': targetUsername}),
      );

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to send friend request: ${e.toString()}');
    }
  }

  /// Get pending friend requests (received)
  /// GET /friends/pending
  Future<List<dynamic>> getPendingRequests({required String userId}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/pending',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.get(uri, headers: _getHeaders());
      final data = _handleResponse(response);
      return data as List<dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get pending requests: ${e.toString()}');
    }
  }

  /// Get sent friend requests (pending)
  /// GET /friends/sent
  Future<List<dynamic>> getSentRequests({required String userId}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/sent',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.get(uri, headers: _getHeaders());
      final data = _handleResponse(response);
      return data as List<dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get sent requests: ${e.toString()}');
    }
  }

  /// Accept friend request
  /// POST /friends/{friendship_id}/accept
  Future<Map<String, dynamic>> acceptFriendRequest({
    required String friendshipId,
    required String userId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/$friendshipId/accept',
      );
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({'user_id': userId}),
      );

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to accept friend request: ${e.toString()}');
    }
  }

  /// Reject friend request
  /// POST /friends/{friendship_id}/reject
  Future<Map<String, dynamic>> rejectFriendRequest({
    required String friendshipId,
    required String userId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/$friendshipId/reject',
      );
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({'user_id': userId}),
      );

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to reject friend request: ${e.toString()}');
    }
  }

  // ==================== NOTIFICATIONS ENDPOINTS ====================

  /// Get notifications
  /// GET /notifications
  Future<List<dynamic>> getNotifications({required String userId}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/notifications',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.get(uri, headers: _getHeaders());
      final data = _handleResponse(response);
      return data as List<dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get notifications: ${e.toString()}');
    }
  }

  /// Accept friend request from notification
  /// POST /notifications/{notification_id}/accept
  Future<Map<String, dynamic>> acceptFriendRequestFromNotification({
    required String notificationId,
    required String userId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/notifications/$notificationId/accept',
      );
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({'user_id': userId}),
      );

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to accept friend request: ${e.toString()}');
    }
  }

  /// Reject friend request from notification
  /// POST /notifications/{notification_id}/reject
  Future<Map<String, dynamic>> rejectFriendRequestFromNotification({
    required String notificationId,
    required String userId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/notifications/$notificationId/reject',
      );
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({'user_id': userId}),
      );

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to reject friend request: ${e.toString()}');
    }
  }

  /// Get blocked users
  /// GET /friends/blocked
  Future<List<dynamic>> getBlockedUsers({required String userId}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/blocked',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.get(uri, headers: _getHeaders());
      final data = _handleResponse(response);
      return data as List<dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get blocked users: ${e.toString()}');
    }
  }

  /// Block a user
  /// POST /friends/{friend_id}/block
  Future<Map<String, dynamic>> blockUser({
    required String friendId,
    required String userId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/$friendId/block',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.post(uri, headers: _getHeaders());

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to block user: ${e.toString()}');
    }
  }

  /// Unblock a user
  /// POST /friends/{friend_id}/unblock
  Future<Map<String, dynamic>> unblockUser({
    required String friendId,
    required String userId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/$friendId/unblock',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.post(uri, headers: _getHeaders());

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to unblock user: ${e.toString()}');
    }
  }

  /// Unfriend a user
  /// DELETE /friends/{friend_id}
  Future<Map<String, dynamic>> unfriend({
    required String friendId,
    required String userId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/$friendId',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.delete(uri, headers: _getHeaders());

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to unfriend user: ${e.toString()}');
    }
  }

  /// Update auto clean keep status
  /// PUT /friends/{friend_id}/keep
  Future<Map<String, dynamic>> updateAutoCleanKeep({
    required String friendId,
    required String userId,
    required String keepStatus,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/friends/$friendId/keep')
          .replace(
            queryParameters: {'user_id': userId, 'keep_status': keepStatus},
          );

      final response = await _client.put(uri, headers: _getHeaders());

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to update keep status: ${e.toString()}');
    }
  }

  // ============================================
  // Sharing Endpoints
  // ============================================

  /// Upload images batch
  /// POST /images/upload
  Future<Map<String, dynamic>> uploadImagesBatch({
    required String userId,
    required List<File> images,
    String? description,
  }) async {
    try {
      debugPrint('📤 [ApiClient] POST /images/upload');
      debugPrint('   User ID: $userId');
      debugPrint('   Images: ${images.length}');
      debugPrint('   Description: ${description ?? "(none)"}');

      final uri = Uri.parse('${ApiConstants.baseUrl}/images/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }

      // Add user_id field
      request.fields['user_id'] = userId;

      // Add description if provided
      if (description != null && description.isNotEmpty) {
        request.fields['description'] = description;
      }

      // Add images
      for (var i = 0; i < images.length; i++) {
        final image = images[i];
        final stream = http.ByteStream(image.openRead());
        final length = await image.length();
        debugPrint(
          '   Image ${i + 1}: ${image.path.split('/').last} (${(length / 1024 / 1024).toStringAsFixed(2)} MB)',
        );
        final multipartFile = http.MultipartFile(
          'images',
          stream,
          length,
          filename: image.path.split('/').last,
        );
        request.files.add(multipartFile);
      }

      debugPrint('🔄 [ApiClient] Sending upload request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('✅ [ApiClient] Upload response: ${response.statusCode}');
      debugPrint('   Body: ${response.body}');

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ [ApiClient] Upload error: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Failed to upload images: ${e.toString()}');
    }
  }

  /// Get batch status
  /// GET /images/batch/{batch_id}?user_id={user_id}
  /// Requires user_id for authorization
  Future<Map<String, dynamic>> getBatchStatus({
    required String batchId,
    required String userId, // Added for authorization
  }) async {
    try {
      debugPrint('🔄 [ApiClient] GET /images/batch/$batchId');
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/images/batch/$batchId',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.get(uri, headers: _getHeaders());

      debugPrint('✅ [ApiClient] Batch status response: ${response.statusCode}');
      debugPrint('   Body: ${response.body}');

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ [ApiClient] Batch status error: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get batch status: ${e.toString()}');
    }
  }

  /// Cancel batch upload
  /// DELETE /images/batch/{batch_id}/cancel
  Future<Map<String, dynamic>> cancelBatch({
    required String batchId,
    required String userId,
  }) async {
    try {
      debugPrint('🔄 [ApiClient] DELETE /images/batch/$batchId/cancel');
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/images/batch/$batchId/cancel',
      );
      // Use MultipartRequest for form data
      final request = http.MultipartRequest('DELETE', uri);
      request.headers.addAll(_getHeaders(isMultipart: true));
      request.fields['user_id'] = userId;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('✅ [ApiClient] Cancel batch response: ${response.statusCode}');
      debugPrint('   Body: ${response.body}');

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ [ApiClient] Cancel batch error: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Failed to cancel batch: ${e.toString()}');
    }
  }

  /// Confirm share
  /// POST /images/share/confirm
  /// Requires user_id for authorization
  Future<Map<String, dynamic>> confirmShare({
    required String batchId,
    required String userId,
    required List<String> recipients,
    required bool autoClean,
    Map<String, List<String>>? imageRecipientMap, // Added parameter
  }) async {
    try {
      debugPrint('📤 [ApiClient] POST /images/share/confirm');
      debugPrint('   Batch ID: $batchId');
      debugPrint('   User ID: $userId');
      debugPrint('   Recipients: $recipients');
      debugPrint('   Auto Clean: $autoClean');
      if (imageRecipientMap != null) {
        debugPrint('   Custom Map: ${imageRecipientMap.length} entries');
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/images/share/confirm');
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({
          'batch_id': batchId,
          'user_id': userId,
          'recipients': recipients,
          'auto_clean': autoClean,
          if (imageRecipientMap != null)
            'image_recipient_map': imageRecipientMap, // Added field
        }),
      );

      debugPrint(
        '✅ [ApiClient] Confirm share response: ${response.statusCode}',
      );
      debugPrint('   Body: ${response.body}');

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ [ApiClient] Confirm share error: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Failed to confirm share: ${e.toString()}');
    }
  }

  // ==================== V2 CONTACT DISCOVERY ENDPOINTS ====================

  /// Bulk upload phonebook for contact matching
  /// POST /contacts/sync
  /// Returns on_platform (Prism users) and not_on_platform (invite targets)
  Future<ContactSyncResult> syncContacts({
    required String userId,
    required List<Map<String, String>> contacts,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/contacts/sync');
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({'user_id': userId, 'contacts': contacts}),
      );

      final data = _handleResponse(response);
      return ContactSyncResult.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Contact sync failed: ${e.toString()}');
    }
  }

  /// Fetch latest friend suggestions (cached by backend from last sync)
  /// GET /contacts/recommendations?user_id=...
  Future<ContactSyncResult> getContactRecommendations({
    required String userId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/contacts/recommendations',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.get(uri, headers: _getHeaders());
      final data = _handleResponse(response);
      return ContactSyncResult.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get recommendations: ${e.toString()}');
    }
  }

  /// Check if user has already granted contacts permission
  /// GET /contacts/sync-status?user_id=...
  Future<Map<String, dynamic>> getContactSyncStatus({
    required String userId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/contacts/sync-status',
      ).replace(queryParameters: {'user_id': userId});

      final response = await _client.get(uri, headers: _getHeaders());
      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get sync status: ${e.toString()}');
    }
  }

  /// Update contacts permission state
  /// PATCH /contacts/sync-status
  Future<void> updateContactSyncStatus({
    required String userId,
    required String status, // e.g. 'granted', 'denied'
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/contacts/sync-status');
      final response = await _client.patch(
        uri,
        headers: _getHeaders(),
        body: json.encode({'user_id': userId, 'status': status}),
      );
      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to update sync status: ${e.toString()}');
    }
  }

  // Dispose method to close the client
  void dispose() {
    _client.close();
  }
}
