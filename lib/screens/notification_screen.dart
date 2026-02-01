import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/models/friend_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/widgets/prism_button.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch notifications on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUser?.userId;
      if (userId != null) {
        Provider.of<NotificationsProvider>(
          context,
          listen: false,
        ).fetchNotifications(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context).currentUser?.userId;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text('Activity', style: PrismTextStyles.h2),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: PrismColors.prismYellow),
            tooltip: 'Mark all as read',
            onPressed: userId == null
                ? null
                : () {
                    Provider.of<NotificationsProvider>(
                      context,
                      listen: false,
                    ).markAllAsRead(userId);
                  },
            style: IconButton.styleFrom(
              backgroundColor: PrismColors.prismYellow.withOpacity(0.1),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: PrismColors.prismYellow),
            );
          }

          if (provider.error != null && provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: PrismColors.destructiveRed,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load notifications',
                    style: PrismTextStyles.h3.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.error!,
                    style: PrismTextStyles.bodyMedium.copyWith(
                      color: PrismColors.secondaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  PrismButton(
                    text: 'Retry',
                    onPressed: userId == null
                        ? null
                        : () {
                            provider.fetchNotifications(userId);
                          },
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // REQUESTS RECEIVED Section
              if (provider.pendingRequests.isNotEmpty) ...[
                _buildSectionHeader('REQUESTS RECEIVED'),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final request = provider.pendingRequests[index];
                    return _buildFriendRequestCard(
                      request,
                      provider,
                      userId,
                      true,
                    );
                  }, childCount: provider.pendingRequests.length),
                ),
              ],

              // REQUESTS SENT Section
              if (provider.sentRequests.isNotEmpty) ...[
                _buildSectionHeader('REQUESTS SENT'),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final request = provider.sentRequests[index];
                    return _buildFriendRequestCard(
                      request,
                      provider,
                      userId,
                      false,
                    );
                  }, childCount: provider.sentRequests.length),
                ),
              ],

              // RECENT Section
              if (provider.notifications.isNotEmpty) ...[
                _buildSectionHeader('RECENT'),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final notification = provider.notifications[index];
                    return _buildRecentNotificationCard(notification);
                  }, childCount: provider.notifications.length),
                ),
              ],

              // Empty state
              if (provider.pendingRequests.isEmpty &&
                  provider.sentRequests.isEmpty &&
                  provider.notifications.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_off_outlined,
                          size: 64,
                          color: PrismColors.secondaryText,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: PrismTextStyles.h3.copyWith(
                            color: PrismColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title,
          style: PrismTextStyles.bodySmall.copyWith(
            color: PrismColors.secondaryText,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildFriendRequestCard(
    FriendRequest request,
    NotificationsProvider provider,
    String? userId,
    bool isReceived,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: PrismCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: PrismColors.voidBlack,
                backgroundImage: request.profilePictureUrl.isNotEmpty
                    ? CachedNetworkImageProvider(request.profilePictureUrl)
                    : null,
                child: request.profilePictureUrl.isEmpty
                    ? Text(
                        request.username.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: PrismColors.prismYellow,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.username,
                      style: PrismTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.timeAgo,
                      style: PrismTextStyles.bodySmall.copyWith(
                        color: PrismColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              if (isReceived)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reject Button
                    GestureDetector(
                      onTap: () {
                        if (userId != null) {
                          provider.rejectFriendRequest(
                            request.friendshipId,
                            userId,
                            context,
                          );
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: PrismColors.voidBlack,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PrismColors.destructiveRed.withOpacity(0.5),
                          ),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: PrismColors.destructiveRed,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Accept Button
                    GestureDetector(
                      onTap: () {
                        if (userId != null) {
                          provider.acceptFriendRequest(
                            request.friendshipId,
                            userId,
                            context,
                          );
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: PrismColors.prismYellow,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                )
              else
                // Pending label for sent requests
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: PrismColors.voidBlack,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    'Pending',
                    style: PrismTextStyles.bodySmall.copyWith(
                      color: PrismColors.secondaryText,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentNotificationCard(notification) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: PrismCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: notification.isRead
                      ? Colors.transparent
                      : PrismColors.prismYellow,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      style: PrismTextStyles.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }
}
