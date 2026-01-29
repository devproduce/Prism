import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/user_model.dart';
import 'package:prism/services/database_service.dart';
import 'package:prism/services/contact_service.dart';
import 'package:prism/providers/profile_provider.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final DatabaseService _databaseService = DatabaseService.instance;
  final ContactService _contactService = ContactService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  bool _contactsSynced = false;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  bool get contactsSynced => _contactsSynced;
  ApiClient get apiClient => _apiClient;

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
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Failed to initialize auth: $e');
    }
  }

  /// Register a new user
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    String? lastName,
    required File profileImage,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _apiClient.register(
        username: username,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        profileImage: profileImage,
      );

      _currentUser = response.user;
      _isAuthenticated = true;

      // Save user session to database
      await _databaseService.saveUserSession(response.user);

      // Fetch fresh profile from backend to ensure latest data
      try {
        final freshUser = await _apiClient.getCurrentUser(response.user.userId);
        _currentUser = freshUser;
        await _databaseService.updateUserSession(freshUser);
      } catch (e) {
        debugPrint('Warning: Could not fetch fresh profile: $e');
        // Continue with registration even if profile fetch fails
      }

      _setLoading(false);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Login user
  Future<bool> login({required String email, required String password}) async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _apiClient.login(email: email, password: password);

      _currentUser = response.user;
      _isAuthenticated = true;

      // Save user session to database
      await _databaseService.saveUserSession(response.user);

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

      _setLoading(false);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Sync contacts to backend
  Future<bool> syncContacts() async {
    if (_currentUser == null) {
      _setError('No user logged in');
      return false;
    }

    try {
      final success = await _contactService.requestPermissionAndSyncContacts(
        _currentUser!.userId,
      );

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

    // Clear ProfileProvider state to prevent data leakage
    if (context.mounted) {
      Provider.of<ProfileProvider>(context, listen: false).clear();
    }

    notifyListeners();
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
      _currentUser = updatedUser;
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
      _setError('Failed to upload profile picture: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }
}
