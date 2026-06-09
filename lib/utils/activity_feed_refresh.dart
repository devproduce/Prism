import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/providers/activity_feed_provider.dart';
import 'package:prism/utils/globals.dart';

/// Mirrors web `prism-new-notification` â€” refreshes feed when push arrives.
class ActivityFeedRefresh {
  ActivityFeedRefresh._();

  static Future<void> refreshFromPush() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      final auth = context.read<AuthProvider>();
      final user = auth.currentUser;
      if (user == null) return;

      final feed = context.read<ActivityFeedProvider>();
      final friends = context.read<FriendsProvider>();
      feed.setUserContext(profilePicId: user.profilePicId);
      await feed.refetch(user.userId);
      await friends.syncFriendshipsIfStale(user.userId, force: true);
    } catch (e) {
      debugPrint('ActivityFeedRefresh failed: $e');
    }
  }
}
