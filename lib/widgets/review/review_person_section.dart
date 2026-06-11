import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism/models/review_models.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/constants.dart';
import 'package:prism/widgets/review/review_photo_grid.dart';

/// Expandable friend or no-face block on the review screen.
class ReviewPersonSection extends StatelessWidget {
  final ReviewPersonGroup group;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(String imageId) onImageTap;
  final String? Function(String? url) fixUrl;
  final Map<String, String>? Function(String? url)? headersForUrl;
  final int Function(String imageId)? recipientCountForImage;
  final Widget? expandedHeaderExtra;

  const ReviewPersonSection({
    super.key,
    required this.group,
    required this.isExpanded,
    required this.onToggle,
    required this.onImageTap,
    required this.fixUrl,
    this.headersForUrl,
    this.recipientCountForImage,
    this.expandedHeaderExtra,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: PrismColors.surfaceGray,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PrismColors.white.withValues(alpha: 0.08),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToggle();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      _SectionAvatar(group: group),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.displayName,
                              style: PrismTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              group.subtitle ?? group.photoCountLabel,
                              style: PrismTextStyles.bodySmall.copyWith(
                                color: group.subtitle != null
                                    ? PrismColors.secondaryText
                                    : PrismColors.prismYellow,
                                fontWeight: FontWeight.w600,
                                letterSpacing: group.subtitle != null ? 0 : 0.8,
                                fontSize: 11,
                              ),
                            ),
                            if (group.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                group.photoCountLabel,
                                style: PrismTextStyles.bodySmall.copyWith(
                                  color: PrismColors.prismYellow,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: PrismColors.secondaryText,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isExpanded) ...[
              Divider(
                height: 1,
                color: PrismColors.white.withValues(alpha: 0.06),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (expandedHeaderExtra != null) ...[
                      expandedHeaderExtra!,
                      const SizedBox(height: 12),
                    ],
                    ReviewPhotoGrid(
                      images: group.images,
                      onImageTap: onImageTap,
                      fixUrl: fixUrl,
                      headersForUrl: headersForUrl,
                      recipientCountForImage: recipientCountForImage,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionAvatar extends StatelessWidget {
  final ReviewPersonGroup group;

  const _SectionAvatar({required this.group});

  @override
  Widget build(BuildContext context) {
    if (group.isNoFace) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: PrismColors.electricCyan.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: PrismColors.electricCyan.withValues(alpha: 0.25),
          ),
        ),
        child: const Icon(
          Icons.photo_filter_rounded,
          color: PrismColors.electricCyan,
          size: 22,
        ),
      );
    }

    if (group.isAssignRecipients) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: PrismColors.prismYellow.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: PrismColors.prismYellow.withValues(alpha: 0.25),
          ),
        ),
        child: const Icon(
          Icons.person_add_alt_1_rounded,
          color: PrismColors.prismYellow,
          size: 22,
        ),
      );
    }

    final profilePicUrl = group.profilePicId != null
        ? '${ApiConstants.baseUrl}/images/${group.profilePicId}'
        : null;

    return CircleAvatar(
      radius: 22,
      backgroundColor: PrismColors.inputGray,
      backgroundImage:
          profilePicUrl != null ? NetworkImage(profilePicUrl) : null,
      child: profilePicUrl == null
          ? Text(
              _initialFor(group.displayName),
              style: PrismTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: PrismColors.white,
              ),
            )
          : null,
    );
  }

  String _initialFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }
}
