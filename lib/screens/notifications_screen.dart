import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:prism/models/notification_model.dart';

import 'package:prism/widgets/gradient_scaffold.dart';
import 'package:prism/widgets/notification_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();

    // Fetch notifications on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final notificationsProvider = Provider.of<NotificationsProvider>(
        context,
        listen: false,
      );

      if (authProvider.currentUser != null) {
        notificationsProvider.fetchNotifications(
          authProvider.currentUser!.userId,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final notificationsProvider = Provider.of<NotificationsProvider>(context);

    return GradientScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        actions: [
          if (notificationsProvider.notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                // Mark all as read
                for (var notification in notificationsProvider.notifications) {
                  if (!notification.isRead) {
                    notificationsProvider.markAsRead(notification.id);
                  }
                }
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: notificationsProvider.isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : notificationsProvider.error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    notificationsProvider.error!,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : notificationsProvider.notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'ll notify you when something arrives',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                if (authProvider.currentUser != null) {
                  await notificationsProvider.refresh(
                    authProvider.currentUser!.userId,
                  );
                }
              },
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notificationsProvider.notifications.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final notification =
                      notificationsProvider.notifications[index];
                  return NotificationCard(
                    notification: notification,
                    currentUserId: authProvider.currentUser?.userId ?? '',
                  );
                },
              ),
            ),
    );
  }
}
