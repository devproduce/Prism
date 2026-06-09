import 'package:flutter/material.dart';
import 'package:prism/models/notification_model.dart';
import 'package:prism/screens/friends_screen.dart';
import 'package:prism/screens/home_screen.dart';
import 'package:prism/screens/notification_screen.dart';
import 'package:prism/screens/settings_screen.dart';
import 'package:prism/screens/user_profile_screen.dart';
import 'package:prism/utils/globals.dart';

/// Deep-link routing for FCM payloads and in-app notification taps.
/// Contract: FCM_PayloadUpgrade_Plan.md
class FcmNavigationService {
  FcmNavigationService._();

  static void handle(Map<String, dynamic> data) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final type = data['type']?.toString() ?? '';
    final route = data['route']?.toString() ?? '';
    final routeTab = data['route_tab']?.toString() ?? '';
    final senderId = data['sender_id']?.toString() ?? '';
    final senderUsername = data['sender_username']?.toString() ?? 'Friend';
    final contactName = _contactNameFrom(data);

    switch (type) {
      case 'batch_share':
        _goHome(tabIndex: 0);
        return;
      case 'batch_received':
        _openUserProfile(
          navigator,
          userId: senderId,
          username: senderUsername,
          initialTab: routeTab.isNotEmpty ? routeTab : 'received',
        );
        return;
      case 'friend_request_received':
        _openNotifications(navigator, highlightFriendRequests: true);
        return;
      case 'friend_req_accepted':
        _openUserProfile(
          navigator,
          userId: senderId,
          username: senderUsername,
        );
        return;
      case 'contact_found_in_batch':
        _openFriendsSearch(
          navigator,
          contactName ?? senderUsername,
        );
        return;
      case 'retroactive_share_prompt':
        _openNotifications(navigator);
        return;
      case 'account_deletion':
        navigator.pushNamed('/settings');
        return;
      case 'system_alert':
        _openNotifications(navigator);
        return;
    }

    switch (route) {
      case '/friend_profile':
        _openUserProfile(
          navigator,
          userId: senderId,
          username: senderUsername,
          initialTab: routeTab,
        );
        return;
      case '/notifications':
        _openNotifications(
          navigator,
          highlightFriendRequests: routeTab == 'requests',
        );
        return;
      case '/home':
        _goHome(tabIndex: routeTab == 'gallery' ? 0 : null);
        return;
      case '/settings':
        navigator.push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        return;
      case '/friends':
        _openFriendsSearch(navigator, contactName ?? senderUsername);
        return;
    }

    if (route.isNotEmpty) {
      navigator.pushNamed(route);
    }
  }

  static void handleNotification(NotificationModel notification) {
    final metadata = notification.metadata ?? {};
    handle({
      'type': notification.type,
      'route': metadata['route']?.toString() ?? '',
      'route_tab': metadata['route_tab']?.toString() ?? '',
      'sender_id':
          metadata['sender_id']?.toString() ?? notification.userId ?? '',
      'sender_username':
          metadata['sender_username']?.toString() ??
              notification.username ??
              '',
      'contact_name': metadata['contact_name']?.toString(),
      'resource_id': notification.resourceId ?? '',
    });
  }

  static String? _contactNameFrom(Map<String, dynamic> data) {
    final direct = data['contact_name']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final metadata = data['metadata'];
    if (metadata is Map) {
      final nested = metadata['contact_name']?.toString();
      if (nested != null && nested.isNotEmpty) return nested;
    }
    return null;
  }

  static void _goHome({int? tabIndex}) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final homeState = HomeScreen.homeScreenKey.currentState;
    if (homeState != null) {
      if (tabIndex != null) homeState.switchToTab(tabIndex);
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          key: HomeScreen.homeScreenKey,
          initialNavIndex: tabIndex,
        ),
      ),
    );
  }

  static void _openUserProfile(
    NavigatorState navigator, {
    required String userId,
    required String username,
    String? initialTab,
  }) {
    if (userId.isEmpty) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: userId,
          username: username,
          initialProfileTab: initialTab,
        ),
      ),
    );
  }

  static void _openNotifications(
    NavigatorState navigator, {
    bool highlightFriendRequests = false,
  }) {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => NotificationScreen(
          highlightFriendRequests: highlightFriendRequests,
        ),
      ),
    );
  }

  static void _openFriendsSearch(NavigatorState navigator, String? query) {
    final trimmed = query?.trim();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => FriendsScreen(
          initialSearchQuery: trimmed?.isNotEmpty == true ? trimmed : null,
        ),
      ),
    );
  }
}
