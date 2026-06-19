import 'package:flutter_test/flutter_test.dart';
import 'package:prism/models/batch_review_partition.dart';
import 'package:prism/models/sharing_models.dart';

void main() {
  const selfId = '756d4db1-0cb3-4502-8258-7f81b1119ef7';
  const friendId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
  const img1 = 'img-unknown-rep-1';
  const img2 = 'img-unknown-rep-2';
  const img3 = 'img-friend-match';
  const img4 = 'img-unmapped-empty';

  BatchStatusResponse buildFixture() {
    return BatchStatusResponse.fromJson({
      'batch_id': 'batch-test',
      'status': 'completed',
      'shared_by': selfId,
      'auto_clean': false,
      'recipients': [
        {
          'user_id': selfId,
          'username': 'Justin Bieber',
          'count': 3,
        },
      ],
      'contacts': [],
      'unknowns': [
        {
          'face_id': 'face-a',
          'representative_image_id': img1,
          'count': 1,
        },
        {
          'face_id': 'face-b',
          'representative_image_id': img2,
          'count': 1,
        },
      ],
      'images': [
        {
          'id': img1,
          'image_url': 'https://example.com/1.jpg',
          'detected_faces': [
            {'user_id': selfId, 'face_id': 'self-face-1'},
          ],
        },
        {
          'id': img2,
          'image_url': 'https://example.com/2.jpg',
          'detected_faces': [
            {'user_id': selfId, 'face_id': 'self-face-2'},
          ],
        },
        {
          'id': img3,
          'image_url': 'https://example.com/3.jpg',
          'detected_faces': [
            {'user_id': friendId, 'face_id': 'friend-face'},
          ],
        },
        {
          'id': img4,
          'image_url': 'https://example.com/4.jpg',
          'detected_faces': [],
        },
      ],
    });
  }

  Set<String> gridImageIds(BatchReviewPartition partition) {
    return {
      ...partition.friendImages.values.expand((list) => list.map((i) => i.id)),
      ...partition.assignImages.map((i) => i.id),
      ...partition.noFaceImages.map((i) => i.id),
    };
  }

  group('BatchReviewPartition.fromBatch', () {
    test('places every image in exactly one grid bucket', () {
      final batch = buildFixture();
      final partition = BatchReviewPartition.fromBatch(
        batch: batch,
        currentUserId: selfId,
        friendUserIds: {friendId},
      );

      expect(partition.allImages.length, 4);
      expect(gridImageIds(partition).length, 4);
      for (final image in partition.allImages) {
        expect(gridImageIds(partition), contains(image.id));
      }
    });

    test('puts unknown representative photos in assign, not orphaned', () {
      final batch = buildFixture();
      final partition = BatchReviewPartition.fromBatch(
        batch: batch,
        currentUserId: selfId,
        friendUserIds: {friendId},
      );

      final assignIds = partition.assignImages.map((i) => i.id).toSet();
      expect(assignIds, contains(img1));
      expect(assignIds, contains(img2));
      expect(partition.unknowns.length, 2);
    });

    test('does not create friend bucket for self even when API recipients include self', () {
      final batch = buildFixture();
      final partition = BatchReviewPartition.fromBatch(
        batch: batch,
        currentUserId: selfId,
        friendUserIds: {selfId, friendId},
      );

      expect(partition.friendImages.containsKey(selfId), isFalse);
      expect(
        partition.friendImages[friendId]?.map((i) => i.id).toList(),
        [img3],
      );
    });

    test('self-only CV matches land in assign, not friend groups', () {
      final batch = buildFixture();
      final partition = BatchReviewPartition.fromBatch(
        batch: batch,
        currentUserId: selfId,
        friendUserIds: {friendId},
      );

      final friendGridIds = partition.friendImages.values
          .expand((list) => list.map((i) => i.id))
          .toSet();
      expect(friendGridIds, isNot(contains(img1)));
      expect(friendGridIds, isNot(contains(img2)));
    });

    test('invite unknown count does not remove photos from assign grid', () {
      final batch = buildFixture();
      final partition = BatchReviewPartition.fromBatch(
        batch: batch,
        currentUserId: selfId,
        friendUserIds: {friendId},
      );

      expect(partition.unknowns.length, 2);
      expect(partition.assignImages.length, greaterThanOrEqualTo(2));
    });
  });
}
