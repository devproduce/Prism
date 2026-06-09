import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/notification_card.dart';
import 'package:prism/widgets/empty_state_widget.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:prism/providers/auth_provider.dart';

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
    await provider.fetchNotifications(auth.currentUser!.userId);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDesktop = media.size.width > 900;
    final horizontalInset = isDesktop
        ? (media.size.width - 800).clamp(16.0, double.infinity) / 2
        : 0.0;

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
                      onPressed: provider.activityFeedNotifications.isEmpty
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              final userId =
                                  context.read<AuthProvider>().currentUser?.userId;
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
          builder: (context, notificationsProvider, authProvider, _) {
            if (notificationsProvider.isLoading &&
                notificationsProvider.activityFeedNotifications.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: PrismColors.prismYellow),
              );
            }

            if (notificationsProvider.error != null &&
                notificationsProvider.activityFeedNotifications.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        notificationsProvider.error!,
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
            final items = notificationsProvider.activityFeedNotifications;

            if (items.isEmpty) {
              return EmptyStateWidget.noNotifications();
            }

            return RefreshIndicator(
              color: PrismColors.prismYellow,
              backgroundColor: PrismColors.surfaceGray,
              onRefresh: _loadNotifications,
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  horizontalInset,
                  0,
                  horizontalInset,
                  media.padding.bottom + 32,
                ),
                itemCount: items.length,
                separatorBuilder: (context, index) {
                  final type = items[index].type;
                  if (type == 'retroactive_share_prompt' ||
                      type == 'contact_found_in_batch') {
                    return const SizedBox(height: 4);
                  }
                  return Divider(
                    height: 1,
                    indent: isDesktop ? 88 : 72,
                    color: PrismColors.white.withValues(alpha: 0.05),
                  );
                },
                itemBuilder: (context, index) {
                  final notification = items[index];
                  return NotificationCard(
                    key: ValueKey(notification.id),
                    notification: notification,
                    currentUserId: userId,
                    onDismiss: () {
                      if (mounted) setState(() {});
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
