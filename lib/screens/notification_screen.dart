import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/models/friend_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/widgets/gradient_scaffold.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/theme/colors.dart';

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
    final theme = Theme.of(context);
    final userId = Provider.of<AuthProvider>(context).currentUser?.userId;
    final isDark = theme.brightness == Brightness.dark;



    return GradientScaffold(
      appBar: AppBar(
        title: Text(
          'Activity',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.done_all, color: theme.colorScheme.primary),
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
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFCE76C)),
            );
          }

          if (provider.error != null && provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load notifications',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: userId == null
                        ? null
                        : () {
                            provider.fetchNotifications(userId);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFCE76C),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // REQUESTS RECEIVED Section
              if (provider.pendingRequests.isNotEmpty) ...[
                _buildSectionHeader('REQUESTS RECEIVED', context),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final request = provider.pendingRequests[index];
                    return _buildFriendRequestCard(
                      request,
                      provider,
                      userId,
                      true,
                      context,
                    );
                  }, childCount: provider.pendingRequests.length),
                ),
              ],

              // REQUESTS SENT Section
              if (provider.sentRequests.isNotEmpty) ...[
                _buildSectionHeader('REQUESTS SENT', context),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final request = provider.sentRequests[index];
                    return _buildFriendRequestCard(
                      request,
                      provider,
                      userId,
                      false,
                      context,
                    );
                  }, childCount: provider.sentRequests.length),
                ),
              ],

              // RECENT Section
              if (provider.notifications.isNotEmpty) ...[
                _buildSectionHeader('RECENT', context),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final notification = provider.notifications[index];
                    return _buildRecentNotificationCard(notification, context);
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
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 64,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey[400],
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

  Widget _buildSectionHeader(String title, BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
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
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            backgroundImage: request.profilePictureUrl.isNotEmpty
                ? CachedNetworkImageProvider(request.profilePictureUrl)
                : null,
            child: request.profilePictureUrl.isEmpty
                ? Text(
                    request.username.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFFCE76C),
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
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  request.timeAgo,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
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
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: theme.colorScheme.error,
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
                      color: Color(0xFFFCE76C),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Pending',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentNotificationCard(notification, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: notification.isRead
                  ? Colors.transparent
                  : const Color(0xFFFCE76C),
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
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  notification.timeAgo,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
