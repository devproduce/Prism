import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/notification_card.dart';
import 'package:prism/widgets/empty_state_widget.dart';
import 'package:prism/widgets/shimmer_placeholder.dart';
import 'package:prism/utils/error_handler.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();

    // Fetch notifications on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final notificationsProvider = Provider.of<NotificationsProvider>(
        context,
        listen: false,
      );

      if (authProvider.currentUser != null) {
        notificationsProvider.fetchNotifications(
          authProvider.currentUser!.userId,
        );
      }
    });
  }

  Future<void> _markAllAsRead(
    NotificationsProvider notificationsProvider,
  ) async {
    HapticFeedback.lightImpact();
    try {
      for (var notification in notificationsProvider.notifications) {
        if (!notification.isRead) {
          notificationsProvider.markAsRead(notification.id);
        }
      }
      if (mounted) {
        ErrorHandler.showSuccessSnackbar(
          context,
          message: 'All notifications marked as read',
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: ErrorHandler.getErrorMessage(e),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final notificationsProvider = Provider.of<NotificationsProvider>(context);

    // Responsive padding
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 12.0 : 16.0;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text('Notifications', style: PrismTextStyles.h2),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: PrismColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (notificationsProvider.notifications.isNotEmpty)
            TextButton(
              onPressed: () => _markAllAsRead(notificationsProvider),
              child: Text(
                'Mark all read',
                style: PrismTextStyles.bodySmall.copyWith(
                  color: PrismColors.prismYellow,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(authProvider, notificationsProvider, horizontalPadding),
    );
  }

  Widget _buildBody(
    AuthProvider authProvider,
    NotificationsProvider notificationsProvider,
    double horizontalPadding,
  ) {
    // Loading state with shimmer
    if (notificationsProvider.isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: ShimmerLayouts.listItems(count: 6),
      );
    }

    // Error state
    if (notificationsProvider.error != null) {
      return EmptyStateWidget.error(
        message: notificationsProvider.error,
        onRetry: () {
          if (authProvider.currentUser != null) {
            notificationsProvider.fetchNotifications(
              authProvider.currentUser!.userId,
            );
          }
        },
      );
    }

    // Empty state
    if (notificationsProvider.notifications.isEmpty) {
      return EmptyStateWidget.noNotifications();
    }

    // Notifications list with pull-to-refresh
    return RefreshIndicator(
      color: PrismColors.prismYellow,
      backgroundColor: PrismColors.surfaceGray,
      onRefresh: () async {
        if (authProvider.currentUser != null) {
          await notificationsProvider.refresh(authProvider.currentUser!.userId);
        }
      },
      child: ListView.separated(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 8,
        ),
        itemCount: notificationsProvider.notifications.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 72,
          color: PrismColors.white.withValues(alpha: 0.1),
        ),
        itemBuilder: (context, index) {
          final notification = notificationsProvider.notifications[index];
          return NotificationCard(
            notification: notification,
            currentUserId: authProvider.currentUser?.userId ?? '',
          );
        },
      ),
    );
  }
}
