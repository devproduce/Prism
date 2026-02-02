import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

class SeeAllAlbumsCard extends StatelessWidget {
  final List<AssetEntity> covers;
  final int albumCount;
  final VoidCallback onTap;

  const SeeAllAlbumsCard({
    super.key,
    required this.covers,
    required this.albumCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the count to display on the last item
    // We show 3 albums outside, and 3 thumbnails inside the card before the 4th one.
    // So displayed = 3 (outside) + 3 (inside) = 6.
    // Remaining = Total - 6.
    // If remaining is less than 0, we just show empty or correct count.
    // Actually, simple logic: Total - 3 (outside) is the number of items *represented* by this card.
    // But the overlay usually means "more items".
    // If the card represents, say, 17 items. We show 4 thumbnails.
    // The +N usually means "N more besides these 4".
    // But here the user wants the card to say "+13" which likely matches "Total - 3 (outside) - 3 (inside card before this one) = 13"?
    // Example: Total 17. 3 outside. 14 inside folder.
    // We show 4 thumbnails.
    // 1st, 2nd, 3rd. 4th has overlay.
    // The overlay should cover the rest.
    // Rest = 14 - 3 = 11.
    // Wait, the user image shows "+13".
    // Maybe they just want the count of "All other albums".
    // Or maybe `albumCount - 3` (total view all count).
    // Let's assume standard "+N" logic: N = Total items not shown in this specific grid cell.
    // But this is a folder.
    // Let's use `albumCount - 3` (total inside) for now? No, that would be 14.
    // If I use `albumCount - 6` (hidden ones).

    // Let's implement dynamic sizing for the grid
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14), // Spacing from card edge
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24), // Card corner radius
          color: PrismColors.surfaceGray, // Dark background
          border: Border.all(
            color: PrismColors.white.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildThumbnailItem(0)),
                  const SizedBox(width: 8), // Gap
                  Expanded(child: _buildThumbnailItem(1)),
                ],
              ),
            ),
            const SizedBox(height: 8), // Gap
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildThumbnailItem(2)),
                  const SizedBox(width: 8), // Gap
                  Expanded(child: _buildThumbnailItem(3, isLast: true)),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(),
    );
  }

  Widget _buildThumbnailItem(int index, {bool isLast = false}) {
    // If we don't have enough covers, show empty placeholder
    if (index >= covers.length) {
      return Container(
        decoration: BoxDecoration(
          color: PrismColors.voidBlack.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
      );
    }

    final asset = covers[index];

    // Calculate count for the last item overlay
    // We assume effective albums shown previously on home screen is 3.
    // Inside this card, we show 4 items (indices 0, 1, 2, 3).
    // The last item (index 3) has the text.
    // So visible items so far = 3 (Home) + 3 (Card clean) + 1 (Card overlay) = 7.
    // Remaining hidden items = Total - 7.
    int remainingCount = albumCount - 7;
    if (remainingCount < 0) remainingCount = 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16), // Rounded individual images
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: asset.thumbnailDataWithSize(
              const ThumbnailSize.square(200),
            ),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Image.memory(snapshot.data!, fit: BoxFit.cover);
              }
              return Container(color: PrismColors.surfaceGray);
            },
          ),

          // Overlay for the last item if there are more albums
          if (isLast && remainingCount > 0)
            Container(
              color: Colors.black.withOpacity(0.6), // Dim overlay
              child: Center(
                child: Text(
                  '+$remainingCount',
                  style: PrismTextStyles.h2.copyWith(
                    color: PrismColors.white,
                    fontSize: 24, // Prominent size
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
