import 'package:flutter_test/flutter_test.dart';
import 'package:prism/models/activity_item.dart';
import 'package:prism/models/notification_model.dart';

void main() {
  test('activity feed empty check treats notifications as activity', () {
    final activities = ActivityItemBuilder.build(
      notifications: [
        NotificationModel(
          id: '1',
          type: 'batch_received',
          message: 'Alice shared photos',
          createdAt: DateTime.now(),
          isRead: false,
        ),
      ],
      sentRequests: const [],
      receivedRequests: const [],
    );

    expect(activities, isNotEmpty);
    expect(activities.single.type, ActivityItemType.notification);
  });
}
