import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/notification_card.dart';
import 'package:prism/widgets/empty_state_widget.dart';
import 'package:prism/models/notification_model.dart';
import 'package:prism/services/local_notification_store.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalNotifications();
  }

  Future<void> _loadLocalNotifications() async {
    final notifications = await LocalNotificationStore.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    Icons.delete_sweep_rounded,
                    color: PrismColors.white.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  tooltip: 'Clear All',
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await LocalNotificationStore.clearAll();
                    _loadLocalNotifications();
                  },
                ),
              ],
            ),
          ];
        },
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: PrismColors.prismYellow))
            : _notifications.isEmpty
                ? EmptyStateWidget.noNotifications()
                : RefreshIndicator(
                    color: PrismColors.prismYellow,
                    backgroundColor: PrismColors.surfaceGray,
                    onRefresh: _loadLocalNotifications,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 32),
                      itemCount: _notifications.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        indent: 72,
                        color: PrismColors.white.withValues(alpha: 0.05),
                      ),
                      itemBuilder: (context, index) {
                        return NotificationCard(
                          notification: _notifications[index],
                          currentUserId: 'local_user', // Local mode mostly doesn't care
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
