import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/models/notification_model.dart';
import 'package:prism/screens/user_profile_screen.dart';
import 'package:prism/screens/friends_screen.dart';
import 'package:prism/widgets/retroactive_share_card.dart';
import 'package:prism/widgets/contact_found_batch_card.dart';

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final String currentUserId;
  final VoidCallback? onDismiss;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.currentUserId,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    switch (notification.type) {
      case 'retroactive_share_prompt':
        return RetroactiveShareCard(
          notification: notification,
          currentUserId: currentUserId,
          onDismiss: onDismiss ?? () {},
        );
      case 'contact_found_in_batch':
        return ContactFoundBatchCard(
          notification: notification,
          currentUserId: currentUserId,
          onDismiss: onDismiss ?? () {},
        );
      default:
        return _DefaultNotificationRow(
          notification: notification,
          onTap: () => _handleRoute(context),
        );
    }
  }

  void _handleRoute(BuildContext context) {
    final type = notification.type;
    final r = notification.metadata?['route'];
    final senderId =
        notification.metadata?['sender_id'] ?? notification.userId;
    final senderUsername =
        notification.metadata?['sender_username'] ?? notification.username;

    if (type == 'batch_received' || r == '/friend_profile') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            userId: senderId ?? '',
            username: senderUsername ?? 'Friend',
          ),
        ),
      );
    } else if (type == 'friend_request_received' || r == '/notifications') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const FriendsScreen(
            openRequestsDirectly: true,
          ),
        ),
      );
    } else if (r != null && r.isNotEmpty) {
      Navigator.of(context).pushNamed(r);
    }
  }
}

class _DefaultNotificationRow extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _DefaultNotificationRow({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContextIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.message,
                    style: PrismTextStyles.bodyMedium.copyWith(
                      color: PrismColors.white,
                      fontWeight: FontWeight.w400,
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
    );
  }

  Widget _buildContextIcon() {
    if (notification.type.contains('friend') ||
        notification.username != null) {
      return _buildAvatar(radius: 20);
    }

    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case 'batch_share':
      case 'batch_received':
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
            valueColor:
                AlwaysStoppedAnimation<Color>(PrismColors.prismYellow),
          ),
        ),
        errorWidget: (context, url, error) => _buildFallbackAvatar(radius),
      );
    }
    return _buildFallbackAvatar(radius);
  }

  Widget _buildFallbackAvatar(double radius) {
    final uname = notification.username ??
        notification.metadata?['sender_username'] ??
        '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[800],
      child: Text(
        uname.isNotEmpty ? uname.substring(0, 1).toUpperCase() : '?',
        style: TextStyle(
          color: PrismColors.prismYellow,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
