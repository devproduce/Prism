import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/models/sharing_models.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_media_preview.dart';

/// Review-page block for photos where CV detected no faces (landscapes, objects, etc.).
class NoFaceReviewSection extends StatelessWidget {
  final List<BatchImage> images;
  final void Function(String imageId) onImageTap;
  final String? Function(String? url) fixUrl;

  const NoFaceReviewSection({
    super.key,
    required this.images,
    required this.onImageTap,
    required this.fixUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final isDesktop = screenWidth > 900;
    final isTablet = screenWidth > 600;

    const contentMaxWidth = 800.0;
    final horizontalInset = isDesktop
        ? (screenWidth - contentMaxWidth).clamp(16.0, double.infinity) / 2
        : 16.0;
    final thumbSize = isDesktop ? 108.0 : (isTablet ? 100.0 : 88.0);

    final sharingProvider = Provider.of<SharingProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final batchRecipientCount = sharingProvider.batchRecipientUserIds.length;
    final canBulkSend = sharingProvider.canSendNoFaceToAll;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalInset, 12, horizontalInset, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: contentMaxWidth),
          child: Material(
            color: Colors.transparent,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(isTablet ? 20 : 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isTablet ? 20 : 18),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            PrismColors.surfaceGray,
                            PrismColors.surfaceGray.withValues(alpha: 0.92),
                            PrismColors.voidBlack.withValues(alpha: 0.35),
                          ],
                        ),
                        border: Border.all(
                          color: PrismColors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      color: PrismColors.electricCyan,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 20 : 16,
                      isTablet ? 20 : 16,
                      isTablet ? 20 : 16,
                      isTablet ? 18 : 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SectionHeader(count: images.length),
                        const SizedBox(height: 16),
                        _SendToAllTile(
                          isChecked: sharingProvider.sendNoFaceToAll,
                          isEnabled: canBulkSend,
                          recipientCount: batchRecipientCount,
                          onChanged: canBulkSend
                              ? (value) {
                                  HapticFeedback.selectionClick();
                                  sharingProvider.setSendNoFaceToAll(value);
                                }
                              : null,
                        ),
                        if (!canBulkSend) ...[
                          const SizedBox(height: 12),
                          _HintBanner(
                            message: batchRecipientCount == 0
                                ? 'No friends were detected in this batch. Tap a photo to choose recipients.'
                                : 'You can also assign recipients individually below.',
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Text(
                              'PHOTOS',
                              style: PrismTextStyles.bodySmall.copyWith(
                                color: PrismColors.secondaryText,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Tap to assign',
                              style: PrismTextStyles.bodySmall.copyWith(
                                color: PrismColors.secondaryText,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: thumbSize + 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(width: isTablet ? 12 : 10),
                            itemBuilder: (context, index) {
                              final image = images[index];
                              final recipientCount = sharingProvider
                                  .recipientCountForImage(image.id);
                              final imageUrl =
                                  fixUrl(image.url ?? image.thumbUrl);
                              final isSignedUrl = imageUrl
                                      ?.contains('X-Amz-Signature') ??
                                  false;
                              final headers = isSignedUrl
                                  ? null
                                  : {
                                      'Authorization':
                                          'Bearer ${authProvider.token}',
                                    };

                              return _NoFaceThumbnail(
                                imageUrl: imageUrl,
                                thumbSize: thumbSize,
                                recipientCount: recipientCount,
                                httpHeaders: headers,
                                mediaType: image.mediaType,
                                onTap: () => onImageTap(image.id),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final int count;

  const _SectionHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: PrismColors.electricCyan.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: PrismColors.electricCyan.withValues(alpha: 0.25),
            ),
          ),
          child: const Icon(
            Icons.photo_filter_rounded,
            color: PrismColors.electricCyan,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'No faces detected',
                      style: PrismTextStyles.h3.copyWith(fontSize: 17),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: PrismColors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: PrismColors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      '$count ${count == 1 ? 'photo' : 'photos'}',
                      style: PrismTextStyles.bodySmall.copyWith(
                        color: PrismColors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'These shots have no people, so Prism cannot auto-match friends. Choose who should receive them.',
                style: PrismTextStyles.bodySmall.copyWith(
                  color: PrismColors.secondaryText,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SendToAllTile extends StatelessWidget {
  final bool isChecked;
  final bool isEnabled;
  final int recipientCount;
  final ValueChanged<bool>? onChanged;

  const _SendToAllTile({
    required this.isChecked,
    required this.isEnabled,
    required this.recipientCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = recipientCount == 0
        ? 'Share with everyone detected in this batch'
        : recipientCount == 1
            ? 'Share with 1 friend detected in this batch'
            : 'Share with all $recipientCount friends in this batch';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled && onChanged != null
            ? () => onChanged!(!isChecked)
            : null,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isChecked
                ? PrismColors.prismYellow.withValues(alpha: 0.08)
                : PrismColors.inputGray.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isChecked
                  ? PrismColors.prismYellow.withValues(alpha: 0.4)
                  : PrismColors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isChecked
                      ? PrismColors.prismYellow.withValues(alpha: 0.18)
                      : PrismColors.white.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.groups_rounded,
                  size: 18,
                  color: isEnabled
                      ? PrismColors.prismYellow
                      : PrismColors.secondaryText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send to all',
                      style: PrismTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isEnabled
                            ? PrismColors.white
                            : PrismColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: PrismTextStyles.bodySmall.copyWith(
                        color: PrismColors.secondaryText,
                        height: 1.3,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isChecked,
                onChanged: isEnabled ? onChanged : null,
                activeThumbColor: PrismColors.prismYellow,
                activeTrackColor: PrismColors.prismYellow.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  final String message;

  const _HintBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PrismColors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PrismColors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 16,
            color: PrismColors.electricCyan.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: PrismTextStyles.bodySmall.copyWith(
                color: PrismColors.secondaryText,
                height: 1.35,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFaceThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double thumbSize;
  final int recipientCount;
  final Map<String, String>? httpHeaders;
  final String mediaType;
  final VoidCallback onTap;

  const _NoFaceThumbnail({
    required this.imageUrl,
    required this.thumbSize,
    required this.recipientCount,
    required this.httpHeaders,
    required this.mediaType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAssigned = recipientCount > 0;

    return Semantics(
      button: true,
      label: isAssigned
          ? 'No-face photo, shared with $recipientCount ${recipientCount == 1 ? 'person' : 'people'}. Tap to edit.'
          : 'No-face photo, no recipients selected. Tap to choose.',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isAssigned
                            ? PrismColors.prismYellow.withValues(alpha: 0.7)
                            : PrismColors.white.withValues(alpha: 0.12),
                        width: isAssigned ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl != null)
                          PrismMediaPreview(
                            imageUrl: imageUrl!,
                            mediaType: mediaType,
                            width: thumbSize,
                            height: thumbSize,
                            fit: BoxFit.cover,
                            placeholderColor: PrismColors.inputGray,
                            httpHeaders: httpHeaders,
                          )
                        else
                          ColoredBox(
                            color: PrismColors.inputGray,
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: PrismColors.secondaryText,
                              size: thumbSize * 0.35,
                            ),
                          ),
                        if (!isAssigned)
                          Container(
                            color: Colors.black.withValues(alpha: 0.18),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.person_add_alt_1_rounded,
                              color: Colors.white.withValues(alpha: 0.75),
                              size: 22,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isAssigned)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: PrismColors.prismYellow,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$recipientCount',
                          style: PrismTextStyles.bodySmall.copyWith(
                            color: PrismColors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: thumbSize,
              child: Text(
                isAssigned ? 'Assigned' : 'Unassigned',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PrismTextStyles.bodySmall.copyWith(
                  color: isAssigned
                      ? PrismColors.prismYellow
                      : PrismColors.secondaryText,
                  fontSize: 10,
                  fontWeight: isAssigned ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
