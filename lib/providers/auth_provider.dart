import 'dart:io';
import 'package:flutter/material.dart';
import 'package:prism/utils/constants.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/user_model.dart';
import 'package:prism/services/database_service.dart';
import 'package:prism/services/contact_service.dart';
import 'package:prism/providers/profile_provider.dart';
import 'package:prism/services/notification_service.dart';

// SharedPreferences keys for native Android access
// These must match the keys used in BackgroundShareService.kt
const String kPrefAuthToken = 'prism_auth_token';
const String kPrefUserId = 'prism_user_id';
const String kPrefBaseUrl = 'prism_base_url';

class AuthProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final DatabaseService _databaseService = DatabaseService.instance;
  final ContactService _contactService = ContactService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  bool _contactsSynced = false;

  bool _phoneSyncWarning = false;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  bool get contactsSynced => _contactsSynced;
  /// True when the backend could not normalize the phone number on registration.
  bool get phoneSyncWarning => _phoneSyncWarning;
  ApiClient get apiClient => _apiClient;
  String? get token => _apiClient.token;

  // Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Set error
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Initialize authentication state from database
  Future<void> initializeAuth() async {
    try {
      final isLoggedIn = await _databaseService.isUserLoggedIn();
      if (isLoggedIn) {
        final user = await _databaseService.getUserSession();
        if (user != null) {
          _currentUser = user;
          _isAuthenticated = true;
          _contactsSynced = await _databaseService.hasContactsSynced();

          // Restore auth token from SharedPreferences
          // This was saved during login and needs to be restored for API calls
          final prefs = await SharedPreferences.getInstance();
          final savedToken = prefs.getString(kPrefAuthToken);
          if (savedToken != null && savedToken.isNotEmpty) {
            _apiClient.setAuthToken(savedToken);
            debugPrint('✅ Restored auth token from SharedPreferences');
          } else {
            debugPrint('⚠️ No saved auth token found in SharedPreferences');
          }

          // Ensure credentials are in SharedPreferences for native Android share receiver
          await _saveCredentialsForNativeAccess();

          // Register FCM token
          NotificationService.registerDeviceToken(user.userId);

          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Failed to initialize auth: $e');
    }
  }

  /// Register a new user (V2 — phone-first)
  Future<bool> register({
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
      _setLoading(true);
      _setError(null);
      _phoneSyncWarning = false;

      final response = await _apiClient.register(
        username: username,
        password: password,
        countryCode: countryCode,
        phoneNumber: phoneNumber,
        email: email,
        firstName: firstName,
        lastName: lastName,
        profileImage: profileImage,
        faceIds: faceIds,
      );

      _currentUser = response.user;
      final token = response.token;

      // Check phone_synced flag
      if (response.phoneSynced == false) {
        _phoneSyncWarning = true;
        debugPrint('⚠️ phone_synced=false: phone number could not be verified');
      }

      debugPrint(
        'Registration Response - UserID: "${_currentUser?.userId}", Token: "${token ?? 'null'}"',
      );

      // FAILSAFE: If registration response didn't return a valid userId OR a valid token,
      // try to login automatically using the phone number.
      bool needsAutoLogin = _currentUser?.userId.isEmpty ?? true;
      if (!needsAutoLogin && (token == null || token.isEmpty)) {
        debugPrint(
          '⚠️ Registration successful but NO TOKEN returned. Forcing auto-login.',
        );
        needsAutoLogin = true;
      }

      if (needsAutoLogin) {
        debugPrint('🔄 Initiating Auto-Login Sequence...');
        
        // Save the full registration user data before login potentially wipes it
        final registeredUser = _currentUser;
        
        // Try login with username (phone login not yet supported on login endpoint)
        final loginSuccess = await login(identifier: username, password: password);
        
        // If login succeeded but wiped our data (e.g. getCurrentUser failed), restore it!
        if (loginSuccess && registeredUser != null) {
           _currentUser = _currentUser?.copyWith(
             firstName: (_currentUser?.firstName.isEmpty ?? true) ? registeredUser.firstName : null,
             lastName: _currentUser?.lastName ?? registeredUser.lastName,
             phoneNumber: _currentUser?.phoneNumber ?? registeredUser.phoneNumber,
             countryCode: _currentUser?.countryCode ?? registeredUser.countryCode,
             email: (_currentUser?.email.isEmpty ?? true) ? registeredUser.email : null,
             // In case username also got wiped somehow
             username: (_currentUser?.username.isEmpty ?? true) ? registeredUser.username : null,
           ) ?? registeredUser;
           
           // Ensure the database has the merged data
           await _databaseService.updateUserSession(_currentUser!);
        }
        
        return loginSuccess;
      }

      _isAuthenticated = true;

      // Set auth token in ApiClient if provided by backend
      if (token != null && token.isNotEmpty) {
        _apiClient.setAuthToken(token);
        debugPrint('✅ Auth token set from register response');
      }

      // Save user session to database
      await _databaseService.saveUserSession(response.user);

      // Save credentials to SharedPreferences for native Android access
      await _saveCredentialsForNativeAccess();

      // Fetch fresh profile from backend to ensure latest data
      try {
        final freshUser = await _apiClient.getCurrentUser(response.user.userId);
        _currentUser = freshUser;
        await _databaseService.updateUserSession(freshUser);
      } catch (e) {
        debugPrint('Warning: Could not fetch fresh profile: $e');
      }

      // Register FCM token
      NotificationService.registerDeviceToken(response.user.userId);

      _setLoading(false);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(ErrorHandler.getErrorMessage(e));
      _setLoading(false);
      return false;
    }
  }


  /// Login user
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _apiClient.login(
        identifier: identifier,
        password: password,
      );

      _currentUser = response.user;
      _isAuthenticated = true;

      // Set auth token in ApiClient if provided by backend
      if (response.token != null && response.token!.isNotEmpty) {
        _apiClient.setAuthToken(response.token!);
        debugPrint('✅ Auth token set from login response');
      } else {
        debugPrint('⚠️ No auth token in login response');
      }

      // Save user session to database
      await _databaseService.saveUserSession(response.user);

      // Save credentials to SharedPreferences for native Android access
      await _saveCredentialsForNativeAccess();

      // Fetch fresh profile from backend to ensure latest data
      try {
        final freshUser = await _apiClient.getCurrentUser(response.user.userId);
        _currentUser = freshUser;
        await _databaseService.updateUserSession(freshUser);
      } catch (e) {
        debugPrint('Warning: Could not fetch fresh profile: $e');
        // Continue with login even if profile fetch fails
      }

      // Check if contacts have been synced
      _contactsSynced = await _databaseService.hasContactsSynced();

      // Register FCM token
      NotificationService.registerDeviceToken(response.user.userId);

      _setLoading(false);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(ErrorHandler.getErrorMessage(e));
      _setLoading(false);
      return false;
    }
  }

  /// Verify password for archive unlock
  /// Returns true if password is valid
  Future<bool> verifyPassword(String password) async {
    if (_currentUser == null) {
      debugPrint('⚠️ Cannot verify password: No current user');
      return false;
    }

    try {
      final isValid = await _apiClient.verifyPassword(
        userId: _currentUser!.userId,
        password: password,
      );

      if (isValid) {
        debugPrint('✓ Password verification successful');
      } else {
        debugPrint('✗ Password verification failed');
      }

      return isValid;
    } on ApiException catch (e) {
      debugPrint('Password verification error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Unexpected error during password verification: $e');
      return false;
    }
  }

  /// Forgot password
  Future<void> forgotPassword(String email) async {
    try {
      _setLoading(true);
      _setError(null);

      await _apiClient.forgotPassword(email);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete account
  Future<void> deleteAccount({
    required String password,
    required String reason,
    String? feedback,
    required BuildContext context,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    try {
      _setLoading(true);
      _setError(null);

      await _apiClient.deleteAccount(
        userId: _currentUser!.userId,
        password: password,
        reason: reason,
        feedback: feedback,
      );

      await logout(context);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Sync contacts to backend (V2 bulk sync)
  Future<bool> syncContacts() async {
    if (_currentUser == null) {
      _setError('No user logged in');
      return false;
    }

    try {
      final result = await _contactService.requestPermissionAndSyncContacts(
        _currentUser!.userId,
      );

      // result is null if permission was denied; non-null means sync succeeded
      final success = result != null;

      if (success) {
        await _databaseService.markContactsSynced();
        _contactsSynced = true;
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('Error syncing contacts: $e');
      return false;
    }
  }

  /// Check if contacts are already synced in backend
  Future<bool> checkBackendContacts() async {
    if (_currentUser == null) return false;

    try {
      final hasContacts = await _contactService.hasContactsInBackend(
        _currentUser!.userId,
      );
      if (hasContacts) {
        _contactsSynced = true;
        await _databaseService.markContactsSynced();
        notifyListeners();
      }
      return hasContacts;
    } catch (e) {
      debugPrint('Error checking backend contacts: $e');
      return false;
    }
  }

  /// Clear database before new registration to remove old user data
  Future<void> clearDatabaseBeforeRegistration() async {
    try {
      await _databaseService.clearAllData();
      await _clearCredentialsForNativeAccess();
      _currentUser = null;
      _isAuthenticated = false;
      _contactsSynced = false;
      _apiClient.clearAuthToken();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing database: $e');
      // Continue with registration even if clearing fails
    }
  }

  /// Logout user
  Future<void> logout(BuildContext context) async {
    _currentUser = null;
    _isAuthenticated = false;
    _contactsSynced = false;
    _apiClient.clearAuthToken();

    // Clear all database data (user session, gallery cache, etc.)
    await _databaseService.clearAllData();

    // Clear credentials from SharedPreferences (for native Android access)
    await _clearCredentialsForNativeAccess();

    // Clear ProfileProvider state to prevent data leakage
    if (context.mounted) {
      Provider.of<ProfileProvider>(context, listen: false).clear();
    }

    notifyListeners();
  }

  // ==================== NATIVE ANDROID CREDENTIAL ACCESS ====================

  /// Save auth credentials to SharedPreferences for native Android background service
  /// This allows BackgroundShareService to upload without Flutter engine
  Future<void> _saveCredentialsForNativeAccess() async {
    if (_currentUser == null) {
      debugPrint('⚠️ Cannot save credentials: missing user');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Save userId (required)
      await prefs.setString(kPrefUserId, _currentUser!.userId);

      // Save token if available, otherwise use placeholder
      // Backend doesn't return token in login response, so we use userId for auth
      if (_apiClient.token != null && _apiClient.token!.isNotEmpty) {
        await prefs.setString(kPrefAuthToken, _apiClient.token!);
        debugPrint('✅ Saved auth token for native access');
      } else {
        // No token from backend - save userId as token for now
        await prefs.setString(kPrefAuthToken, _currentUser!.userId);
        debugPrint('⚠️ No backend token - using userId as auth credential');
      }

      await prefs.setString(
        kPrefBaseUrl,
        ApiConstants.baseUrl,
      );

      debugPrint(
        '✅ Saved credentials for native Android access (userId: ${_currentUser!.userId})',
      );
    } catch (e) {
      debugPrint('⚠️ Failed to save credentials for native access: $e');
    }
  }

  /// Clear auth credentials from SharedPreferences
  Future<void> _clearCredentialsForNativeAccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kPrefAuthToken);
      await prefs.remove(kPrefUserId);
      await prefs.remove(kPrefBaseUrl);
      debugPrint('✅ Cleared credentials for native Android access');
    } catch (e) {
      debugPrint('⚠️ Failed to clear credentials for native access: $e');
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    required String username,
    required String firstName,
    String? lastName,
    String? pronouns,
    String? bio,
    DateTime? dob,
    String? countryCode,
    String? phoneNumber,
  }) async {
    if (_currentUser == null) {
      _setError('No user logged in');
      return false;
    }

    try {
      _setLoading(true);
      _setError(null);

      final updatedUser = await _apiClient.updateProfile(
        userId: _currentUser!.userId,
        username: username,
        firstName: firstName,
        lastName: lastName,
        pronouns: pronouns,
        bio: bio,
        dob: dob,
        countryCode: countryCode,
        phoneNumber: phoneNumber,
      );

      _currentUser = updatedUser;

      // Update user session in database
      await _databaseService.updateUserSession(updatedUser);

      _setLoading(false);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to update profile: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Refresh current user data
  Future<void> refreshUser() async {
    if (_currentUser == null) return;

    try {
      final updatedUser = await _apiClient.getCurrentUser(_currentUser!.userId);

      // Preserve local archive PIN since backend doesn't know about it
      _currentUser = updatedUser.copyWith(archivePin: _currentUser!.archivePin);

      await _databaseService.updateUserSession(_currentUser!);
      notifyListeners();
    } catch (e) {
      // Silently fail on refresh
      debugPrint('Failed to refresh user: $e');
    }
  }

  /// Upload/Update profile picture
  Future<bool> uploadProfilePicture(File profileImage) async {
    if (_currentUser == null) {
      _setError('No user logged in');
      return false;
    }

    try {
      _setLoading(true);
      _setError(null);

      final updatedUser = await _apiClient.uploadProfilePicture(
        userId: _currentUser!.userId,
        profileImage: profileImage,
      );

      debugPrint(
        'Upload Profile Picture Response - UserID: "${updatedUser.userId}"',
      );

      // CRITICAL FAILSAFE: Verify the API returned a valid user ID.
      // If not, assume the backend only returned partial data and PRESERVE our existing valid ID.
      UserModel finalUser = updatedUser;
      if (updatedUser.userId.isEmpty) {
        debugPrint(
          '⚠️ Upload Profile Picture returned empty User ID! Preserving existing ID: ${_currentUser!.userId}',
        );
        // Merge the new data (likely just profile_pic_id) into the existing user object
        // OR force the ID back into the new object
        finalUser = updatedUser.copyWith(
          userId: _currentUser!.userId, // Restore valid ID
          // Token is not part of UserModel, so no need to restore it here.
          // It is managed by ApiClient and SharedPreferences.
        );
      }

      // Preserve local archive PIN
      _currentUser = finalUser.copyWith(archivePin: _currentUser!.archivePin);

      // Update user session in database
      await _databaseService.updateUserSession(_currentUser!);

      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to upload profile picture: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Reset profile picture to default avatar
  Future<bool> resetProfilePicture() async {
    if (_currentUser == null) {
      _setError('No user logged in');
      return false;
    }

    try {
      _setLoading(true);
      _setError(null);

      final response = await _apiClient.resetProfilePicture(
        userId: _currentUser!.userId,
      );

      // Update user with new default avatar profile_pic_id
      _currentUser = _currentUser!.copyWith(
        profilePicId: response['profile_pic_id'] as String?,
      );

      // Update user session in database
      await _databaseService.updateUserSession(_currentUser!);

      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to reset profile picture: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // ==================== ARCHIVE PIN METHODS ====================

  bool get hasArchivePin =>
      _currentUser?.archivePin != null && _currentUser!.archivePin!.isNotEmpty;

  /// Set Archive PIN
  Future<bool> setArchivePin(String pin) async {
    if (_currentUser == null) return false;

    try {
      // update local user model
      _currentUser = _currentUser!.copyWith(archivePin: pin);

      // persist to local DB
      await _databaseService.updateUserSession(_currentUser!);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to set archive pin: $e');
      return false;
    }
  }

  /// Check Archive PIN
  bool checkArchivePin(String pin) {
    if (_currentUser == null || _currentUser!.archivePin == null) return false;
    return _currentUser!.archivePin == pin;
  }
}
