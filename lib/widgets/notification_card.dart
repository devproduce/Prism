import 'package:flutter/material.dart';
import 'package:prism/models/notification_model.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final String currentUserId;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive dimensions
    final cardMarginH = screenWidth < 360 ? 12.0 : 16.0;
    final cardPadding = screenWidth < 360 ? 12.0 : 16.0;
    final avatarRadius = screenWidth < 360
        ? 20.0
        : (screenWidth > 600 ? 28.0 : 24.0);
    final buttonSize = screenWidth < 360
        ? 32.0
        : (screenWidth > 600 ? 40.0 : 36.0);
    final iconButtonSize = screenWidth < 360 ? 16.0 : 18.0;
    final messageFontSize = screenWidth < 360
        ? 13.0
        : (screenWidth > 600 ? 15.0 : 14.0);
    final timeFontSize = screenWidth < 360 ? 11.0 : 12.0;

    // Colors from design
    // Theme-aware colors
    final yellowColor = const Color(0xFFFCE76C);
    final cardBackground = isDark
        ? const Color(0xFF2A2A2A)
        : theme.colorScheme.surfaceContainerHighest;
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor = theme.colorScheme.onSurfaceVariant;
    final avatarBgColor = isDark
        ? Colors.grey[800]!
        : theme.colorScheme.surfaceContainerHigh;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (direction) {
          Provider.of<NotificationsProvider>(
            context,
            listen: false,
          ).markAsRead(notification.id);
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: cardMarginH, vertical: 8),
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Avatar or Icon
              _buildAvatar(context, avatarRadius, yellowColor, avatarBgColor),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notification.type == 'friend_request' ||
                        notification.type == 'friend_request_received')
                      RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: primaryTextColor,
                            fontSize: messageFontSize,
                          ),
                          children: [
                            TextSpan(
                              text: notification.username ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        notification.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: primaryTextColor,
                          fontSize: messageFontSize,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 4),
                    Text(
                      notification.timeAgo,
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: timeFontSize,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              if (notification.type == 'friend_request' ||
                  notification.type == 'friend_request_received')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reject Button
                    GestureDetector(
                      onTap: () {
                        Provider.of<NotificationsProvider>(
                          context,
                          listen: false,
                        ).rejectFriendRequest(
                          notification.id,
                          currentUserId,
                          context,
                        );
                      },
                      child: Container(
                        width: buttonSize,
                        height: buttonSize,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: iconButtonSize,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Accept Button
                    GestureDetector(
                      onTap: () {
                        Provider.of<NotificationsProvider>(
                          context,
                          listen: false,
                        ).acceptFriendRequest(
                          notification.id,
                          currentUserId,
                          context,
                        );
                      },
                      child: Container(
                        width: buttonSize,
                        height: buttonSize,
                        decoration: BoxDecoration(
                          color: yellowColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          color: Colors.black,
                          size: iconButtonSize,
                        ),
                      ),
                    ),
                  ],
                )
              else if (notification.type == 'image_share' ||
                  notification.type == 'batch_shared')
                Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: Colors.green,
                    size: iconButtonSize,
                  ),
                )
              else
                // General notification indicator (yellow dot)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: notification.isRead
                        ? Colors.transparent
                        : yellowColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    double radius,
    Color yellowColor,
    Color avatarBgColor,
  ) {
    if (notification.profilePicId != null &&
        notification.profilePicId!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(
          notification.profilePictureUrl,
        ),
        backgroundColor: avatarBgColor,
      );
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundColor: avatarBgColor,
        child: Text(
          notification.username?.substring(0, 1).toUpperCase() ?? '?',
          style: TextStyle(
            color: yellowColor,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.6, // Responsive font size
          ),
        ),
      );
    }
  }
}
