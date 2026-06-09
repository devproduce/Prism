import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism/models/activity_item.dart';
import 'package:prism/models/friend_model.dart';
import 'package:prism/screens/notification_screen.dart';
import 'package:prism/services/fcm_navigation_service.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/constants.dart';
import 'package:prism/utils/time_ago.dart';
import 'package:prism/widgets/activity_title.dart';
import 'package:prism/widgets/friend_requests_header.dart';
import 'package:prism/widgets/retroactive_share_card.dart';

/// Ports activity-feed.tsx ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â unified grouped activity timeline.
class ActivityFeed extends StatelessWidget {
  final List<ActivityItem> activities;
  final Map<ActivityTimeBucket, List<ActivityItem>> groupedActivities;
  final String currentUserId;
  final bool showFriendRequestsHeader;
  final int friendRequestsCount;
  final List<FriendRequest> friendRequestsPreview;
  final Future<void> Function(String friendshipId)? onAccept;
  final Future<void> Function(String friendshipId)? onDecline;
  final VoidCallback? onNavigateToRequests;
  final VoidCallback? onRetroactiveSuccess;

  const ActivityFeed({
    super.key,
    required this.activities,
    required this.groupedActivities,
    required this.currentUserId,
    this.showFriendRequestsHeader = true,
    this.friendRequestsCount = 0,
    this.friendRequestsPreview = const [],
    this.onAccept,
    this.onDecline,
    this.onNavigateToRequests,
    this.onRetroactiveSuccess,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty && friendRequestsCount == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No new activity',
            style: PrismTextStyles.bodyMedium.copyWith(
              color: PrismColors.secondaryText,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showFriendRequestsHeader && friendRequestsCount > 0)
          FriendRequestsHeader(
            friendRequestsCount: friendRequestsCount,
            friendRequestsPreview: friendRequestsPreview,
            onTap: onNavigateToRequests ??
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(
                        highlightFriendRequests: true,
                      ),
                    ),
                  );
                },
          ),
        for (final bucket in ActivityTimeBucket.ordered) ...[
          if ((groupedActivities[bucket] ?? []).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Text(
                bucket.label,
                style: PrismTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: PrismColors.white,
                ),
              ),
            ),
            ...groupedActivities[bucket]!.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ActivityFeedRow(
                  item: item,
                  currentUserId: currentUserId,
                  onAccept: onAccept,
                  onDecline: onDecline,
                  onRetroactiveSuccess: onRetroactiveSuccess,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _ActivityFeedRow extends StatelessWidget {
  final ActivityItem item;
  final String currentUserId;
  final Future<void> Function(String friendshipId)? onAccept;
  final Future<void> Function(String friendshipId)? onDecline;
  final VoidCallback? onRetroactiveSuccess;

  const _ActivityFeedRow({
    required this.item,
    required this.currentUserId,
    this.onAccept,
    this.onDecline,
    this.onRetroactiveSuccess,
  });

  @override
  Widget build(BuildContext context) {
    if (item.isRetroactiveSharePrompt) {
      final notification = item.notification!;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: RetroactiveShareCard(
          notification: notification,
          currentUserId: currentUserId,
          onDismiss: onRetroactiveSuccess ?? () {},
        ),
      );
    }

    final isContactFound = item.isContactFoundInBatch;

    final canOpenNotification =
        item.type == ActivityItemType.notification && !isContactFound;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isContactFound
            ? () => _openContactSearch(context, item)
            : canOpenNotification
                ? () => _openNotification(context, item)
                : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActivityAvatar(
                profilePicId: item.image,
                name: item.title.split(' ').first,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ActivityTitle(
                      title: item.title,
                      style: PrismTextStyles.bodyMedium.copyWith(
                        color: PrismColors.white,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDistanceToNow(item.date),
                      style: PrismTextStyles.bodySmall.copyWith(
                        color: PrismColors.secondaryText,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TrailingActions(
                item: item,
                onAccept: onAccept,
                onDecline: onDecline,
                onViewContact: isContactFound
                    ? () => _openContactSearch(context, item)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openContactSearch(BuildContext context, ActivityItem item) {
    final notification = item.notification;
    if (notification == null) return;
    FcmNavigationService.handleNotification(notification);
  }

  void _openNotification(BuildContext context, ActivityItem item) {
    final notification = item.notification;
    if (notification == null) return;
    FcmNavigationService.handleNotification(notification);
  }
}

class _TrailingActions extends StatelessWidget {
  final ActivityItem item;
  final Future<void> Function(String friendshipId)? onAccept;
  final Future<void> Function(String friendshipId)? onDecline;
  final VoidCallback? onViewContact;

  const _TrailingActions({
    required this.item,
    this.onAccept,
    this.onDecline,
    this.onViewContact,
  });

  @override
  Widget build(BuildContext context) {
    switch (item.type) {
      case ActivityItemType.requestReceived:
        final friendshipId = item.friendRequest?.friendshipId ?? '';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionIconButton(
              icon: Icons.check_rounded,
              backgroundColor: PrismColors.prismYellow,
              iconColor: PrismColors.black,
              tooltip: 'Confirm',
              onPressed: friendshipId.isEmpty
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      await onAccept?.call(friendshipId);
                    },
            ),
            const SizedBox(width: 4),
            _ActionIconButton(
              icon: Icons.close_rounded,
              backgroundColor: PrismColors.inputGray,
              iconColor: PrismColors.secondaryText,
              tooltip: 'Decline',
              onPressed: friendshipId.isEmpty
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      await onDecline?.call(friendshipId);
                    },
            ),
          ],
        );
      case ActivityItemType.requestSent:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: PrismColors.inputGray,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Pending',
            style: PrismTextStyles.bodySmall.copyWith(
              color: PrismColors.secondaryText,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case ActivityItemType.notification:
        if (item.isContactFoundInBatch) {
          return OutlinedButton(
            onPressed: onViewContact,
            style: OutlinedButton.styleFrom(
              foregroundColor: PrismColors.white,
              side: BorderSide(color: PrismColors.white.withValues(alpha: 0.1)),
              backgroundColor: PrismColors.white.withValues(alpha: 0.05),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              minimumSize: const Size(0, 32),
              shape: const StadiumBorder(),
            ),
            child: const Text('View', style: TextStyle(fontSize: 12)),
          );
        }
        return const SizedBox.shrink();
    }
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ActionIconButton({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }
}

class _ActivityAvatar extends StatelessWidget {
  final String? profilePicId;
  final String name;

  const _ActivityAvatar({
    required this.profilePicId,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = profilePicId != null && profilePicId!.isNotEmpty;
    final imageUrl =
        hasImage ? '${ApiConstants.baseUrl}/images/$profilePicId' : null;

    if (imageUrl != null) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: PrismColors.inputGray,
        backgroundImage: CachedNetworkImageProvider(imageUrl),
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: PrismColors.inputGray,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: PrismColors.prismYellow,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
