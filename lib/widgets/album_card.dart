import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

/// A sleek album card widget with glassmorphic design.
/// Shows album cover, title, and asset count with optional selection state.
class AlbumCard extends StatelessWidget {
  final String title;
  final int assetCount;
  final AssetEntity? coverAsset;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double width;
  final double height;
  final bool isSelected;
  final bool selectionMode;

  const AlbumCard({
    super.key,
    required this.title,
    required this.assetCount,
    this.coverAsset,
    this.onTap,
    this.onLongPress,
    this.width = 140,
    this.height = 160,
    this.isSelected = false,
    this.selectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // Premium Design: Soft elevation, no harsh borders (unless selected)
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child:
          AnimatedContainer(
                duration: 200.ms,
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20), // Increased radius
                  color: PrismColors.surfaceGray,
                  border: isSelected
                      ? Border.all(color: PrismColors.prismYellow, width: 2)
                      : Border.all(
                          color: PrismColors.white.withValues(alpha: 0.05),
                          width: 1,
                        ),
                  boxShadow: [
                    if (!isSelected)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isSelected ? 17 : 20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background image
                      if (coverAsset != null)
                        _buildCoverImage(coverAsset!)
                      else
                        _buildPlaceholder(),

                      // Gradient overlay - smoother and deeper for text legibility
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(
                                  0.2,
                                ), // Subtle top shade
                                Colors.black.withOpacity(
                                  0.8,
                                ), // Stronger bottom
                              ],
                              stops: const [0.5, 0.75, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Album info at bottom - Modern Typography
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: PrismTextStyles.bodyMedium.copyWith(
                                color: PrismColors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$assetCount items',
                              style: PrismTextStyles.bodySmall.copyWith(
                                color: PrismColors.secondaryText,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Selection checkmark
                      if (selectionMode)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: AnimatedContainer(
                            duration: 150.ms,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? PrismColors.prismYellow
                                  : PrismColors.black.withOpacity(0.5),
                              border: Border.all(
                                color: isSelected
                                    ? PrismColors.prismYellow
                                    : PrismColors.white.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: isSelected
                                  ? PrismColors.black
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
              .animate(target: isSelected ? 1 : 0)
              .scale(begin: const Offset(1, 1), end: const Offset(0.95, 0.95)),
    );
  }

  Widget _buildCoverImage(AssetEntity asset) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize.square(300)),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        }
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: PrismColors.surfaceGray,
      child: Center(
        child: Icon(
          Icons.photo_library_outlined,
          color: PrismColors.secondaryText.withOpacity(0.5),
          size: 32,
        ),
      ),
    );
  }
}
