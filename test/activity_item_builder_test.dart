import 'package:flutter_test/flutter_test.dart';
import 'package:prism/models/activity_item.dart';
import 'package:prism/models/friend_model.dart';
import 'package:prism/models/notification_model.dart';

NotificationModel _notification({
  required String id,
  required String message,
  String type = 'friend_request_received',
  DateTime? createdAt,
}) {
  return NotificationModel(
    id: id,
    type: type,
    message: message,
    createdAt: createdAt ?? DateTime(2026, 6, 1, 12),
    isRead: false,
  );
}

FriendRequest _receivedRequest({
  required String friendshipId,
  required String username,
  DateTime? createdAt,
}) {
  return FriendRequest(
    friendshipId: friendshipId,
    userId: 'user-$username',
    username: username,
    status: 'pending',
    requesterId: 'user-$username',
    receiverId: 'me',
    createdAt: createdAt ?? DateTime(2026, 6, 1, 13),
  );
}

void main() {
  group('ActivityItemBuilder.build', () {
    test('merges notifications, sent, and received requests', () {
      final activities = ActivityItemBuilder.build(
        notifications: [
          _notification(id: '1', message: 'You shared 3 photos'),
        ],
        sentRequests: [
          _receivedRequest(friendshipId: 's1', username: 'alice'),
        ],
        receivedRequests: [
          _receivedRequest(friendshipId: 'r1', username: 'bob'),
        ],
      );

      expect(activities, hasLength(3));
      expect(
        activities.map((a) => a.type).toSet(),
        equals({
          ActivityItemType.notification,
          ActivityItemType.requestSent,
          ActivityItemType.requestReceived,
        }),
      );
    });

    test('deduplicates friend-request notifications when live request exists',
        () {
      final activities = ActivityItemBuilder.build(
        notifications: [
          _notification(
            id: 'dup',
            message: 'bob requested to follow you',
          ),
        ],
        sentRequests: const [],
        receivedRequests: [
          _receivedRequest(friendshipId: 'r1', username: 'bob'),
        ],
      );

      expect(activities, hasLength(1));
      expect(activities.single.type, ActivityItemType.requestReceived);
      expect(activities.single.title, contains('bob'));
    });

    test('uses current user profile pic for You-prefixed notifications', () {
      final activities = ActivityItemBuilder.build(
        notifications: [
          _notification(id: '1', message: 'You shared 2 photos'),
        ],
        sentRequests: const [],
        receivedRequests: const [],
        currentUserProfilePicId: 'my-pic',
      );

      expect(activities.single.image, 'my-pic');
    });

    test('sorts activities newest first', () {
      final activities = ActivityItemBuilder.build(
        notifications: [
          _notification(
            id: 'old',
            message: 'Older event',
            createdAt: DateTime(2026, 5, 1),
          ),
        ],
        sentRequests: const [],
        receivedRequests: [
          _receivedRequest(
            friendshipId: 'r1',
            username: 'bob',
            createdAt: DateTime(2026, 6, 9),
          ),
        ],
      );

      expect(activities.first.type, ActivityItemType.requestReceived);
      expect(activities.last.type, ActivityItemType.notification);
    });
  });

  group('ActivityItemBuilder.groupByTimeBucket', () {
    test('groups items into time buckets', () {
      final now = DateTime.now();
      final activities = [
        ActivityItem(
          id: 'today',
          date: now,
          type: ActivityItemType.notification,
          title: 'Today',
          data: _notification(id: 'today', message: 'Today'),
        ),
        ActivityItem(
          id: 'earlier',
          date: now.subtract(const Duration(days: 40)),
          type: ActivityItemType.notification,
          title: 'Earlier',
          data: _notification(id: 'earlier', message: 'Earlier'),
        ),
      ];

      final grouped = ActivityItemBuilder.groupByTimeBucket(activities);

      expect(grouped[ActivityTimeBucket.today], hasLength(1));
      expect(grouped[ActivityTimeBucket.earlier], hasLength(1));
      expect(grouped[ActivityTimeBucket.yesterday], isEmpty);
    });
  });
}
