import 'dart:io';
import 'package:flutter/material.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/user_model.dart';
import 'package:prism/services/database_service.dart';
import 'package:prism/services/contact_service.dart';

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

  /// Logout user
  Future<void> logout() async {
    _currentUser = null;
    _isAuthenticated = false;
    _apiClient.clearAuthToken();

    // Clear user session from database
    await _databaseService.clearUserSession();

    notifyListeners();
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? username,
    String? firstName,
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
}
