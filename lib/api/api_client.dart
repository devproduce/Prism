import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
        // If JSON parsing fails, return the raw body
        print('Failed to parse JSON response: ${response.body}');
        throw ApiException('Invalid response format from server');
      }
    } else {
      // Try to parse error response as JSON
      try {
        final errorBody = response.body.isNotEmpty
            ? json.decode(response.body)
            : {'detail': 'Unknown error'};
        final errorMessage =
            errorBody['detail'] ?? errorBody['message'] ?? 'Request failed';
        throw ApiException(errorMessage, response.statusCode);
      } catch (e) {
        // If error response is not JSON, use the raw text
        final errorMessage = response.body.isNotEmpty
            ? response.body
            : 'Request failed with status ${response.statusCode}';
        throw ApiException(errorMessage, response.statusCode);
      }
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
    List<String>? faceIds, // Optional face IDs from multi-view registration
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

      // Add face_ids if provided (multi-view registration)
      if (faceIds != null && faceIds.isNotEmpty) {
        request.fields['face_ids'] = json.encode(faceIds);
        debugPrint('✓ Including ${faceIds.length} face IDs in registration');
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

  // Dispose method to close the client
  void dispose() {
    _client.close();
  }
}
