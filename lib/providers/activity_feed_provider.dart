import 'package:flutter/material.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/activity_item.dart';
import 'package:prism/models/friend_model.dart';
import 'package:prism/models/notification_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prism/utils/in_app_notification.dart';

/// Unified activity feed state - ports notifications-context.tsx merge logic.
class ActivityFeedProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<NotificationModel> _notifications = [];
  List<FriendRequest> _receivedRequests = [];
  List<FriendRequest> _sentRequests = [];
  List<ActivityItem> _activities = [];
  String? _currentUserProfilePicId;

  bool _isLoading = false;
  String? _error;

  List<NotificationModel> get notifications => _notifications;

  List<ActivityItem> get activities => _activities;

  List<FriendRequest> get receivedRequests => _receivedRequests;
  List<FriendRequest> get sentRequests => _sentRequests;

  bool get isLoading => _isLoading;
  String? get error => _error;

  int get unreadCount =>
      _notifications.where((n) => !n.isRead).length + _receivedRequests.length;

  List<FriendRequest> friendRequestsPreview({int limit = 3}) {
    if (_receivedRequests.length <= limit) {
      return List<FriendRequest>.from(_receivedRequests);
    }
    return _receivedRequests.sublist(0, limit);
  }

  Map<ActivityTimeBucket, List<ActivityItem>> get groupedActivities =>
      ActivityItemBuilder.groupByTimeBucket(_activities);

  void setUserContext({String? profilePicId}) {
    if (_currentUserProfilePicId == profilePicId) return;
    _currentUserProfilePicId = profilePicId;
    _rebuildActivities();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _rebuildActivities() {
    _activities = ActivityItemBuilder.build(
      notifications: _notifications,
      sentRequests: _sentRequests,
      receivedRequests: _receivedRequests,
      currentUserProfilePicId: _currentUserProfilePicId,
    );
  }

  Future<bool> requestPermissions() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> refetch(String userId) async {

    try {
      _setLoading(true);
      _setError(null);

      final results = await Future.wait<List<dynamic>>([
        _apiClient.getNotifications(),
        _apiClient.getPendingRequests(),
        _apiClient.getSentRequests(),
      ]);

      final notificationData = results[0];
      final pendingData = results[1];
      final sentData = results[2];

      _notifications = notificationData
          .map((json) => NotificationModel.fromJson(json))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _notifications = _notifications
          .where((n) => !(n.type == 'retroactive_share_prompt' && n.isRead))
          .toList();

      _receivedRequests =
          pendingData.map((json) => FriendRequest.fromJson(json)).toList();

      _sentRequests =
          sentData.map((json) => FriendRequest.fromJson(json)).toList();

      _rebuildActivities();
      _setLoading(false);
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
    } catch (e) {
      _setError('Failed to fetch activity feed: ${e.toString()}');
      _setLoading(false);
    }
  }


  Future<bool> acceptFriendRequest(
    String friendshipId,
    String userId,
    BuildContext context,
  ) async {
    try {
      _setError(null);
      _optimisticallyRemoveReceivedRequest(friendshipId);

      await _apiClient.acceptFriendRequest(
        friendshipId: friendshipId,
      );

      await refetch(userId);

      if (context.mounted) {
        InAppNotification.show(
          context,
          title: 'Success',
          message: 'Friend request accepted',
          type: 'success',
        );
      }
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      await refetch(userId);
      if (context.mounted) {
        InAppNotification.show(
          context,
          title: 'Error',
          message: e.message,
          type: 'error',
        );
      }
      return false;
    } catch (e) {
      _setError('Failed to accept friend request: ${e.toString()}');
      await refetch(userId);
      if (context.mounted) {
        InAppNotification.show(
          context,
          title: 'Error',
          message: 'Failed to accept request',
          type: 'error',
        );
      }
      return false;
    }
  }

  Future<bool> rejectFriendRequest(
    String friendshipId,
    String userId,
    BuildContext context,
  ) async {
    try {
      _setError(null);
      _optimisticallyRemoveReceivedRequest(friendshipId);

      await _apiClient.rejectFriendRequest(
        friendshipId: friendshipId,
      );

      await refetch(userId);

      if (context.mounted) {
        InAppNotification.show(
          context,
          title: 'Rejected',
          message: 'Friend request rejected',
          type: 'info',
        );
      }
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      await refetch(userId);
      return false;
    } catch (e) {
      _setError('Failed to reject friend request: ${e.toString()}');
      await refetch(userId);
      return false;
    }
  }

  void _optimisticallyRemoveReceivedRequest(String friendshipId) {
    _receivedRequests.removeWhere((r) => r.friendshipId == friendshipId);
    _rebuildActivities();
    notifyListeners();
  }

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;

    final current = _notifications[index];
    _notifications[index] = NotificationModel(
      id: current.id,
      type: current.type,
      message: current.message,
      userId: current.userId,
      username: current.username,
      profilePicId: current.profilePicId,
      resourceId: current.resourceId,
      metadata: current.metadata,
      createdAt: current.createdAt,
      isRead: true,
    );
    _rebuildActivities();
    notifyListeners();
  }

  Future<bool> markAsReadSingle(
    String notificationId,
    String userId, {
    bool removeRetroactiveFromFeed = false,
  }) async {
    try {
      _setError(null);
      await _apiClient.markNotificationReadSingle(
        notificationId: notificationId,
      );

      if (removeRetroactiveFromFeed ||
          _notifications.any(
            (n) =>
                n.id == notificationId && n.type == 'retroactive_share_prompt',
          )) {
        _notifications.removeWhere((n) => n.id == notificationId);
      } else {
        markAsRead(notificationId);
        return true;
      }

      _rebuildActivities();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to mark notification read: ${e.toString()}');
      return false;
    }
  }

  Future<bool> acceptRetroactiveShare({
    required BuildContext context,
    required String userId,
    required String friendId,
    required List<String> contactFaceIds,
    required List<String> unknownFaceIds,
    required List<String> imageIds,
  }) async {
    try {
      _setError(null);
      final response = await _apiClient.acceptRetroactiveShare(
        friendId: friendId,
        contactFaceIds: contactFaceIds,
        unknownFaceIds: unknownFaceIds,
        imageIds: imageIds,
      );

      if (context.mounted) {
        final count = response['shared_count'] as int? ?? imageIds.length;
        InAppNotification.show(
          context,
          title: 'Memories shared',
          message:
              '$count ${count == 1 ? 'photo' : 'photos'} linked with your friend.',
          type: 'success',
        );
      }
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      if (context.mounted) {
        InAppNotification.show(
          context,
          title: 'Could not share memories',
          message: e.message.contains('No valid pending')
              ? 'These memories were already shared or are no longer available.'
              : e.message,
          type: 'info',
        );
      }
      return false;
    } catch (e) {
      _setError('Failed to accept retroactive share: ${e.toString()}');
      if (context.mounted) {
        InAppNotification.show(
          context,
          title: 'Error',
          message: 'Failed to share memories. Please try again.',
          type: 'error',
        );
      }
      return false;
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _apiClient.markNotificationsRead();

      _notifications = _notifications
          .map(
            (n) => NotificationModel(
              id: n.id,
              type: n.type,
              message: n.message,
              userId: n.userId,
              username: n.username,
              profilePicId: n.profilePicId,
              resourceId: n.resourceId,
              metadata: n.metadata,
              createdAt: n.createdAt,
              isRead: true,
            ),
          )
          .toList();

      _rebuildActivities();
      notifyListeners();
    } on ApiException catch (e) {
      _setError(e.message);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to mark all as read: $e');
    }
  }
}
