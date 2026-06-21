import 'dart:io';
import 'package:flutter/material.dart';
import 'package:prism/utils/constants.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:prism/utils/auth_constants.dart';
import 'package:prism/models/auth_gate.dart';
import 'package:prism/models/resolve_username_result.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/user_model.dart';
import 'package:prism/models/auth_response.dart';
import 'package:prism/services/database_service.dart';
import 'package:prism/services/contact_service.dart';
import 'package:prism/services/token_storage_service.dart';
import 'package:prism/services/auth_session_store.dart';
import 'package:prism/services/firebase_auth_service.dart';
import 'package:prism/providers/profile_provider.dart';
import 'package:prism/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider() {
    _apiClient.onSessionExpired = _handleSessionExpired;
    _apiClient.onAuthGateRequired = _handleAuthGateRequired;
  }

  final ApiClient _apiClient = ApiClient();
  final DatabaseService _databaseService = DatabaseService.instance;
  final ContactService _contactService = ContactService();
  final TokenStorageService _tokenStorage = TokenStorageService.instance;
  final AuthSessionStore _sessionStore = AuthSessionStore.instance;
  final FirebaseAuthService _firebaseAuth = FirebaseAuthService.instance;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  bool _contactsSynced = false;
  AuthGate _authGate = AuthGate.none;
  bool _sessionExpired = false;

  bool _phoneSyncWarning = false;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  bool get contactsSynced => _contactsSynced;
  AuthGate get authGate => _authGate;
  bool get sessionExpired => _sessionExpired;
  /// True when the backend could not normalize the phone number on registration.
  bool get phoneSyncWarning => _phoneSyncWarning;
  ApiClient get apiClient => _apiClient;
  String? get token => _apiClient.token;

  /// Check username availability
  Future<bool> checkUsernameAvailability(String username) async {
    return await _apiClient.checkUsernameAvailability(username);
  }

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
      _sessionExpired = false;
      final isLoggedIn = await _databaseService.isUserLoggedIn();
      if (isLoggedIn) {
        final user = await _databaseService.getUserSession();
        if (user != null) {
          _currentUser = user;
          _isAuthenticated = true;
          await _sessionStore.bindUser(user.userId);
          _authGate = _sessionStore.authGate;
          await _hydrateContactsSyncedState(user.userId);

          final accessToken = await _tokenStorage.getAccessToken();
          if (accessToken != null && accessToken.isNotEmpty) {
            _apiClient.setAuthToken(accessToken);
            debugPrint('✅ Restored access token from storage');
          } else {
            debugPrint('⚠️ No saved access token found');
          }

          await _saveCredentialsForNativeAccess();
          NotificationService.registerDeviceToken(user.userId);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Failed to initialize auth: $e');
    }
  }

  void _handleSessionExpired() {
    _sessionExpired = true;
    _isAuthenticated = false;
    _authGate = AuthGate.none;
    notifyListeners();
  }

  void _handleAuthGateRequired(AuthGate gate) {
    _authGate = gate;
    _sessionStore.setAuthGate(gate);
    notifyListeners();
  }

  void clearSessionExpiredFlag() {
    _sessionExpired = false;
  }

  void clearAuthGate() {
    _authGate = AuthGate.none;
    _sessionStore.setAuthGate(AuthGate.none);
    notifyListeners();
  }

  Future<bool> _finalizeAuthenticatedSession(AuthResponse response) async {
    _currentUser = response.user;
    _isAuthenticated = true;
    _authGate = AuthGate.none;
    _sessionStore.setAuthGate(AuthGate.none);

    if (response.accessToken != null && response.accessToken!.isNotEmpty) {
      debugPrint('✅ Auth tokens persisted from response');
    } else {
      debugPrint('⚠️ No access token in auth response');
    }

    await _sessionStore.bindUser(response.user.userId);
    await _databaseService.saveUserSession(response.user);
    await _saveCredentialsForNativeAccess();

    try {
      final freshUser = await _apiClient.getCurrentUser();
      _currentUser = freshUser;
      await _databaseService.updateUserSession(freshUser);
    } catch (e) {
      if (e is ApiException && e.statusCode == 403) {
        debugPrint('Session active but email verification required: $e');
      } else {
        debugPrint('Warning: Could not fetch fresh profile: $e');
      }
    }

    await _hydrateContactsSyncedState(response.user.userId);
    NotificationService.registerDeviceToken(response.user.userId);
    notifyListeners();
    return true;
  }

  Future<ResolveUsernameResult> resolveUsername(String username) async {
    return _apiClient.resolveUsername(username);
  }

  Future<bool> loginWithFirebaseEmail({
    required String email,
    required String password,
    bool manageLoadingState = true,
  }) async {
    try {
      if (manageLoadingState) {
        _setLoading(true);
        _setError(null);
      }

      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final idToken = await _firebaseAuth.getIdToken();
      final response = await _apiClient.loginVerify(idToken: idToken);
      await _finalizeAuthenticatedSession(response);
      if (manageLoadingState) _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_firebaseAuth.friendlyError(e));
      if (manageLoadingState) _setLoading(false);
      return false;
    } on ApiException catch (e) {
      _setError(e.message);
      if (manageLoadingState) _setLoading(false);
      return false;
    } catch (e) {
      _setError(ErrorHandler.getErrorMessage(e));
      if (manageLoadingState) _setLoading(false);
      return false;
    }
  }

  Future<bool> _recoverRegistrationSession({
    required UserModel registeredUser,
    required String username,
    required String password,
    String? email,
  }) async {
    var loginEmail = email?.trim().isNotEmpty == true
        ? email!.trim()
        : (registeredUser.email.isNotEmpty ? registeredUser.email : null);

    if (loginEmail == null || loginEmail.isEmpty) {
      try {
        final resolved = await _apiClient.resolveUsername(username);
        loginEmail = resolved.email;
      } catch (e) {
        debugPrint('Could not resolve email after registration: $e');
      }
    }

    if (loginEmail == null || loginEmail.isEmpty) {
      _setError(
        'Registration succeeded but sign-in failed. Please log in with your username.',
      );
      return false;
    }

    return loginWithFirebaseEmail(
      email: loginEmail,
      password: password,
      manageLoadingState: false,
    );
  }

  UserModel _mergeRegisteredUserData(
    UserModel? current,
    UserModel registeredUser,
  ) {
    final merged = current ?? registeredUser;
    return merged.copyWith(
      firstName: merged.firstName.isEmpty
          ? registeredUser.firstName
          : merged.firstName,
      lastName: merged.lastName ?? registeredUser.lastName,
      phoneNumber: merged.phoneNumber ?? registeredUser.phoneNumber,
      countryCode: merged.countryCode ?? registeredUser.countryCode,
      email: merged.email.isEmpty ? registeredUser.email : merged.email,
      username:
          merged.username.isEmpty ? registeredUser.username : merged.username,
    );
  }

  Future<bool> migrateLegacyAccount({
    required String email,
    required String password,
  }) async {
    final migrationToken = _sessionStore.migrationToken;
    if (migrationToken == null || migrationToken.isEmpty) {
      _setError('Migration session expired. Please log in again.');
      return false;
    }

    try {
      _setLoading(true);
      _setError(null);

      final response = await _apiClient.migrateEmail(
        migrationToken: migrationToken,
        email: email,
        password: password,
      );

      if (_currentUser != null) {
        await _sessionStore.setHasFirebaseAccount(_currentUser!.userId, true);
      } else {
        await _sessionStore.setHasFirebaseAccount(
          response.user.userId,
          true,
        );
      }

      _sessionStore.setMigrationToken(null);
      await _finalizeAuthenticatedSession(response);
      _authGate = AuthGate.verifyEmail;
      _sessionStore.setAuthGate(AuthGate.verifyEmail);
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

  Future<void> resendVerificationEmail() async {
    await _apiClient.resendVerificationEmail();
  }

  Future<bool> confirmEmailVerified() async {
    try {
      _setLoading(true);
      await _firebaseAuth.reloadCurrentUser();
      if (!_firebaseAuth.isEmailVerified) {
        _setLoading(false);
        return false;
      }

      final idToken = await _firebaseAuth.getIdToken(forceRefresh: true);
      final response = await _apiClient.loginVerify(idToken: idToken);
      await _finalizeAuthenticatedSession(response);
      clearAuthGate();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(ErrorHandler.getErrorMessage(e));
      _setLoading(false);
      return false;
    }
  }

  void beginLegacyMigration(ResolveUsernameResult result) {
    _sessionStore.setMigrationToken(result.migrationToken);
    _sessionStore.hasFirebaseAccount = result.hasFirebaseAccount;
    _authGate = AuthGate.migrateAccount;
    _sessionStore.setAuthGate(AuthGate.migrateAccount);
    notifyListeners();
  }

  /// Google sign-in for returning users. Returns false when registration is required.
  Future<bool> loginWithGoogle() async {
    try {
      _setLoading(true);
      _setError(null);

      await _firebaseAuth.signInWithGoogle();
      final idToken = await _firebaseAuth.getIdToken();
      final response = await _apiClient.googleLogin(idToken: idToken);

      if (response.exists == false) {
        _pendingGoogleIdToken = idToken;
        _googleRegistrationRequired = true;
        _setError(null);
        _setLoading(false);
        return false;
      }

      await _finalizeAuthenticatedSession(response);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'google-sign-in-cancelled') {
        _setError(null);
      } else {
        _setError(_firebaseAuth.friendlyError(e));
      }
      _setLoading(false);
      return false;
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

  /// Returns true when [loginWithGoogle] found no existing Prism account.
  bool get googleRegistrationRequired => _googleRegistrationRequired;
  bool _googleRegistrationRequired = false;
  String? _pendingGoogleIdToken;

  bool get usesGoogleAuth {
    final provider = _currentUser?.authProvider?.toLowerCase();
    if (provider != null && provider.isNotEmpty) {
      return provider == 'google';
    }
    return _firebaseAuth.isGoogleLinked;
  }

  void clearGoogleRegistrationRequired() {
    _googleRegistrationRequired = false;
    _pendingGoogleIdToken = null;
  }

  Future<bool> completeGoogleRegistration({
    required String username,
    List<String>? faceIds,
    File? profileImage,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final idToken = _pendingGoogleIdToken ??
          await _firebaseAuth.getIdToken(forceRefresh: true);
      final response = await _apiClient.googleRegister(
        idToken: idToken,
        username: username,
        faceIds: faceIds,
        profileImage: profileImage,
      );

      _pendingGoogleIdToken = null;
      _googleRegistrationRequired = false;
      await _finalizeAuthenticatedSession(response);
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

  Future<String> _reauthenticateForSensitiveAction({String? password}) async {
    if (usesGoogleAuth) {
      await _firebaseAuth.reauthenticateWithGoogle();
    } else {
      final email =
          _currentUser?.email ?? _firebaseAuth.currentUser?.email ?? '';
      if (email.isEmpty || password == null || password.isEmpty) {
        throw StateError('Password is required to confirm this action.');
      }
      await _firebaseAuth.reauthenticateWithPassword(
        email: email,
        password: password,
      );
    }
    return _firebaseAuth.getIdToken(forceRefresh: true);
  }

  Future<void> forceLogout(BuildContext context) async {
    await logout(context);
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
      final token = response.accessToken;

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
        debugPrint('🔄 Initiating Firebase recovery after registration...');

        final registeredUser = _currentUser ?? response.user;
        final loginSuccess = await _recoverRegistrationSession(
          registeredUser: registeredUser,
          username: username,
          password: password,
          email: email,
        );

        if (loginSuccess) {
          _currentUser = _mergeRegisteredUserData(_currentUser, registeredUser);
          await _databaseService.updateUserSession(_currentUser!);
        }

        _setLoading(false);
        return loginSuccess;
      }

      await _finalizeAuthenticatedSession(response);
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


  /// Verify password for archive unlock.
  /// Returns true if password is valid
  Future<bool> verifyPassword(String password) async {
    if (_currentUser == null) {
      debugPrint('⚠️ Cannot verify password: No current user');
      return false;
    }

    try {
      final isValid = await _apiClient.verifyPassword(
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

  /// Forgot password — accepts username or email.
  Future<void> forgotPassword(String identifier) async {
    try {
      _setLoading(true);
      _setError(null);

      await _apiClient.forgotPassword(identifier.trim());
    } catch (_) {
      // Always show generic success per security policy.
    } finally {
      _setLoading(false);
    }
  }

  /// Delete account after Firebase re-authentication.
  Future<void> deleteAccount({
    String? password,
    required String reason,
    String? feedback,
    required BuildContext context,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    try {
      _setLoading(true);
      _setError(null);

      final firebaseToken =
          await _reauthenticateForSensitiveAction(password: password);

      await _apiClient.deleteAccount(
        firebaseToken: firebaseToken,
        reason: reason,
        feedback: feedback,
      );

      await logout(context);
    } on FirebaseAuthException catch (e) {
      _setError(_firebaseAuth.friendlyError(e));
      rethrow;
    } catch (e) {
      _setError(ErrorHandler.getErrorMessage(e));
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Cancel scheduled account deletion.
  Future<void> cancelAccountDeletion({
    String? password,
    required BuildContext context,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final firebaseToken =
          await _reauthenticateForSensitiveAction(password: password);
      await _apiClient.cancelDeletion(firebaseToken: firebaseToken);
      await refreshUser();
    } on FirebaseAuthException catch (e) {
      _setError(_firebaseAuth.friendlyError(e));
      rethrow;
    } catch (e) {
      _setError(ErrorHandler.getErrorMessage(e));
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
      final user = _currentUser!;
      final fullName = '${user.firstName} ${user.lastName ?? ''}'.trim();
      final ownerName = fullName.isNotEmpty ? fullName : user.username;

      final outcome = await _contactService.requestPermissionAndSyncContacts(
        user.userId,
        accountCountryCode: user.countryCode,
        accountPhone: user.phoneNumber,
        accountDisplayName: ownerName,
      );

      final success = outcome.isSuccess;

      if (success) {
        await _databaseService.markContactsSynced();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('contacts_synced_${_currentUser!.userId}', true);
        
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
    await _hydrateContactsSyncedState(_currentUser!.userId);
    return _contactsSynced;
  }

  /// Align local flags with backend when the user already synced on another device
  /// or after reinstall (SharedPreferences / SQLite may be empty).
  Future<void> _hydrateContactsSyncedState(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('contacts_synced_$userId') ?? false) {
      final storedOnBackend =
          await _contactService.hasContactsStoredOnBackend(userId);
      if (storedOnBackend) {
        _contactsSynced = true;
        await _databaseService.markContactsSynced();
      }
      return;
    }

    if (await _databaseService.hasContactsSynced()) {
      final storedOnBackend =
          await _contactService.hasContactsStoredOnBackend(userId);
      if (storedOnBackend) {
        _contactsSynced = true;
        await prefs.setBool('contacts_synced_$userId', true);
      }
      return;
    }

    _contactsSynced = false;
    notifyListeners();
  }

  /// Clear database before new registration to remove old user data
  Future<void> clearDatabaseBeforeRegistration() async {
    try {
      await _databaseService.clearAllData();
      await _clearCredentialsForNativeAccess();
      await _sessionStore.clear();
      await _firebaseAuth.signOut();
      _currentUser = null;
      _isAuthenticated = false;
      _contactsSynced = false;
      _authGate = AuthGate.none;
      await _apiClient.clearAuthToken();
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
    _authGate = AuthGate.none;
    await _apiClient.clearAuthToken();
    await _sessionStore.clear();
    await _firebaseAuth.signOut();

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
        debugPrint('⚠️ No backend token available for native access');
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
      final updatedUser = await _apiClient.getCurrentUser();

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

      final response = await _apiClient.resetProfilePicture();

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
