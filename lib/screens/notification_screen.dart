import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/activity_feed.dart';
import 'package:prism/widgets/empty_state_widget.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/screens/friends_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotifications());
  }

  Future<void> _loadNotifications() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return;
    final provider = context.read<NotificationsProvider>();
    provider.setUserContext(profilePicId: auth.currentUser!.profilePicId);
    await provider.refetch(auth.currentUser!.userId);
  }

  Future<void> _handleAccept(String friendshipId) async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<NotificationsProvider>();
    final userId = auth.currentUser?.userId;
    if (userId == null || !mounted) return;

    await provider.acceptFriendRequest(friendshipId, userId, context);
    if (!mounted) return;
    await context.read<FriendsProvider>().syncFriendshipsIfStale(userId, force: true);
  }

  Future<void> _handleDecline(String friendshipId) async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<NotificationsProvider>();
    final userId = auth.currentUser?.userId;
    if (userId == null || !mounted) return;

    await provider.rejectFriendRequest(friendshipId, userId, context);
    if (!mounted) return;
    await context.read<FriendsProvider>().syncFriendshipsIfStale(userId, force: true);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDesktop = media.size.width > 900;
    final horizontalInset = isDesktop
        ? (media.size.width - 800).clamp(16.0, double.infinity) / 2
        : 16.0;

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
                Consumer<NotificationsProvider>(
                  builder: (context, provider, _) {
                    return IconButton(
                      icon: Icon(
                        Icons.done_all_rounded,
                        color: PrismColors.white.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      tooltip: 'Mark all read',
                      onPressed: provider.activities.isEmpty
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              final userId = context
                                  .read<AuthProvider>()
                                  .currentUser
                                  ?.userId;
                              if (userId != null) {
                                await provider.markAllAsRead(userId);
                              }
                            },
                    );
                  },
                ),
              ],
            ),
          ];
        },
        body: Consumer2<NotificationsProvider, AuthProvider>(
          builder: (context, provider, authProvider, _) {
            if (provider.isLoading && provider.activities.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: PrismColors.prismYellow),
              );
            }

            if (provider.error != null && provider.activities.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        provider.error!,
                        style: PrismTextStyles.bodyMedium.copyWith(
                          color: PrismColors.destructiveRed,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final userId = authProvider.currentUser?.userId ?? '';
            final hasContent =
                provider.activities.isNotEmpty || provider.receivedRequests.isNotEmpty;

            if (!hasContent) {
              return EmptyStateWidget.noNotifications();
            }

            return RefreshIndicator(
              color: PrismColors.prismYellow,
              backgroundColor: PrismColors.surfaceGray,
              onRefresh: _loadNotifications,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalInset,
                  8,
                  horizontalInset,
                  media.padding.bottom + 32,
                ),
                children: [
                  ActivityFeed(
                    activities: provider.activities,
                    groupedActivities: provider.groupedActivities,
                    currentUserId: userId,
                    showFriendRequestsHeader: true,
                    friendRequestsCount: provider.receivedRequests.length,
                    friendRequestsPreview: provider.friendRequestsPreview(),
                    onAccept: _handleAccept,
                    onDecline: _handleDecline,
                    onNavigateToRequests: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FriendsScreen(
                            openRequestsDirectly: true,
                          ),
                        ),
                      );
                    },
                    onRetroactiveSuccess: _loadNotifications,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
