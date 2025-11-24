import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:prism/models/notification_model.dart';
import 'package:prism/utils/theme.dart';

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
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context);
    final notificationsProvider = Provider.of<NotificationsProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primaryText(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: AppTheme.headlineStyle(
            context,
          ).copyWith(fontSize: size.width * 0.05),
        ),
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
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: AppTheme.primaryAccent,
                  fontSize: size.width * 0.032,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: notificationsProvider.isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent),
            )
          : notificationsProvider.error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: size.width * 0.15,
                    color: Colors.red,
                  ),
                  SizedBox(height: size.height * 0.02),
                  Text(
                    notificationsProvider.error!,
                    style: TextStyle(
                      color: AppTheme.secondaryText(context),
                      fontSize: size.width * 0.04,
                    ),
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
                    size: size.width * 0.2,
                    color: AppTheme.tertiaryText(context),
                  ),
                  SizedBox(height: size.height * 0.02),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: AppTheme.secondaryText(context),
                      fontSize: size.width * 0.045,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: size.height * 0.01),
                  Text(
                    'We\'ll notify you when something arrives',
                    style: TextStyle(
                      color: AppTheme.tertiaryText(context),
                      fontSize: size.width * 0.035,
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
              color: AppTheme.primaryAccent,
              backgroundColor: AppTheme.primaryBackground(context),
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: size.height * 0.01),
                itemCount: notificationsProvider.notifications.length,
                itemBuilder: (context, index) {
                  final notification =
                      notificationsProvider.notifications[index];
                  return _buildNotificationItem(
                    notification,
                    notificationsProvider,
                    authProvider,
                    size,
                  );
                },
              ),
            ),
    );
  }

  Widget _buildNotificationItem(
    NotificationModel notification,
    NotificationsProvider provider,
    AuthProvider authProvider,
    Size size,
  ) {
    return InkWell(
      onTap: () {
        if (!notification.isRead) {
          provider.markAsRead(notification.id);
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: AppTheme.horizontalPadding(context),
          vertical: size.height * 0.005,
        ),
        padding: EdgeInsets.all(size.width * 0.035),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.transparent
              : AppTheme.primaryAccent.withOpacity(0.05),
          border: Border(
            left: BorderSide(
              color: notification.isRead
                  ? Colors.transparent
                  : AppTheme.primaryAccent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Picture / Icon
            Container(
              width: size.width * 0.12,
              height: size.width * 0.12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getNotificationColor(
                  notification.type,
                ).withOpacity(0.15),
              ),
              child: notification.profilePictureUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        notification.profilePictureUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            _getNotificationIcon(notification.type),
                            color: _getNotificationColor(notification.type),
                            size: size.width * 0.06,
                          );
                        },
                      ),
                    )
                  : Icon(
                      _getNotificationIcon(notification.type),
                      color: _getNotificationColor(notification.type),
                      size: size.width * 0.06,
                    ),
            ),
            SizedBox(width: size.width * 0.03),
            // Notification content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message
                  Text(
                    notification.message,
                    style: TextStyle(
                      color: AppTheme.primaryText(context),
                      fontSize: size.width * 0.038,
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: size.height * 0.005),
                  // Time
                  Text(
                    notification.timeAgo,
                    style: TextStyle(
                      color: AppTheme.tertiaryText(context),
                      fontSize: size.width * 0.032,
                    ),
                  ),
                  // Actions for friend requests
                  if (notification.type == 'friend_request')
                    Padding(
                      padding: EdgeInsets.only(top: size.height * 0.015),
                      child: Row(
                        children: [
                          // Accept button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (authProvider.currentUser != null) {
                                  final success = await provider
                                      .acceptFriendRequest(
                                        notification.id,
                                        authProvider.currentUser!.userId,
                                      );

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? 'Friend request accepted!'
                                              : provider.error ??
                                                    'Failed to accept',
                                        ),
                                        backgroundColor: success
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryAccent,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: size.height * 0.012,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Accept',
                                style: TextStyle(
                                  fontSize: size.width * 0.035,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: size.width * 0.02),
                          // Reject button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                if (authProvider.currentUser != null) {
                                  final success = await provider
                                      .rejectFriendRequest(
                                        notification.id,
                                        authProvider.currentUser!.userId,
                                      );

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? 'Friend request rejected'
                                              : provider.error ??
                                                    'Failed to reject',
                                        ),
                                        backgroundColor: success
                                            ? Colors.orange
                                            : Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.secondaryText(
                                  context,
                                ),
                                side: BorderSide(
                                  color: AppTheme.darkDotInactive,
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: size.height * 0.012,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Reject',
                                style: TextStyle(
                                  fontSize: size.width * 0.035,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Unread indicator
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryAccent,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add;
      case 'image_share':
        return Icons.photo;
      case 'comment':
        return Icons.comment;
      case 'like':
        return Icons.favorite;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'friend_request':
        return AppTheme.primaryAccent;
      case 'image_share':
        return Colors.blue;
      case 'comment':
        return Colors.orange;
      case 'like':
        return Colors.red;
      default:
        return AppTheme.primaryAccent;
    }
  }
}
