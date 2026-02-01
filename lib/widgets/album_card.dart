import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

/// A sleek album card widget with glassmorphic design.
/// Shows album cover, title, and asset count with optional selection state.
class AlbumCard extends StatelessWidget {
  final String title;
  final int assetCount;
  final Uint8List? thumbnail;
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
    this.thumbnail,
    this.onTap,
    this.onLongPress,
    this.width = 140,
    this.height = 160,
    this.isSelected = false,
    this.selectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child:
          AnimatedContainer(
                duration: 150.ms,
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: PrismColors.prismYellow, width: 3)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: PrismColors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isSelected ? 13 : 16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background image or placeholder
                      if (thumbnail != null)
                        Image.memory(
                          thumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      else
                        _buildPlaceholder(),

                      // Gradient overlay for text readability
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                PrismColors.black.withValues(alpha: 0.7),
                              ],
                              stops: const [0.4, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Album info at bottom
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: PrismTextStyles.bodyMedium.copyWith(
                                color: PrismColors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$assetCount items',
                              style: PrismTextStyles.bodySmall.copyWith(
                                color: PrismColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Selection checkmark
                      if (selectionMode)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: AnimatedContainer(
                            duration: 150.ms,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? PrismColors.prismYellow
                                  : PrismColors.black.withValues(alpha: 0.5),
                              border: Border.all(
                                color: isSelected
                                    ? PrismColors.prismYellow
                                    : PrismColors.white.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: isSelected
                                  ? PrismColors.black
                                  : Colors.transparent,
                            ),
                          ),
                        ),

                      // Subtle border (only when not selected)
                      if (!isSelected)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: PrismColors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1, 1),
                duration: 300.ms,
              ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: PrismColors.surfaceGray,
      child: const Center(
        child: Icon(
          Icons.photo_library_outlined,
          color: PrismColors.secondaryText,
          size: 32,
        ),
      ),
    );
  }
}
