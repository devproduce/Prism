import 'package:flutter/material.dart';
import 'package:prism/models/sharing_models.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/responsive_helper.dart';
import 'package:prism/widgets/prism_media_preview.dart';

/// Three-column square thumbnail grid for review accordion bodies.
class ReviewPhotoGrid extends StatelessWidget {
  final List<BatchImage> images;
  final void Function(String imageId) onImageTap;
  final String? Function(String? url) fixUrl;
  final Map<String, String>? Function(String? url)? headersForUrl;
  final int Function(String imageId)? recipientCountForImage;

  const ReviewPhotoGrid({
    super.key,
    required this.images,
    required this.onImageTap,
    required this.fixUrl,
    this.headersForUrl,
    this.recipientCountForImage,
  });

  static double _spacing(BuildContext context) {
    return ResponsiveHelper.isSmallScreen(context) ? 6 : 8;
  }

  static int _columns(BuildContext context) {
    final width = ResponsiveHelper.screenWidth(context);
    if (width >= ResponsiveHelper.tablet) return 4;
    if (width < ResponsiveHelper.smallScreen) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columns(context);
        final spacing = _spacing(context);
        final cellSize =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: images.map((image) {
            final recipientCount = recipientCountForImage?.call(image.id) ?? 0;
            final imageUrl = fixUrl(image.url ?? image.thumbUrl);

            return SizedBox(
              width: cellSize,
              height: cellSize,
              child: _ReviewPhotoTile(
                image: image,
                imageUrl: imageUrl,
                httpHeaders: headersForUrl?.call(imageUrl),
                recipientCount: recipientCount,
                onTap: () => onImageTap(image.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ReviewPhotoTile extends StatelessWidget {
  final BatchImage image;
  final String? imageUrl;
  final Map<String, String>? httpHeaders;
  final int recipientCount;
  final VoidCallback onTap;

  const _ReviewPhotoTile({
    required this.image,
    required this.imageUrl,
    required this.httpHeaders,
    required this.recipientCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null
                ? PrismMediaPreview(
                    imageUrl: imageUrl!,
                    mediaType: image.mediaType,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholderColor: PrismColors.inputGray,
                    httpHeaders: httpHeaders,
                  )
                : ColoredBox(
                    color: PrismColors.inputGray,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: PrismColors.destructiveRed,
                        size: 28,
                      ),
                    ),
                  ),
          ),
          if (recipientCount > 0)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: PrismColors.prismYellow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, size: 12, color: PrismColors.black),
                    const SizedBox(width: 3),
                    Text(
                      '$recipientCount',
                      style: PrismTextStyles.bodySmall.copyWith(
                        color: PrismColors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
