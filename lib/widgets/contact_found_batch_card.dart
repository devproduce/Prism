import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/models/notification_model.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

class ContactFoundBatchCard extends StatelessWidget {
  final NotificationModel notification;
  final String currentUserId;
  final VoidCallback onDismiss;

  const ContactFoundBatchCard({
    super.key,
    required this.notification,
    required this.currentUserId,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isTablet = media.size.width > 600;
    final horizontalPad = media.size.width > 900
        ? (media.size.width - 800).clamp(16.0, double.infinity) / 2
        : 16.0;

    final metadata = notification.metadata ?? {};
    final targetUsername = notification.username ??
        metadata['username']?.toString() ??
        metadata['target_username']?.toString() ??
        'friend';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 8),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 18 : 16),
        decoration: BoxDecoration(
          color: PrismColors.surfaceGray,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PrismColors.prismYellow.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(notification: notification),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact found in your photos',
                        style: PrismTextStyles.bodySmall.copyWith(
                          color: PrismColors.prismYellow,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@$targetUsername is in your contacts and appeared in a recent upload.',
                        style: PrismTextStyles.bodyMedium.copyWith(height: 1.35),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.timeAgo,
                        style: PrismTextStyles.bodySmall.copyWith(
                          color: PrismColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final provider = context.read<NotificationsProvider>();
                    final ok = await provider.sendFriendRequestFromNotification(
                      context: context,
                      userId: currentUserId,
                      username: targetUsername,
                    );
                    if (ok) {
                      await provider.markAsReadSingle(
                        notification.id,
                        currentUserId,
                      );
                      onDismiss();
                    }
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.black),
                  label: const Text(
                    'Add Friend',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PrismColors.prismYellow,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    await context.read<NotificationsProvider>().markAsReadSingle(
                          notification.id,
                          currentUserId,
                        );
                    onDismiss();
                  },
                  child: Text(
                    'Dismiss',
                    style: PrismTextStyles.bodySmall.copyWith(color: PrismColors.secondaryText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final NotificationModel notification;

  const _Avatar({required this.notification});

  @override
  Widget build(BuildContext context) {
    final radius = MediaQuery.of(context).size.width > 600 ? 26.0 : 24.0;
    if (notification.profilePicId != null && notification.profilePicId!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: PrismColors.inputGray,
        backgroundImage: CachedNetworkImageProvider(notification.profilePictureUrl),
      );
    }
    final initial = (notification.username ?? '?').isNotEmpty
        ? notification.username![0].toUpperCase()
        : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: PrismColors.inputGray,
      child: Text(initial, style: const TextStyle(color: PrismColors.prismYellow)),
    );
  }
}
