import 'dart:io';
import 'package:flutter/material.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/user_model.dart';
import 'package:prism/services/database_service.dart';

class ProfileProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final DatabaseService _databaseService = DatabaseService.instance;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  // Stats - hardcoded for now, ready for backend integration
  int _postsCount = 27;
  int _friendsCount = 607;
  int _reach = 1234;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get postsCount => _postsCount;
  int get friendsCount => _friendsCount;
  int get reach => _reach;

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

  Future<bool> _ensureAuthenticated() async {
    if (!await _apiClient.ensureAuthenticated()) {
      _setError('Your session has expired. Please log in again.');
      return false;
    }
    return true;
  }

  /// Initialize profile with user from database
  void initializeWithUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Fetch user profile from backend
  Future<void> fetchUserProfile(String userId) async {
    if (!await _ensureAuthenticated()) return;

    try {
      _setLoading(true);
      _setError(null);

      debugPrint('Fetching user profile for: $userId');

      final user = await _apiClient.getCurrentUser();

      _currentUser = user;

      // Update database cache
      await _databaseService.updateUserSession(user);

      debugPrint('Profile fetched successfully');
      _setLoading(false);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      final message = e is ApiException
          ? e.message
          : 'Failed to load profile: ${e.toString()}';
      _setError(message);
      _setLoading(false);
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
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
    if (!await _ensureAuthenticated()) return false;

    try {
      _setLoading(true);
      _setError(null);

      debugPrint('Updating profile for user: $userId');

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

      // Update database cache
      await _databaseService.updateUserSession(updatedUser);

      debugPrint('Profile updated successfully');

      // Refetch profile from backend to ensure we have the latest data
      debugPrint('Refetching profile to confirm latest data');
      await fetchUserProfile(userId);

      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      _setError('Failed to update profile: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Upload profile picture
  Future<bool> uploadProfilePicture({
    required String userId,
    required File profileImage,
  }) async {
    if (!await _ensureAuthenticated()) return false;

    try {
      _setLoading(true);
      _setError(null);

      debugPrint('Uploading profile picture for user: $userId');

      final updatedUser = await _apiClient.uploadProfilePicture(
        profileImage: profileImage,
      );

      _currentUser = updatedUser;

      // Update database cache
      await _databaseService.updateUserSession(updatedUser);

      debugPrint('Profile picture uploaded successfully');

      // Refetch profile from backend to ensure we have the latest data
      debugPrint('Refetching profile to confirm latest data');
      await fetchUserProfile(userId);

      return true;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      _setError('Failed to upload profile picture: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Refresh profile data
  Future<void> refresh(String userId) async {
    await fetchUserProfile(userId);
  }

  /// Update stats (when backend integration is ready)
  void updateStats({int? posts, int? friends, int? reach}) {
    if (posts != null) _postsCount = posts;
    if (friends != null) _friendsCount = friends;
    if (reach != null) _reach = reach;
    notifyListeners();
  }

  /// Clear profile data
  void clear() {
    _currentUser = null;
    _isLoading = false;
    _error = null;
    _postsCount = 27;
    _friendsCount = 607;
    _reach = 1234;
    notifyListeners();
  }
}
