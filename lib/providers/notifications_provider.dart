import 'package:flutter/material.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/notification_model.dart';

class NotificationsProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get unread count
  int get unreadCount => _notifications.where((notif) => !notif.isRead).length;

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

  /// Fetch notifications
  Future<void> fetchNotifications(String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      final data = await _apiClient.getNotifications(userId: userId);
      _notifications = data
          .map((json) => NotificationModel.fromJson(json))
          .toList();

      // Sort by date (newest first)
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _setLoading(false);
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
    } catch (e) {
      _setError('Failed to fetch notifications: ${e.toString()}');
      _setLoading(false);
    }
  }

  /// Accept friend request from notification
  Future<bool> acceptFriendRequest(String notificationId, String userId) async {
    try {
      _setError(null);

      await _apiClient.acceptFriendRequestFromNotification(
        notificationId: notificationId,
        userId: userId,
      );

      // Refresh notifications
      await fetchNotifications(userId);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to accept friend request: ${e.toString()}');
      return false;
    }
  }

  /// Reject friend request from notification
  Future<bool> rejectFriendRequest(String notificationId, String userId) async {
    try {
      _setError(null);

      await _apiClient.rejectFriendRequestFromNotification(
        notificationId: notificationId,
        userId: userId,
      );

      // Refresh notifications
      await fetchNotifications(userId);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to reject friend request: ${e.toString()}');
      return false;
    }
  }

  /// Mark notification as read (local only for now)
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = NotificationModel(
        id: _notifications[index].id,
        type: _notifications[index].type,
        message: _notifications[index].message,
        userId: _notifications[index].userId,
        username: _notifications[index].username,
        profilePicId: _notifications[index].profilePicId,
        metadata: _notifications[index].metadata,
        createdAt: _notifications[index].createdAt,
        isRead: true,
      );
      notifyListeners();
    }
  }

  /// Refresh notifications
  Future<void> refresh(String userId) async {
    await fetchNotifications(userId);
  }
}
