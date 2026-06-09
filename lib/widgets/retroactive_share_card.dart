import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/models/notification_model.dart';
import 'package:prism/providers/activity_feed_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/constants.dart';

class RetroactiveShareCard extends StatelessWidget {
  final NotificationModel notification;
  final String currentUserId;
  final VoidCallback onDismiss;

  const RetroactiveShareCard({
    super.key,
    required this.notification,
    required this.currentUserId,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isTablet = media.size.width > 600;
    final horizontalPad = media.size.width > 900
        ? (media.size.width - 800).clamp(16.0, double.infinity) / 2
        : 16.0;
    final thumbSize = isTablet ? 88.0 : 80.0;

    final metadata = notification.metadata ?? {};
    final imageIds = (metadata['image_ids'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final contactFaceIds = (metadata['contact_face_ids'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final unknownFaceIds = (metadata['unknown_face_ids'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final friendId = metadata['friend_id']?.toString() ?? '';
    final friendUsername = notification.username ??
        metadata['friend_username']?.toString() ??
        'your friend';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 8),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 18 : 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          border: const Border(
            left: BorderSide(color: PrismColors.prismYellow, width: 3),
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: PrismColors.prismYellow,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You & $friendUsername are friends!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'We found ${imageIds.length} shared ${imageIds.length == 1 ? 'memory' : 'memories'} with them.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (imageIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: thumbSize,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageIds.length > 3 ? 3 : imageIds.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final imageId = imageIds[index];
                    final isLast = index == 2 && imageIds.length > 3;
                    return Stack(
                      children: [
                        Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl:
                                  '${ApiConstants.baseUrl}/images/$imageId',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (isLast)
                          Container(
                            width: thumbSize,
                            height: thumbSize,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '+${imageIds.length - 3} more',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.share_rounded, size: 14, color: Colors.black),
                  label: const Text(
                    'Prism Share',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PrismColors.prismYellow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final provider = context.read<ActivityFeedProvider>();
                    final ok = await provider.acceptRetroactiveShare(
                      context: context,
                      userId: currentUserId,
                      friendId: friendId,
                      contactFaceIds: contactFaceIds,
                      unknownFaceIds: unknownFaceIds,
                      imageIds: imageIds,
                    );
                    if (ok) {
                      await provider.markAsReadSingle(
                        notification.id,
                        currentUserId,
                        removeRetroactiveFromFeed: true,
                      );
                      onDismiss();
                    }
                  },
                ),
                TextButton(
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    await context.read<ActivityFeedProvider>().markAsReadSingle(
                          notification.id,
                          currentUserId,
                          removeRetroactiveFromFeed: true,
                        );
                    onDismiss();
                  },
                  child: Text(
                    'Skip',
                    style: PrismTextStyles.bodySmall.copyWith(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
