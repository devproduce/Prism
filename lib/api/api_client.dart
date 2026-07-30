import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:prism/utils/constants.dart';
import 'package:prism/utils/image_file_utils.dart';
import 'package:prism/models/user_model.dart';
import 'package:prism/models/auth_response.dart';
import 'package:prism/models/auth_gate.dart';
import 'package:prism/models/contact_sync_result.dart';
import 'package:prism/models/resolve_username_result.dart';
import 'package:prism/services/token_storage_service.dart';
import 'package:prism/services/auth_session_store.dart';

/// Central auth contract for API requests.
class ApiAuthPolicy {
  /// Production sends JWT Bearer on protected routes.
  static const bool jwtOnly = true;

  /// Live backend still validates user_id on many routes alongside JWT.
  static const bool includeSessionUserId = true;
}

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
  final TokenStorageService _tokenStorage = TokenStorageService.instance;
  String? _authToken;
  bool _legacyAuthMode = false;

  bool _isRefreshing = false;
  bool _logoutInProgress = false;
  final List<Completer<String?>> _refreshWaiters = [];

  /// Called when refresh fails and the user must sign in again.
  VoidCallback? onSessionExpired;

  /// Called when backend returns 403 "Email not verified".
  void Function(AuthGate gate)? onAuthGateRequired;

  /// Called after a successful silent access-token refresh (e.g. re-register FCM).
  VoidCallback? onAccessTokenRefreshed;

  Future<void> saveAuthTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    _authToken = accessToken;
    await _tokenStorage.saveAccessToken(accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _tokenStorage.saveRefreshToken(refreshToken);
    }
  }

  // Set authentication token
  void setAuthToken(String token) {
    _authToken = token;
  }

  void setLegacyAuthMode(bool enabled) {
    _legacyAuthMode = enabled;
  }

  bool get legacyAuthMode => _legacyAuthMode;

  // Clear authentication token
  Future<void> clearAuthToken() async {
    _logoutInProgress = true;
    _authToken = null;
    _completeRefreshWaiters(null);
    _isRefreshing = false;
    await _tokenStorage.clearAll();
    _logoutInProgress = false;
  }

  // Get authentication token
  String? get token => _authToken;

  /// Restore in-memory token from secure storage when the singleton outlives
  /// a process restart or a code hot-reload.
  Future<void> _hydrateAuthTokenIfNeeded() async {
    if (_authToken == null || _authToken!.isEmpty) {
      final stored = await _tokenStorage.getAccessToken();
      if (stored != null && stored.isNotEmpty) {
        _authToken = stored;
      }
    }
    await AuthSessionStore.instance.ensureSessionUserIdHydrated();
  }

  /// Returns true when a JWT is available for protected contact/API calls.
  Future<bool> ensureAuthenticated() async {
    if (_legacyAuthMode) return true;
    await _hydrateAuthTokenIfNeeded();
    return _authToken != null && _authToken!.isNotEmpty;
  }

  void _requireAuthToken({required bool authenticated}) {
    if (!authenticated) return;
    if (ApiAuthPolicy.jwtOnly &&
        !_legacyAuthMode &&
        (_authToken == null || _authToken!.isEmpty)) {
      throw ApiException('Not authenticated. Please log in again.', 401);
    }
  }

  Map<String, String> _authHeaders({
    bool isMultipart = false,
    bool authenticated = true,
  }) {
    _requireAuthToken(authenticated: authenticated);
    return {
      if (!isMultipart) 'Content-Type': 'application/json',
      if (_authToken != null && _authToken!.isNotEmpty)
        'Authorization': 'Bearer $_authToken',
    };
  }

  String? get _sessionUserId => AuthSessionStore.instance.sessionUserId;

  Map<String, String> _userQueryParams([Map<String, String>? extra]) {
    final params = <String, String>{...?extra};
    if (!ApiAuthPolicy.includeSessionUserId) return params;
    final userId = _sessionUserId;
    if (userId != null && userId.isNotEmpty) {
      params.putIfAbsent('user_id', () => userId);
    }
    return params;
  }

  Map<String, dynamic> _userJsonBody(Map<String, dynamic> body) {
    if (!ApiAuthPolicy.includeSessionUserId) return body;
    final userId = _sessionUserId;
    if (userId != null && userId.isNotEmpty) {
      body.putIfAbsent('user_id', () => userId);
    }
    return body;
  }

  void _applyUserIdMultipartField(http.MultipartRequest request) {
    if (!ApiAuthPolicy.includeSessionUserId) return;
    final userId = _sessionUserId;
    if (userId != null && userId.isNotEmpty) {
      request.fields.putIfAbsent('user_id', () => userId);
    }
  }

  void _logAuthDiagnostics(String endpoint, {int? statusCode}) {
    if (!kDebugMode) return;
    final hasJwt = _authToken != null && _authToken!.isNotEmpty;
    final hasUserId = _sessionUserId != null && _sessionUserId!.isNotEmpty;
    debugPrint(
      '[AuthDiag] $endpoint status=${statusCode ?? "?"} '
      'jwt=$hasJwt sessionUserId=$hasUserId',
    );
  }

  void _handle403EmailGate(http.Response response) {
    final message = _extractErrorMessage(response.body, 403).toLowerCase();
    final isEmailGate = message.contains('email not verified') ||
        message.contains('email verification') ||
        message.contains('verify your email');
    if (!isEmailGate) {
      return;
    }

    // Email verification is not enforced after registration (forgot-password
    // reset links only). Still route legacy users without a Firebase account
    // to the migration flow.
    if (AuthSessionStore.instance.hasFirebaseAccount) {
      return;
    }

    AuthSessionStore.instance.setAuthGate(AuthGate.migrateAccount);
    onAuthGateRequired?.call(AuthGate.migrateAccount);
  }

  bool _isTransientRefreshError(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException;
  }

  bool _isTransientRefreshStatus(int statusCode) {
    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
  }

  String? _extractRefreshAccessToken(Map<String, dynamic> data) {
    return AuthResponse.extractAccessToken(data);
  }

  String? _extractRefreshRefreshToken(
    Map<String, dynamic> data,
    String fallback,
  ) {
    return AuthResponse.extractRefreshToken(data) ?? fallback;
  }

  Future<void> _invalidateSessionAfterRefreshFailure() async {
    _completeRefreshWaiters(null);
    await clearAuthToken();
    onSessionExpired?.call();
  }

  /// Attempts silent refresh without logging out on transient network errors.
  Future<String?> trySilentRefresh() => _refreshAccessToken(forceAuthFailure: false);

  Future<String?> _refreshAccessToken({bool forceAuthFailure = false}) async {
    if (_logoutInProgress) {
      _completeRefreshWaiters(null);
      return null;
    }

    if (_isRefreshing) {
      final waiter = Completer<String?>();
      _refreshWaiters.add(waiter);
      return waiter.future;
    }

    _isRefreshing = true;
    try {
      if (_logoutInProgress) {
        _completeRefreshWaiters(null);
        return null;
      }

      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _invalidateSessionAfterRefreshFailure();
        return null;
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refresh}');
      final response = await _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: json.encode({'refresh_token': refreshToken}),
      );

      if (_logoutInProgress) {
        _completeRefreshWaiters(null);
        return null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final accessToken = _extractRefreshAccessToken(data);
        final newRefresh = _extractRefreshRefreshToken(data, refreshToken);
        if (accessToken != null && accessToken.isNotEmpty) {
          await saveAuthTokens(
            accessToken: accessToken,
            refreshToken: newRefresh,
          );
          _completeRefreshWaiters(accessToken);
          onAccessTokenRefreshed?.call();
          return accessToken;
        }
      }

      if (!forceAuthFailure && _isTransientRefreshStatus(response.statusCode)) {
        debugPrint('Token refresh deferred: HTTP ${response.statusCode}');
        _completeRefreshWaiters(null);
        return null;
      }

      await _invalidateSessionAfterRefreshFailure();
      return null;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      if (!forceAuthFailure && _isTransientRefreshError(e)) {
        _completeRefreshWaiters(null);
        return null;
      }
      await _invalidateSessionAfterRefreshFailure();
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  void _completeRefreshWaiters(String? token) {
    for (final waiter in _refreshWaiters) {
      if (!waiter.isCompleted) {
        waiter.complete(token);
      }
    }
    _refreshWaiters.clear();
  }

  Future<void> _ensureAccessTokenForRequest() async {
    await _hydrateAuthTokenIfNeeded();
    if (_authToken != null && _authToken!.isNotEmpty) return;

    final refreshed = await _refreshAccessToken();
    if (refreshed != null && refreshed.isNotEmpty) return;

    final hasRefresh = await _tokenStorage.hasRefreshToken();
    if (hasRefresh) {
      throw ApiException(
        'Unable to refresh your session. Check your connection and try again.',
        503,
      );
    }
    throw ApiException('Not authenticated. Please log in again.', 401);
  }

  Future<http.Response> _withAuthRetry(
    Future<http.Response> Function() send, {
    bool authenticated = true,
  }) async {
    if (authenticated && !_legacyAuthMode) {
      await _ensureAccessTokenForRequest();
    }

    var response = await send();

    if (response.statusCode == 429) {
      throw ApiException(
        _extractErrorMessage(response.body, 429),
        429,
      );
    }

    if (response.statusCode == 403) {
      _handle403EmailGate(response);
    }

    if (_legacyAuthMode || !authenticated || response.statusCode != 401) {
      return response;
    }

    final newToken = await _refreshAccessToken(forceAuthFailure: true);
    if (newToken == null) {
      final hasRefresh = await _tokenStorage.hasRefreshToken();
      if (hasRefresh) {
        throw ApiException(
          'Unable to refresh your session. Check your connection and try again.',
          503,
        );
      }
      throw ApiException(
        'Your session has expired. Please log in again.',
        401,
      );
    }

    return send();
  }

  Future<http.Response> _get(
    Uri uri, {
    bool authenticated = true,
  }) {
    return _withAuthRetry(
      () => _client.get(uri, headers: _authHeaders(authenticated: authenticated)),
      authenticated: authenticated,
    );
  }

  Future<http.Response> _post(
    Uri uri, {
    Object? body,
    bool authenticated = true,
  }) {
    return _withAuthRetry(
      () => _client.post(uri, headers: _authHeaders(authenticated: authenticated), body: body),
      authenticated: authenticated,
    );
  }

  Future<http.Response> _delete(
    Uri uri, {
    Object? body,
    bool authenticated = true,
  }) {
    return _withAuthRetry(
      () => _client.delete(uri, headers: _authHeaders(authenticated: authenticated), body: body),
      authenticated: authenticated,
    );
  }

  Future<http.Response> _put(
    Uri uri, {
    Object? body,
    bool authenticated = true,
  }) {
    return _withAuthRetry(
      () => _client.put(uri, headers: _authHeaders(authenticated: authenticated), body: body),
      authenticated: authenticated,
    );
  }

  Future<http.Response> _patch(
    Uri uri, {
    Object? body,
    bool authenticated = true,
  }) {
    return _withAuthRetry(
      () => _client.patch(uri, headers: _authHeaders(authenticated: authenticated), body: body),
      authenticated: authenticated,
    );
  }

  Future<http.Response> _sendMultipart(
    Future<http.MultipartRequest> Function() buildRequest, {
    bool authenticated = true,
  }) {
    return _withAuthRetry(() async {
      final request = await buildRequest();
      _applyUserIdMultipartField(request);
      request.headers.addAll(
        _authHeaders(isMultipart: true, authenticated: authenticated),
      );
      final streamedResponse = await request.send();
      return http.Response.fromStream(streamedResponse);
    }, authenticated: authenticated);
  }

  // Handle API response
  dynamic _handleResponse(http.Response response, {String? endpoint}) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return json.decode(response.body);
      } catch (e) {
        print('Failed to parse JSON response: ${response.body}');
        throw ApiException('Invalid response format from server');
      }
    } else {
      if (endpoint != null &&
          (response.statusCode == 401 || response.statusCode == 422)) {
        _logAuthDiagnostics(endpoint, statusCode: response.statusCode);
      }
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
          if (value == null) continue;
          if (value is List) {
            final parts = value.map((item) {
              if (item is Map) {
                final field = (item['loc'] as List?)?.last?.toString();
                final msg = item['msg']?.toString();
                if (field != null && msg != null) return '$field: $msg';
                return msg ?? item.toString();
              }
              return item.toString();
            });
            final joined = parts.where((p) => p.isNotEmpty).join('; ');
            if (joined.isNotEmpty) return joined;
          }
          if (value.toString().isNotEmpty) {
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

  /// Backend responses may be a raw JSON array or an object wrapping the array.
  List<dynamic> _coerceToList(
    dynamic data, {
    List<String> listKeys = const [
      'images',
      'gallery',
      'gallery_items',
      'items',
      'data',
      'results',
      'notifications',
      'contacts',
      'friends',
    ],
  }) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map) {
      for (final key in listKeys) {
        final value = data[key];
        if (value is List) return value;
      }
    }
    throw ApiException('Expected list but got ${data.runtimeType}');
  }

  // ==================== AUTH ENDPOINTS ====================

  /// Check if username is available
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/auth/check-availability',
      ).replace(
        queryParameters: {'type': 'username', 'value': username},
      );
      final response = await _get(uri, authenticated: false);
      
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

  /// Register device token for FCM (production backend contract).
  Future<void> registerDeviceToken({
    required String userId,
    required String fcmToken,
    required String deviceId,
    required String platform,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/notifications/device/register');
      final response = await _post(
        uri,
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

  /// Register a new user.
  /// POST /auth/register (multipart)
  /// Required: username, password, email, country_code, phone_number, face_ids
  Future<AuthResponse> register({
    required String username,
    required String password,
    required String email,
    required String countryCode,
    required String phoneNumber,
    String? firstName,
    String? lastName,
    File? profileImage,
    List<String>? faceIds,
    String? firebaseToken,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}');
      final request = http.MultipartRequest('POST', uri);

      request.fields['username'] = username;
      request.fields['password'] = password;
      request.fields['email'] = email.trim();
      request.fields['country_code'] = countryCode.replaceAll('+', '').trim();
      request.fields['phone_number'] =
          phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (firebaseToken != null && firebaseToken.isNotEmpty) {
        request.fields['firebase_token'] = firebaseToken;
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

      // Multi-view: backend links face_ids; send tiny placeholder for required image field.
      final Uint8List imageBytes;
      if (faceIds != null && faceIds.isNotEmpty) {
        imageBytes = ImageFileUtils.placeholderJpeg;
        debugPrint('✓ Using placeholder image for multi-view registration');
      } else if (profileImage != null) {
        imageBytes = await ImageFileUtils.readAsJpegBytes(profileImage);
      } else {
        imageBytes = ImageFileUtils.placeholderJpeg;
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'profile.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      debugPrint(
        '✓ Including profile image in registration (${imageBytes.length} bytes JPEG)',
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '❌ Register failed: HTTP ${response.statusCode} body=${response.body}',
        );
      }
      final data = _handleResponse(response);

      final authResponse = AuthResponse.fromJson(data);
      await _persistAuthResponse(authResponse);
      return authResponse;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Registration failed: ${e.toString()}');
    }
  }

  Future<void> _persistAuthResponse(AuthResponse response) async {
    final accessToken = response.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      await saveAuthTokens(
        accessToken: accessToken,
        refreshToken: response.refreshToken,
      );
    }
  }

  /// Standard login — POST /auth/login (JSON: identifier + password).
  /// May return needs_migration for legacy accounts (no tokens persisted yet).
  Future<AuthResponse> login({
    required String identifier, // Changed from 'email' to 'identifier'
    required String password,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}');
      final response = await _post(
        uri,
        body: json.encode({
          'identifier': identifier,
          'password': password,
        }),
        authenticated: false,
      );

      if (response.statusCode >= 400) {
        // Release builds strip debugPrint — use print so 500 bodies are visible.
        // Captured evidence (2026-07): status=500, content-type=text/plain,
        // body="Internal Server Error" (password accepted, post-auth crash).
        print(
          '[Login] POST /auth/login status=${response.statusCode} '
          'content-type=${response.headers['content-type']} '
          'body=${response.body}',
        );
      }

      final data = _handleResponse(response) as Map<String, dynamic>;
      final authResponse = AuthResponse.fromJson(data);
      if (authResponse.needsMigration == true) {
        return authResponse;
      }
      await _persistAuthResponse(authResponse);
      return authResponse;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Login failed: ${e.toString()}');
    }
  }

  /// Verify password for archive unlock
  /// POST /auth/verify-password
  Future<bool> verifyPassword({required String password}) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/auth/verify-password');
      final response = await _sendMultipart(() async {
        final request = http.MultipartRequest('POST', uri);
        request.fields['password'] = password;
        return request;
      });
      final data = _handleResponse(response);

      return data['valid'] == true;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Password verification failed: ${e.toString()}');
    }
  }

  /// Set password for Google-only users (one-time).
  /// PATCH /auth/set-password
  /// Throws [ApiException] with statusCode 400 when password is already set.
  Future<void> setPassword(String password) async {
    try {
      final uri =
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.setPassword}');
      debugPrint('[SetPassword] PATCH $uri');
      final response = await _patch(
        uri,
        body: json.encode({'password': password}),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw ApiException(
            'Request timed out. Check your connection and try again.',
            408,
          );
        },
      );
      debugPrint(
        '[SetPassword] status=${response.statusCode} body=${response.body}',
      );
      _handleResponse(response);
    } catch (e) {
      debugPrint('[SetPassword] error: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Failed to set password: ${e.toString()}');
    }
  }

  /// Forgot password — accepts username or email.
  /// POST /auth/forgot-password
  Future<String?> forgotPassword(String identifier) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.forgotPassword}');
      final response = await _sendMultipart(() async {
        final request = http.MultipartRequest('POST', uri);
        request.fields['identifier'] = identifier;
        return request;
      }, authenticated: false);

      final data = _handleResponse(response);
      if (data is Map<String, dynamic>) {
        return data['email'] as String?;
      }
      return null;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to send reset link: ${e.toString()}');
    }
  }

  /// Delete account — requires Firebase re-authentication token.
  /// DELETE /auth/delete-account
  Future<void> deleteAccount({
    required String firebaseToken,
    required String reason,
    String? feedback,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deleteAccount}');
      final response = await _delete(
        uri,
        body: json.encode({
          'firebase_token': firebaseToken,
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

  /// POST /auth/cancel-deletion
  Future<void> cancelDeletion({required String firebaseToken}) async {
    try {
      final uri =
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.cancelDeletion}');
      final response = await _post(
        uri,
        body: json.encode({'firebase_token': firebaseToken}),
      );
      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to cancel account deletion: ${e.toString()}');
    }
  }

  /// Resolve username to determine login path.
  /// POST /auth/resolve-username
  Future<ResolveUsernameResult> resolveUsername(String username) async {
    try {
      final uri =
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.resolveUsername}');
      final response = await _post(
        uri,
        body: json.encode({'username': username.trim()}),
        authenticated: false,
      );
      final data = _handleResponse(response) as Map<String, dynamic>;
      return ResolveUsernameResult.fromJson(data);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to resolve username: ${e.toString()}');
    }
  }

  /// Exchange Firebase ID token for backend JWT pair.
  /// POST /auth/login/verify (multipart form: id_token)
  Future<AuthResponse> loginVerify({required String idToken}) async {
    try {
      if (idToken.trim().isEmpty) {
        throw ApiException('Firebase id_token is missing. Please try again.');
      }
      final uri =
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.loginVerify}');
      final request = http.MultipartRequest('POST', uri);
      request.fields['id_token'] = idToken;
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode >= 400) {
        print(
          '[Login] POST /auth/login/verify status=${response.statusCode} '
          'content-type=${response.headers['content-type']} '
          'body=${response.body}',
        );
      }
      final data = _handleResponse(response);
      if (kDebugMode && data is Map<String, dynamic>) {
        debugPrint('loginVerify response keys: ${data.keys.toList()}');
      }
      final authResponse = AuthResponse.fromJson(data as Map<String, dynamic>);
      await _persistAuthResponse(authResponse);
      return authResponse;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Login verification failed: ${e.toString()}');
    }
  }

  /// Legacy account migration via email verification.
  /// POST /auth/verify-legacy-email
  Future<AuthResponse> verifyLegacyEmail({
    required String migrationToken,
    required String email,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.verifyLegacyEmail}',
      );
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $migrationToken',
        },
        body: json.encode({'email': email.trim()}),
      );

      final data = _handleResponse(response);
      final authResponse =
          AuthResponse.fromJson(data as Map<String, dynamic>);
      await _persistAuthResponse(authResponse);
      return authResponse;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Account migration failed: ${e.toString()}');
    }
  }

  /// POST /auth/resend-verification
  Future<void> resendVerificationEmail() async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.resendVerification}',
      );
      final response = await _post(uri);
      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to resend verification email: ${e.toString()}');
    }
  }

  /// POST /auth/google-login (multipart form: id_token)
  Future<AuthResponse> googleLogin({required String idToken}) async {
    try {
      if (idToken.trim().isEmpty) {
        throw ApiException('Google id_token is missing. Please try again.');
      }
      final uri =
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.googleLogin}');
      final request = http.MultipartRequest('POST', uri);
      request.fields['id_token'] = idToken;
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = _handleResponse(response);
      final authResponse = AuthResponse.fromJson(data as Map<String, dynamic>);
      if (authResponse.exists != false) {
        await _persistAuthResponse(authResponse);
      }
      return authResponse;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Google login failed: ${e.toString()}');
    }
  }

  /// POST /auth/google-register
  Future<AuthResponse> googleRegister({
    required String idToken,
    required String username,
    List<String>? faceIds,
    File? profileImage,
  }) async {
    try {
      final uri =
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.googleRegister}');
      final request = http.MultipartRequest('POST', uri);
      request.fields['id_token'] = idToken;
      request.fields['username'] = username;
      if (faceIds != null && faceIds.isNotEmpty) {
        request.fields['face_ids'] = json.encode(faceIds);
      }
      if (profileImage != null) {
        final jpegBytes = await ImageFileUtils.readAsJpegBytes(profileImage);
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            jpegBytes,
            filename: 'profile.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = _handleResponse(response);
      final authResponse = AuthResponse.fromJson(data);
      await _persistAuthResponse(authResponse);
      return authResponse;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Google registration failed: ${e.toString()}');
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

      final response = await _get(uri, authenticated: false);
      final data = _handleResponse(response);
      return data['available'] == true;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to check availability: ${e.toString()}');
    }
  }

  // ==================== USER ENDPOINTS ====================

  /// Get current user details
  /// GET /users/me
  Future<UserModel> getCurrentUser([String? userId]) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.getCurrentUser}',
      ).replace(queryParameters: _userQueryParams());

      final response = await _get(uri);
      final data = _handleResponse(response, endpoint: 'GET /users/me');

      return UserModel.fromApiResponse(data);
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

      final response = await _get(uri);
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
      final response = await _sendMultipart(() async {
        final request = http.MultipartRequest('PUT', uri);
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
        return request;
      });
      final data = _handleResponse(response);

      return UserModel.fromApiResponse(data);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to update profile: ${e.toString()}');
    }
  }

  /// Upload/Update profile picture
  /// PUT /users/me/profile-picture
  Future<UserModel> uploadProfilePicture({required File profileImage}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.uploadProfilePicture}',
      );
      final response = await _sendMultipart(() async {
        final request = http.MultipartRequest('POST', uri);
        final jpegBytes = await ImageFileUtils.readAsJpegBytes(profileImage);
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            jpegBytes,
            filename: 'profile.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
        return request;
      });
      final data = _handleResponse(response);

      return UserModel.fromApiResponse(data);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to upload profile picture: ${e.toString()}');
    }
  }

  /// Reset profile picture to default avatar
  /// DELETE /users/me/profile-picture
  Future<Map<String, dynamic>> resetProfilePicture() async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/users/me/profile-picture');
      final response = await _sendMultipart(() async {
        final request = http.MultipartRequest('DELETE', uri);
        return request;
      });
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
    bool? favourite,
    bool? archive,
    bool? bin,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (favourite != null) queryParams['favourite'] = favourite.toString();
      if (archive != null) queryParams['archive'] = archive.toString();
      if (bin != null) queryParams['bin'] = bin.toString();

      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.getGallery}',
      ).replace(queryParameters: _userQueryParams(queryParams));

      print('Gallery API Request: $uri');
      final response = await _get(uri);
      print('Gallery API Status Code: ${response.statusCode}');
      print('Gallery API Response Body: ${response.body}');

      // Handle empty response
      if (response.body.isEmpty || response.body == '[]') {
        print('Gallery API returned empty response');
        return [];
      }

      final data = _handleResponse(response);
      print('Gallery API Parsed Data Type: ${data.runtimeType}');

      final list = _coerceToList(
        data,
        listKeys: const ['images', 'gallery', 'gallery_items', 'items', 'data'],
      );
      print('Gallery API Data Length: ${list.length}');
      return list;
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
    required String field,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.toggleImageStatus}$imageId/toggle/$field',
      );

      print('Toggle API Request: $uri');
      print('Toggle field: $field for image: $imageId');

      final response = await _sendMultipart(() async {
        final request = http.MultipartRequest('POST', uri);
        return request;
      });

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
  Future<List<dynamic>> getSharedGallery({required String friendId}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.getSharedGallery}$friendId',
      ).replace(queryParameters: _userQueryParams());

      print('Shared Gallery API Request: $uri');
      final response = await _get(uri);
      print('Shared Gallery API Status Code: ${response.statusCode}');

      if (response.body.isEmpty || response.body == '[]') {
        print('Shared Gallery returned empty');
        return [];
      }

      final data = _handleResponse(response);

      return _coerceToList(
        data,
        listKeys: const ['images', 'gallery', 'gallery_items', 'items', 'data'],
      );
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
    required String description,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.updateImageDescription}$imageId/description',
      );
      final response = await _sendMultipart(() async {
        final request = http.MultipartRequest('PATCH', uri);
        request.fields['description'] = description;
        return request;
      });
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
    required List<String> imageIds,
    required String field,
    required bool value,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.batchUpdateStatus}',
      );
      final response = await _post(
        uri,
        body: json.encode(_userJsonBody({
          'image_ids': imageIds,
          'field': field,
          'value': value,
        })),
      );

      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to batch update: ${e.toString()}');
    }
  }

  // ==================== FRIENDS ENDPOINTS ====================

  /// Get list of all friendships (accepted and pending)
  /// GET /friends
  /// Returns all friendships where user is either requester or receiver
  Future<List<dynamic>> getFriends() async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends',
      ).replace(queryParameters: _userQueryParams());

      final response = await _get(uri);
      final data = _handleResponse(response);
      return _coerceToList(
        data,
        listKeys: const ['friends', 'friendships', 'items', 'data'],
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get friends: ${e.toString()}');
    }
  }

  /// Search users by username
  /// GET /friends/search
  Future<List<dynamic>> searchUsers({required String username}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/search',
      ).replace(
        queryParameters: _userQueryParams({'username': username}),
      );

      final response = await _get(uri);
      final data = _handleResponse(response);
      return _coerceToList(
        data,
        listKeys: const ['users', 'results', 'items', 'data'],
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to search users: ${e.toString()}');
    }
  }

  /// Send friend request
  /// POST /friends/request
  Future<Map<String, dynamic>> sendFriendRequest({
    required String targetUsername,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/friends/request');
      final response = await _post(
        uri,
        body: json.encode(_userJsonBody({
          'username': targetUsername,
        })),
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
  Future<List<dynamic>> getPendingRequests() async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/pending',
      ).replace(queryParameters: _userQueryParams());

      final response = await _get(uri);
      final data = _handleResponse(response);
      return _coerceToList(
        data,
        listKeys: const ['requests', 'pending', 'items', 'data'],
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get pending requests: ${e.toString()}');
    }
  }

  /// Get sent friend requests (pending)
  /// GET /friends/sent
  Future<List<dynamic>> getSentRequests() async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/sent',
      ).replace(queryParameters: _userQueryParams());

      final response = await _get(uri);
      final data = _handleResponse(response);
      return _coerceToList(
        data,
        listKeys: const ['requests', 'sent', 'items', 'data'],
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get sent requests: ${e.toString()}');
    }
  }

  /// Accept friend request
  /// POST /friends/{friendship_id}/accept
  Future<Map<String, dynamic>> acceptFriendRequest({required String friendshipId}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/$friendshipId/accept',
      );
      final response = await _post(
        uri,
        body: json.encode(_userJsonBody({})),
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
  Future<Map<String, dynamic>> rejectFriendRequest({required String friendshipId}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/$friendshipId/reject',
      );
      final response = await _post(
        uri,
        body: json.encode(_userJsonBody({})),
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
  Future<List<dynamic>> getNotifications() async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/notifications',
      ).replace(queryParameters: _userQueryParams());

      final response = await _get(uri);
      final data = _handleResponse(response);
      return _coerceToList(
        data,
        listKeys: const ['notifications', 'items', 'data'],
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get notifications: ${e.toString()}');
    }
  }

  /// Get blocked users
  /// GET /friends/blocked
  Future<List<dynamic>> getBlockedUsers() async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/blocked',
      ).replace(queryParameters: _userQueryParams());

      final response = await _get(uri);
      final data = _handleResponse(response);
      return _coerceToList(
        data,
        listKeys: const ['blocked', 'users', 'items', 'data'],
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get blocked users: ${e.toString()}');
    }
  }

  /// Block a user
  /// POST /friends/{friend_id}/block
  Future<Map<String, dynamic>> blockUser({required String friendId}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/$friendId/block',
      );

      final response = await _post(
        uri,
        body: json.encode(_userJsonBody({})),
      );

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to block user: ${e.toString()}');
    }
  }

  /// Unblock a user
  /// POST /friends/{friend_id}/unblock
  Future<Map<String, dynamic>> unblockUser({required String friendId}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/$friendId/unblock',
      );

      final response = await _post(
        uri,
        body: json.encode(_userJsonBody({})),
      );

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to unblock user: ${e.toString()}');
    }
  }

  /// Unfriend a user
  /// DELETE /friends/{friend_id}
  Future<Map<String, dynamic>> unfriend({required String friendId}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/friends/$friendId',
      ).replace(queryParameters: _userQueryParams());

      final response = await _delete(uri);

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
    required String keepStatus,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/friends/$friendId/keep');

      final response = await _put(
        uri,
        body: json.encode(
          _userJsonBody({'keep_status': keepStatus}),
        ),
      );

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
    required List<File> images,
    String? description,
  }) async {
    try {
      debugPrint('📤 [ApiClient] POST /images/upload');
      debugPrint('   Images: ${images.length}');
      debugPrint('   Description: ${description ?? "(none)"}');

      final uri = Uri.parse('${ApiConstants.baseUrl}/images/upload');
      final response = await _sendMultipart(() async {
        final request = http.MultipartRequest('POST', uri);
        if (description != null && description.isNotEmpty) {
          request.fields['description'] = description;
        }

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
        return request;
      });

      debugPrint('🔄 [ApiClient] Sending upload request...');

      debugPrint('✅ [ApiClient] Upload response: ${response.statusCode}');
      _logExactBackendJson('POST /images/upload', response.body);

      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ [ApiClient] Upload error: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Failed to upload images: ${e.toString()}');
    }
  }

  /// Get batch status
  /// GET /images/batch/{batch_id}
  Future<Map<String, dynamic>> getBatchStatus({required String batchId}) async {
    try {
      debugPrint('🔄 [ApiClient] GET /images/batch/$batchId');
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/images/batch/$batchId',
      ).replace(queryParameters: _userQueryParams());

      final response = await _get(uri);

      debugPrint('✅ [ApiClient] Batch status response: ${response.statusCode}');
      _logExactBackendJson('GET /images/batch/$batchId', response.body);

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
  Future<Map<String, dynamic>> cancelBatch({required String batchId}) async {
    try {
      debugPrint('🔄 [ApiClient] DELETE /images/batch/$batchId/cancel');
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/images/batch/$batchId/cancel',
      );
      final response = await _sendMultipart(() async {
        return http.MultipartRequest('DELETE', uri);
      });

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
  Future<Map<String, dynamic>> confirmShare({
    required String batchId,
    required List<String> recipients,
    required bool autoClean,
    Map<String, List<String>>? imageRecipientMap, // Added parameter
  }) async {
    try {
      debugPrint('📤 [ApiClient] POST /images/share/confirm');
      debugPrint('   Batch ID: $batchId');
      debugPrint('   Recipients: $recipients');
      debugPrint('   Auto Clean: $autoClean');
      if (imageRecipientMap != null) {
        debugPrint('   Custom Map: ${imageRecipientMap.length} entries');
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/images/share/confirm');
      final response = await _post(
        uri,
        body: json.encode(_userJsonBody({
          'batch_id': batchId,
          'recipients': recipients,
          'auto_clean': autoClean,
          if (imageRecipientMap != null)
            'image_recipient_map': imageRecipientMap,
        })),
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
    required List<Map<String, String>> contacts,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/contacts/sync');
      final response = await _post(
        uri,
        body: json.encode(_userJsonBody({
          'contacts': contacts,
        })),
      );

      final data = _handleResponse(response);
      return ContactSyncResult.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Contact sync failed: ${e.toString()}');
    }
  }

  /// Fetch latest friend suggestions (cached by backend from last sync)
  /// GET /contacts/recommendations
  Future<ContactSyncResult> getContactRecommendations() async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/contacts/recommendations',
      ).replace(queryParameters: _userQueryParams());

      final response = await _get(uri);
      final data = _handleResponse(response);
      return ContactSyncResult.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get recommendations: ${e.toString()}');
    }
  }

  /// Dismiss a "People You May Know" suggestion permanently
  /// POST /contacts/recommendations/dismiss
  Future<void> dismissRecommendation({
    required String dismissedUserId,
  }) async {
    try {
      final uri =
          Uri.parse('${ApiConstants.baseUrl}/contacts/recommendations/dismiss');
      final response = await _post(
        uri,
        body: json.encode(_userJsonBody({
          'dismissed_user_id': dismissedUserId,
        })),
      );
      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to dismiss recommendation: ${e.toString()}');
    }
  }

  /// Link historical photo matches when two users become friends
  /// POST /friends/retroactive-share/accept
  Future<Map<String, dynamic>> acceptRetroactiveShare({
    required String friendId,
    required List<String> contactFaceIds,
    required List<String> unknownFaceIds,
    required List<String> imageIds,
  }) async {
    try {
      final uri =
          Uri.parse('${ApiConstants.baseUrl}/friends/retroactive-share/accept');
      final response = await _post(
        uri,
        body: json.encode(_userJsonBody({
          'friend_id': friendId,
          'contact_face_ids': contactFaceIds,
          'unknown_face_ids': unknownFaceIds,
          'image_ids': imageIds,
        })),
      );
      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to accept retroactive share: ${e.toString()}');
    }
  }

  /// Mark all notifications as read
  /// POST /notifications/mark-read
  Future<void> markNotificationsRead() async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/notifications/mark-read',
      );
      final response = await _post(
        uri,
        body: json.encode(_userJsonBody({})),
      );
      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to mark notifications read: ${e.toString()}');
    }
  }

  /// Mark a single notification as read
  /// POST /notifications/{notification_id}/mark-read
  Future<void> markNotificationReadSingle({required String notificationId}) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/notifications/$notificationId/mark-read',
      );
      final response = await _post(
        uri,
        body: json.encode(_userJsonBody({})),
      );
      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to mark notification read: ${e.toString()}');
    }
  }

  /// Check if user has already granted contacts permission
  /// GET /contacts/sync-status
  Future<Map<String, dynamic>> getContactSyncStatus() async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/contacts/sync-status',
      ).replace(queryParameters: _userQueryParams());

      final response = await _get(uri);
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
    required String permissionStatus, // e.g. 'granted', 'denied'
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/contacts/sync-status');
      final response = await _patch(
        uri,
        body: json.encode(_userJsonBody({
          'permission_status': permissionStatus,
        })),
      );
      _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to update sync status: ${e.toString()}');
    }
  }

  /// Logs the exact backend JSON without [debugPrint] line truncation.
  void _logExactBackendJson(String label, String body) {
    if (!kDebugMode) return;

    debugPrint('┌─── BACKEND JSON: $label ───');
    try {
      final decoded = jsonDecode(body);
      const encoder = JsonEncoder.withIndent('  ');
      final pretty = encoder.convert(decoded);
      const chunkSize = 900;
      for (var i = 0; i < pretty.length; i += chunkSize) {
        final end = i + chunkSize < pretty.length ? i + chunkSize : pretty.length;
        debugPrint(pretty.substring(i, end));
      }
    } catch (e) {
      debugPrint('(could not parse as JSON: $e)');
      const chunkSize = 900;
      for (var i = 0; i < body.length; i += chunkSize) {
        final end = i + chunkSize < body.length ? i + chunkSize : body.length;
        debugPrint(body.substring(i, end));
      }
    }
    debugPrint('└─── END BACKEND JSON: $label ───');
  }

  // Dispose method to close the client
  void dispose() {
    _client.close();
  }
}
