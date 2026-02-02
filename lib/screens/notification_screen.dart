import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/models/friend_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

import 'package:prism/widgets/notification_card.dart';
import 'package:prism/widgets/notification_section_header.dart';
import 'package:prism/widgets/empty_state_widget.dart';
import 'package:prism/widgets/shimmer_placeholder.dart';
import 'package:prism/models/notification_model.dart';

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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text(
                'ACTIVITY LOG',
                style: PrismTextStyles.h3.copyWith(
                  letterSpacing: 1.5,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PrismColors.white.withValues(alpha: 0.9),
                ),
              ),
              centerTitle: true,
              backgroundColor: PrismColors.voidBlack,
              elevation: 0,
              pinned: true,
              floating: true,
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.done_all_rounded,
                    color: PrismColors.white.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  tooltip: 'Mark all as read',
                  onPressed: userId == null
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          Provider.of<NotificationsProvider>(
                            context,
                            listen: false,
                          ).markAllAsRead(userId);
                        },
                ),
              ],
            ),
          ];
        },
        body: Consumer<NotificationsProvider>(
          builder: (context, provider, child) {
            // Loading State
            if (provider.isLoading && provider.notifications.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ShimmerLayouts.listItems(count: 8),
              );
            }

            // Error State
            if (provider.error != null && provider.notifications.isEmpty) {
              return EmptyStateWidget.error(
                message: provider.error,
                onRetry: () {
                  if (userId != null) {
                    provider.fetchNotifications(userId);
                  }
                },
              );
            }

            // Empty State
            if (provider.pendingRequests.isEmpty &&
                provider.sentRequests.isEmpty &&
                provider.notifications.isEmpty) {
              return EmptyStateWidget.noNotifications();
            }

            // Group Notifications by Date for nicer display
            final logs = List<NotificationModel>.from(provider.notifications);
            logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            final today = <NotificationModel>[];
            final yesterday = <NotificationModel>[];
            final earlier = <NotificationModel>[];

            final now = DateTime.now();
            for (var log in logs) {
              final diff = now.difference(log.createdAt).inDays;
              if (diff == 0 && log.createdAt.day == now.day) {
                today.add(log);
              } else if (diff == 1 ||
                  (diff == 0 && log.createdAt.day != now.day)) {
                yesterday.add(log);
              } else {
                earlier.add(log);
              }
            }

            return RefreshIndicator(
              color: PrismColors.prismYellow,
              backgroundColor: PrismColors.surfaceGray,
              onRefresh: () async {
                if (userId != null) {
                  await provider.fetchNotifications(userId);
                }
              },
              child: CustomScrollView(
                slivers: [
                  // SECTION: RECEIVED REQUESTS (Action Required)
                  if (provider.pendingRequests.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: NotificationSectionHeader(
                        title: 'Pending Requests',
                      ),
                    ),
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

                  // SECTION: SENT REQUESTS (Informational)
                  if (provider.sentRequests.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: NotificationSectionHeader(title: 'Sent Requests'),
                    ),
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

                  // SECTION: TODAY
                  if (today.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: NotificationSectionHeader(title: 'Today'),
                    ),
                    _buildLogSliverList(today, userId ?? ''),
                  ],

                  // SECTION: YESTERDAY
                  if (yesterday.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: NotificationSectionHeader(title: 'Yesterday'),
                    ),
                    _buildLogSliverList(yesterday, userId ?? ''),
                  ],

                  // SECTION: EARLIER
                  if (earlier.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: NotificationSectionHeader(title: 'Earlier'),
                    ),
                    _buildLogSliverList(earlier, userId ?? ''),
                  ],

                  // Bottom Spacing
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogSliverList(
    List<NotificationModel> notifications,
    String userId,
  ) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final isLast = index == notifications.length - 1;
        return Column(
          children: [
            NotificationCard(
              notification: notifications[index],
              currentUserId: userId,
            ),
            // Subtle separator
            if (!isLast)
              Divider(
                height: 1,
                indent: 72,
                color: PrismColors.white.withValues(alpha: 0.05),
              ),
          ],
        );
      }, childCount: notifications.length),
    );
  }

  // Custom widget for FriendRequests to match NotificationCard style
  Widget _buildFriendRequestCard(
    FriendRequest request,
    NotificationsProvider provider,
    String? userId,
    bool isReceived,
  ) {
    if (!isReceived) {
      // Sent requests style (Quieter)
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            _buildAvatar(request.profilePictureUrl, request.username),
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
                        const TextSpan(text: 'Request sent to '),
                        TextSpan(
                          text: request.username,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    request.timeAgo,
                    style: PrismTextStyles.bodySmall.copyWith(
                      color: PrismColors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Pending',
                style: TextStyle(
                  color: PrismColors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Received requests style (High Priority Card)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark card
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
              _buildAvatar(
                request.profilePictureUrl,
                request.username,
                radius: 24,
              ),
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
                            text: request.username,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: ' sent you a friend request.',
                            style: TextStyle(
                              color: PrismColors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.timeAgo,
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
                    if (userId != null) {
                      provider.rejectFriendRequest(
                        request.friendshipId,
                        userId,
                        context,
                      );
                    }
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
                    if (userId != null) {
                      provider.acceptFriendRequest(
                        request.friendshipId,
                        userId,
                        context,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String url, String username, {double radius = 20}) {
    if (url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
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
        errorWidget: (context, url, error) =>
            _buildFallbackAvatar(username, radius),
      );
    }
    return _buildFallbackAvatar(username, radius);
  }

  Widget _buildFallbackAvatar(String username, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[800],
      child: Text(
        username.isNotEmpty ? username.substring(0, 1).toUpperCase() : '?',
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
}
