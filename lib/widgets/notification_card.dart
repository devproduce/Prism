import 'package:flutter/material.dart';
import 'package:prism/models/notification_model.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final String currentUserId;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.currentUserId,
  });

  bool get _isRequest =>
      notification.type == 'friend_request' ||
      notification.type == 'friend_request_received';

  @override
  Widget build(BuildContext context) {
    // If it's a request, use the High-Priority Card style
    if (_isRequest) {
      return _buildRequestCard(context);
    }
    // Otherwise, use the Low-Priority List Item style
    return _buildActivityItem(context);
  }

  Widget _buildRequestCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Using a distinct card background for requests to emphasize importance
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    // Requests are handled by buttons, so no Dismissible needed here implicitly
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PrismColors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildAvatar(radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: PrismTextStyles.bodyMedium.copyWith(
                          color: PrismColors.white,
                        ),
                        children: [
                          TextSpan(
                            text: notification.username ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' sent you a friend request.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.timeAgo,
                      style: PrismTextStyles.bodySmall.copyWith(
                        color: PrismColors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  label: 'Decline',
                  isPrimary: false,
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  label: 'Accept',
                  isPrimary: true,
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context) {
    final isUnread = !notification.isRead;

    // Use Dismissible with confirmDismiss to avoid removal-from-tree crash
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(),
      confirmDismiss: (direction) async {
        _markAsRead(context);
        // Return false to snap back, keeping the item in the list (history)
        // This avoids the "Dismissed widget still in tree" error
        return false;
      },
      child: InkWell(
        onTap: () => _markAsRead(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Indicator (Dot)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnread
                      ? PrismColors.prismYellow
                      : Colors.transparent,
                ),
              ),

              // Variable Icon/Avatar based on type
              _buildContextIcon(),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      style: PrismTextStyles.bodyMedium.copyWith(
                        color: isUnread
                            ? PrismColors.white
                            : PrismColors.white.withValues(alpha: 0.7),
                        fontWeight: isUnread
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.timeAgo,
                      style: PrismTextStyles.bodySmall.copyWith(
                        color: PrismColors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextIcon() {
    // If user-related, show avatar
    if (notification.type.contains('friend') || notification.username != null) {
      return _buildAvatar(radius: 20);
    }

    // Otherwise show system icon
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case 'image_share':
      case 'batch_shared':
        iconData = Icons.collections_rounded;
        iconColor = Colors.blueAccent;
        break;
      case 'security':
        iconData = Icons.security_rounded;
        iconColor = Colors.orangeAccent;
        break;
      default:
        iconData = Icons.notifications_none_rounded;
        iconColor = PrismColors.white.withValues(alpha: 0.6);
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 20, color: iconColor),
    );
  }

  Widget _buildAvatar({required double radius}) {
    if (notification.profilePicId != null &&
        notification.profilePicId!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: notification.profilePictureUrl,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundImage: imageProvider,
          backgroundColor: Colors.grey[800],
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[800],
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(PrismColors.prismYellow),
          ),
        ),
        errorWidget: (context, url, error) => _buildFallbackAvatar(radius),
      );
    } else {
      return _buildFallbackAvatar(radius);
    }
  }

  Widget _buildFallbackAvatar(double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[800],
      child: Text(
        notification.username?.substring(0, 1).toUpperCase() ?? '?',
        style: TextStyle(
          color: PrismColors.prismYellow,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? PrismColors.prismYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isPrimary
              ? null
              : Border.all(color: PrismColors.white.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: PrismTextStyles.bodySmall.copyWith(
            color: isPrimary ? Colors.black : PrismColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      color: PrismColors.prismYellow.withValues(
        alpha: 0.2,
      ), // Change to "Read" color
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.done_all_rounded, color: PrismColors.prismYellow),
    );
  }

  void _markAsRead(BuildContext context) {
    if (!notification.isRead) {
      Provider.of<NotificationsProvider>(
        context,
        listen: false,
      ).markAsRead(notification.id);
    }
  }
}
