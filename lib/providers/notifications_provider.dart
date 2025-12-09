import 'package:flutter/material.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/notification_model.dart';
import 'package:prism/models/friend_model.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationsProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<NotificationModel> _notifications = [];
  List<FriendRequest> _pendingRequests = []; // Friend requests received
  List<FriendRequest> _sentRequests = []; // Friend requests sent
  bool _isLoading = false;
  String? _error;

  // Getters
  List<NotificationModel> get notifications => _notifications;
  List<FriendRequest> get pendingRequests => _pendingRequests;
  List<FriendRequest> get sentRequests => _sentRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get unread count (including friend requests)
  int get unreadCount =>
      _notifications.where((notif) => !notif.isRead).length +
      _pendingRequests.length; // Pending requests are always "unread"

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

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Fetch notifications (general + friend requests)
  Future<void> fetchNotifications(String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      debugPrint(
        '🔔 [NotificationsProvider] Fetching notifications for user: $userId',
      );

      // Fetch general notifications
      final data = await _apiClient.getNotifications(userId: userId);

      debugPrint(
        '🔔 [NotificationsProvider] Raw response type: ${data.runtimeType}',
      );
      debugPrint(
        '🔔 [NotificationsProvider] Raw response length: ${data.length}',
      );
      debugPrint('🔔 [NotificationsProvider] Raw response data: $data');

      _notifications = data.map((json) {
        debugPrint('🔔 [NotificationsProvider] Parsing notification: $json');
        return NotificationModel.fromJson(json);
      }).toList();

      debugPrint(
        '🔔 [NotificationsProvider] Parsed ${_notifications.length} notifications',
      );

      // Sort by date (newest first)
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Fetch pending friend requests (received)
      try {
        final pendingData = await _apiClient.getPendingRequests(userId: userId);
        _pendingRequests = pendingData
            .map((json) => FriendRequest.fromJson(json))
            .toList();
        debugPrint(
          '🔔 [NotificationsProvider] Fetched ${_pendingRequests.length} pending requests',
        );
      } catch (e) {
        debugPrint(
          '🔔 [NotificationsProvider] ⚠️ Error fetching pending requests: $e',
        );
        _pendingRequests = [];
      }

      // Fetch sent friend requests
      try {
        final sentData = await _apiClient.getSentRequests(userId: userId);
        _sentRequests = sentData
            .map((json) => FriendRequest.fromJson(json))
            .toList();
        debugPrint(
          '🔔 [NotificationsProvider] Fetched ${_sentRequests.length} sent requests',
        );
      } catch (e) {
        debugPrint(
          '🔔 [NotificationsProvider] ⚠️ Error fetching sent requests: $e',
        );
        _sentRequests = [];
      }

      debugPrint('🔔 [NotificationsProvider] ✅ Successfully fetched all data');

      _setLoading(false);
    } on ApiException catch (e) {
      debugPrint('🔔 [NotificationsProvider] ❌ ApiException: ${e.message}');
      _setError(e.message);
      _setLoading(false);
    } catch (e, stackTrace) {
      debugPrint('🔔 [NotificationsProvider] ❌ Error: ${e.toString()}');
      debugPrint('🔔 [NotificationsProvider] ❌ StackTrace: $stackTrace');
      _setError('Failed to fetch notifications: ${e.toString()}');
      _setLoading(false);
    }
  }

  /// Accept friend request from notification
  Future<bool> acceptFriendRequest(
    String friendshipId,
    String userId,
    BuildContext context,
  ) async {
    try {
      _setError(null);

      await _apiClient.acceptFriendRequest(
        friendshipId: friendshipId,
        userId: userId,
      );

      // Refresh all data
      await fetchNotifications(userId);

      if (context.mounted) {
        showInAppNotification(
          context,
          title: "Success",
          message: "Friend request accepted",
          type: "success",
        );
      }

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      if (context.mounted) {
        showInAppNotification(
          context,
          title: "Error",
          message: e.message,
          type: "error",
        );
      }
      return false;
    } catch (e) {
      _setError('Failed to accept friend request: ${e.toString()}');
      if (context.mounted) {
        showInAppNotification(
          context,
          title: "Error",
          message: "Failed to accept request",
          type: "error",
        );
      }
      return false;
    }
  }

  /// Reject friend request from notification
  Future<bool> rejectFriendRequest(
    String friendshipId,
    String userId,
    BuildContext context,
  ) async {
    try {
      _setError(null);

      await _apiClient.rejectFriendRequest(
        friendshipId: friendshipId,
        userId: userId,
      );

      // Refresh all data
      await fetchNotifications(userId);

      if (context.mounted) {
        showInAppNotification(
          context,
          title: "Rejected",
          message: "Friend request rejected",
          type: "info",
        );
      }

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

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      // TODO: Implement markNotificationsRead endpoint in backend
      // await _apiClient.markNotificationsRead(userId: userId);

      // Update local state optimistically
      _notifications = _notifications
          .map(
            (n) => NotificationModel(
              id: n.id,
              type: n.type,
              message: n.message,
              userId: n.userId,
              username: n.username,
              profilePicId: n.profilePicId,
              metadata: n.metadata,
              createdAt: n.createdAt,
              isRead: true,
            ),
          )
          .toList();

      notifyListeners();
    } catch (e) {
      print('Failed to mark all as read: $e');
    }
  }

  /// Refresh notifications
  Future<void> refresh(String userId) async {
    await fetchNotifications(userId);
  }

  /// Show in-app notification using SnackBar
  void showInAppNotification(
    BuildContext context, {
    required String title,
    required String message,
    required String type,
  }) {
    Color backgroundColor;
    IconData icon;

    switch (type) {
      case 'success':
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'error':
        backgroundColor = Colors.red;
        icon = Icons.error;
        break;
      case 'info':
      default:
        backgroundColor = Colors.blue;
        icon = Icons.info;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(message, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
