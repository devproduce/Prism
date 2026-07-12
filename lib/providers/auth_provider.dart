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
import 'package:prism/services/auth_backend_capabilities.dart';
import 'package:prism/providers/profile_provider.dart';
import 'package:prism/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider() {
    _apiClient.onSessionExpired = _handleSessionExpired;
    _apiClient.onAuthGateRequired = _handleAuthGateRequired;
    _apiClient.onAccessTokenRefreshed = _onAccessTokenRefreshed;
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

  /// Whether the restored or active session is sufficient to enter the app.
  bool get hasValidSession {
    if (!_isAuthenticated || _currentUser == null) return false;
    if (AuthBackendCapabilities.firebaseAuthEnabled) {
      final t = _apiClient.token;
      return t != null && t.isNotEmpty;
    }
    final userId = _sessionStore.sessionUserId ?? _currentUser!.userId;
    return userId.isNotEmpty;
  }

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
      _apiClient.setLegacyAuthMode(AuthBackendCapabilities.legacyAuthEnabled);

      final isLoggedIn = await _databaseService.isUserLoggedIn();
      if (!isLoggedIn) return;

      final user = await _databaseService.getUserSession();
      if (user == null) return;

      await _sessionStore.ensureSessionUserIdHydrated();
      final accessToken = await _tokenStorage.getAccessToken();
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString(kPrefUserId);
      debugPrint(
        'Auth init: jwt=${accessToken?.length ?? 0} chars, '
        'userId=${storedUserId != null && storedUserId.isNotEmpty}',
      );

      if (AuthBackendCapabilities.firebaseAuthEnabled &&
          (accessToken == null || accessToken.isEmpty)) {
        debugPrint(
          '⚠️ SQLite session without JWT — clearing stale session',
        );
        await _clearStaleSession();
        return;
      }

      _currentUser = user;
      _isAuthenticated = true;
      await _sessionStore.bindUser(user.userId);
      _bindApiUser();
      _authGate = _sessionStore.authGate;
      await _hydrateContactsSyncedState(user.userId);

      if (accessToken != null && accessToken.isNotEmpty) {
        _apiClient.setAuthToken(accessToken);
        debugPrint('✅ Restored access token from storage');
      }

      await _saveCredentialsForNativeAccess();
      if (_apiClient.token != null) {
        NotificationService.registerDeviceToken(user.userId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize auth: $e');
    }
  }

  Future<void> _clearStaleSession() async {
    _currentUser = null;
    _isAuthenticated = false;
    _contactsSynced = false;
    _authGate = AuthGate.none;
    await _apiClient.clearAuthToken();
    await _sessionStore.clear();
    await _databaseService.clearAllData();
    await _clearCredentialsForNativeAccess();
    notifyListeners();
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

  void _onAccessTokenRefreshed() {
    final userId = _currentUser?.userId;
    if (userId != null) {
      NotificationService.registerDeviceToken(userId);
    }
  }

  void clearSessionExpiredFlag() {
    _sessionExpired = false;
  }

  /// Clear session state after a refresh-token failure invalidated the session.
  Future<void> acknowledgeSessionExpiry(BuildContext context) async {
    if (!_sessionExpired) return;
    clearSessionExpiredFlag();
    await logout(context);
  }

  void clearAuthGate() {
    _authGate = AuthGate.none;
    _sessionStore.setAuthGate(AuthGate.none);
    notifyListeners();
  }

  Future<bool> _finalizeAuthenticatedSession(AuthResponse response) async {
    await _persistAuthTokensFromResponse(response);

    if (AuthBackendCapabilities.firebaseAuthEnabled && !_hasJwtAvailable(response)) {
      debugPrint(
        'Login failed: backend did not return an access token '
        '(apiClient.token=${_apiClient.token?.length ?? 0} chars)',
      );
      _setError('Login failed. Please try again.');
      return false;
    }

    _currentUser = response.user;
    _isAuthenticated = true;
    _authGate = AuthGate.none;
    _sessionStore.setAuthGate(AuthGate.none);

    await _sessionStore.bindUser(response.user.userId);
    _bindApiUser();
    await _databaseService.saveUserSession(response.user);
    await _saveCredentialsForNativeAccess();

    try {
      final freshUser = await _apiClient.getCurrentUser(response.user.userId);
      _currentUser = freshUser.copyWith(archivePin: _currentUser?.archivePin);
      await _databaseService.updateUserSession(_currentUser!);
    } catch (e) {
      if (e is ApiException && e.statusCode == 403) {
        debugPrint('Session active but email verification required: $e');
      } else {
        debugPrint('Warning: Could not fetch fresh profile: $e');
        _setError(
          e is ApiException
              ? e.message
              : 'Could not load full profile. Pull to refresh.',
        );
      }
    }

    await _hydrateContactsSyncedState(response.user.userId);
    NotificationService.registerDeviceToken(response.user.userId);
    notifyListeners();
    return true;
  }

  Future<void> _persistAuthTokensFromResponse(AuthResponse response) async {
    final accessToken = response.accessToken ?? _apiClient.token;
    if (accessToken != null && accessToken.isNotEmpty) {
      await _apiClient.saveAuthTokens(
        accessToken: accessToken,
        refreshToken: response.refreshToken,
      );
      debugPrint('✅ Auth tokens persisted (${accessToken.length} chars)');
    }
  }

  bool _hasJwtAvailable(AuthResponse response) {
    final fromResponse =
        response.accessToken != null && response.accessToken!.isNotEmpty;
    final fromClient = _apiClient.token != null && _apiClient.token!.isNotEmpty;
    return fromResponse || fromClient;
  }

  /// Validates the session with the backend and refreshes cached user data.
  Future<bool> validateAndHydrateSession() async {
    if (!hasValidSession || _currentUser == null) return false;

    try {
      final freshUser = await _apiClient.getCurrentUser(_currentUser!.userId);
      _currentUser = freshUser.copyWith(archivePin: _currentUser!.archivePin);
      await _databaseService.updateUserSession(_currentUser!);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Session validation failed: $e');
      rethrow;
    }
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
      final ok = await _finalizeAuthenticatedSession(response);
      if (!ok) {
        if (manageLoadingState) _setLoading(false);
        return false;
      }
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

  void _bindApiUser() {
    _apiClient.setLegacyAuthMode(AuthBackendCapabilities.legacyAuthEnabled);
  }

  /// Legacy username/password login for backends without Firebase auth.
  Future<bool> login({
    required String identifier,
    required String password,
    bool manageLoadingState = true,
  }) async {
    try {
      if (manageLoadingState) {
        _setLoading(true);
        _setError(null);
      }

      final response = await _apiClient.login(
        identifier: identifier,
        password: password,
      );

      if (response.needsMigration == true) {
        beginLegacyMigration(
          ResolveUsernameResult(
            needsMigration: true,
            migrationToken: response.migrationToken,
            hasFirebaseAccount: false,
            prefilledEmail: response.user.email.isNotEmpty
                ? response.user.email
                : null,
          ),
        );
        if (manageLoadingState) _setLoading(false);
        return false;
      }

      final ok = await _finalizeAuthenticatedSession(response);
      if (manageLoadingState) _setLoading(false);
      return ok;
    } on ApiException catch (e) {
      final message = e.statusCode == 401
          ? (e.message.toLowerCase().contains('session')
              ? 'Invalid username or password.'
              : e.message)
          : e.message;
      _setError(message);
      if (manageLoadingState) _setLoading(false);
      return false;
    } catch (e) {
      _setError(ErrorHandler.getErrorMessage(e));
      if (manageLoadingState) _setLoading(false);
      return false;
    }
  }

  Future<bool> migrateLegacyAccount({required String email}) async {
    final migrationToken = _sessionStore.migrationToken;
    if (migrationToken == null || migrationToken.isEmpty) {
      _setError('Migration session expired. Please log in again.');
      return false;
    }

    try {
      _setLoading(true);
      _setError(null);

      final response = await _apiClient.verifyLegacyEmail(
        migrationToken: migrationToken,
        email: email,
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
      final ok = await _finalizeAuthenticatedSession(response);
      if (!ok) {
        _setLoading(false);
        return false;
      }
      clearAuthGate();
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
      final ok = await _finalizeAuthenticatedSession(response);
      if (!ok) {
        _setLoading(false);
        return false;
      }
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

      final ok = await _finalizeAuthenticatedSession(response);
      if (!ok) {
        _setLoading(false);
        return false;
      }
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
      final ok = await _finalizeAuthenticatedSession(response);
      if (!ok) {
        _setLoading(false);
        return false;
      }
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

  /// Register a new user.
  /// Creates Firebase identity first, then registers with the Prism backend.
  Future<bool> register({
    required String username,
    required String password,
    required String email,
    required String countryCode,
    required String phoneNumber,
    String? firstName,
    String? lastName,
    File? profileImage,
    List<String>? faceIds,
  }) async {
    try {
      _setLoading(true);
      _setError(null);
      _phoneSyncWarning = false;

      final trimmedEmail = email.trim();
      if (trimmedEmail.isEmpty) {
        _setError('Email is required');
        _setLoading(false);
        return false;
      }

      final code = countryCode.replaceAll('+', '').trim();
      final phone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '').trim();
      if (code.isEmpty || phone.isEmpty) {
        _setError('Phone number is required');
        _setLoading(false);
        return false;
      }

      if (faceIds == null || faceIds.isEmpty) {
        _setError('Face scan is required to complete registration');
        _setLoading(false);
        return false;
      }

      if (profileImage == null || !await profileImage.exists()) {
        _setError(
          'Profile photo is required. Please complete the face scan again.',
        );
        _setLoading(false);
        return false;
      }

      String? firebaseToken;
      if (AuthBackendCapabilities.firebaseAuthEnabled) {
        try {
          await _firebaseAuth.createUserWithEmailAndPassword(
            email: trimmedEmail,
            password: password,
          );
          firebaseToken = await _firebaseAuth.getIdToken();
        } on FirebaseAuthException catch (e) {
          _setError(_firebaseAuth.friendlyError(e));
          _setLoading(false);
          return false;
        }
      }

      try {
        final response = await _apiClient.register(
          username: username,
          password: password,
          countryCode: code,
          phoneNumber: phone,
          email: trimmedEmail,
          firstName: firstName,
          lastName: lastName,
          profileImage: profileImage,
          faceIds: faceIds,
          firebaseToken: firebaseToken,
        );

        if (response.phoneSynced == false) {
          _phoneSyncWarning = true;
          debugPrint(
            '⚠️ phone_synced=false: phone number could not be verified',
          );
        }

        if (AuthBackendCapabilities.firebaseAuthEnabled) {
          await _sessionStore.setHasFirebaseAccount(response.user.userId, true);
          final ok = await _finalizeAuthenticatedSession(response);
          if (!ok) {
            _setLoading(false);
            return false;
          }
          if (_currentUser != null && _currentUser!.email.isEmpty) {
            _currentUser = _currentUser!.copyWith(email: trimmedEmail);
            await _databaseService.updateUserSession(_currentUser!);
          }
          _authGate = AuthGate.verifyEmail;
          _sessionStore.setAuthGate(AuthGate.verifyEmail);
          _setLoading(false);
          notifyListeners();
          return true;
        }

        final ok = await _finalizeAuthenticatedSession(response);
        if (!ok) {
          _setLoading(false);
          return false;
        }
        _setLoading(false);
        return true;
      } catch (e) {
        if (AuthBackendCapabilities.firebaseAuthEnabled) {
          await _firebaseAuth.signOut();
        }
        rethrow;
      }
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

      final email = await _apiClient.forgotPassword(identifier.trim());
      if (email != null && email.isNotEmpty) {
        await _firebaseAuth.sendPasswordResetEmail(email: email);
      }
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

      await _firebaseAuth.deleteCurrentUser();
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

    if (!await _apiClient.ensureAuthenticated()) {
      _setError('Your session has expired. Please log in again.');
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

  /// Refresh current user data and optionally sync [profileProvider].
  Future<bool> refreshUser({ProfileProvider? profileProvider}) async {
    if (_currentUser == null) return false;

    if (!await _apiClient.ensureAuthenticated()) {
      _setError('Your session has expired. Please log in again.');
      return false;
    }

    try {
      final updatedUser = await _apiClient.getCurrentUser(_currentUser!.userId);

      // Preserve local archive PIN since backend doesn't know about it
      _currentUser = updatedUser.copyWith(archivePin: _currentUser!.archivePin);

      await _databaseService.updateUserSession(_currentUser!);
      if (profileProvider != null) {
        profileProvider.initializeWithUser(_currentUser!);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to refresh user: $e');
      _setError(
        e is ApiException
            ? e.message
            : 'Failed to refresh profile. Please try again.',
      );
      return false;
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

      // Update user with new default avatar profile_pic_id; clear custom imageId.
      _currentUser = _currentUser!.copyWith(
        profilePicId: response['profile_pic_id'] as String?,
        imageId: '',
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
