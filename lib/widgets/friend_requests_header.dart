import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:prism/models/friend_model.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
/// Ports the optional friend-requests header from activity-feed.tsx.
class FriendRequestsHeader extends StatelessWidget {
  final int friendRequestsCount;
  final List<FriendRequest> friendRequestsPreview;
  final VoidCallback onTap;

  const FriendRequestsHeader({
    super.key,
    required this.friendRequestsCount,
    required this.friendRequestsPreview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (friendRequestsCount <= 0) return const SizedBox.shrink();

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  _PreviewAvatars(
                    count: friendRequestsCount,
                    preview: friendRequestsPreview,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Friend Requests',
                          style: PrismTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: PrismColors.white,
                          ),
                        ),
                        Text(
                          'Approve or ignore',
                          style: PrismTextStyles.bodySmall.copyWith(
                            color: PrismColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: PrismColors.prismYellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: PrismColors.secondaryText,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Divider(
          height: 1,
          color: PrismColors.white.withValues(alpha: 0.1),
        ),
      ],
    );
  }
}

class _PreviewAvatars extends StatelessWidget {
  final int count;
  final List<FriendRequest> preview;

  const _PreviewAvatars({
    required this.count,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    if (preview.isEmpty) {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: PrismColors.inputGray,
        child: Icon(Icons.person, color: PrismColors.secondaryText, size: 20),
      );
    }

    if (count == 1) {
      return _RequestAvatar(request: preview.first, radius: 20);
    }

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: _RequestAvatar(request: preview.first, radius: 14),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: PrismColors.surfaceGray,
                shape: BoxShape.circle,
                border: Border.all(color: PrismColors.voidBlack, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                '+${count - 1}',
                style: const TextStyle(
                  color: PrismColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestAvatar extends StatelessWidget {
  final FriendRequest request;
  final double radius;

  const _RequestAvatar({
    required this.request,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = request.profilePictureUrl;
    if (imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: PrismColors.inputGray,
        backgroundImage: CachedNetworkImageProvider(imageUrl),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: PrismColors.inputGray,
      child: Text(
        request.username.isNotEmpty
            ? request.username[0].toUpperCase()
            : '?',
        style: TextStyle(
          color: PrismColors.prismYellow,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }
}
