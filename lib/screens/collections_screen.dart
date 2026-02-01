import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/screens/collection_detail_screen.dart';
import 'package:prism/widgets/prism_media_preview.dart';
import 'package:prism/models/gallery_image_model.dart';

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final galleryProvider = Provider.of<GalleryProvider>(context);

    // Responsive values
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 12.0 : 16.0;
    final cardHeight = (screenWidth * 0.4).clamp(140.0, 180.0);

    // Calculate counts
    final favouriteCount = galleryProvider.favouriteImages.length;
    final binCount = galleryProvider.binImages.length;

    // Get preview images (first one for cover)
    final favPreview = galleryProvider.favouriteImages.isNotEmpty
        ? galleryProvider.favouriteImages.first
        : null;
    final binPreview = binCount > 0 ? galleryProvider.binImages.first : null;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text('Collections', style: PrismTextStyles.h2),
        backgroundColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 8,
        ),
        children: [
          _buildCollectionCard(
            context,
            title: 'Favourites',
            count: favouriteCount,
            previewImage: favPreview,
            icon: Icons.favorite_rounded,
            gradient: PrismColors.sunsetGlow,
            height: cardHeight,
            onTap: () => _navigateToDetail(context, 'Favourites'),
          ).animate().fadeIn().moveX(begin: -20, end: 0),

          const SizedBox(height: 16),
          _buildCollectionCard(
            context,
            title: 'Bin',
            count: binCount,
            previewImage: binPreview,
            icon: Icons.delete_rounded,
            gradient: LinearGradient(
              colors: [
                PrismColors.secondaryText.withValues(alpha: 0.6),
                PrismColors.secondaryText.withValues(alpha: 0.8),
              ],
            ),
            height: cardHeight,
            onTap: () => _navigateToDetail(context, 'Bin'),
          ).animate().fadeIn(delay: 200.ms).moveX(begin: -20, end: 0),
          // Additional space for bottom nav bar if needed
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _navigateToDetail(BuildContext context, String title) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollectionDetailScreen(title: title),
      ),
    );
  }

  Widget _buildCollectionCard(
    BuildContext context, {
    required String title,
    required int count,
    GalleryImage? previewImage,
    required IconData icon,
    required LinearGradient gradient,
    required double height,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: PrismCard(
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image or Gradient
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: previewImage != null
                    ? PrismMediaPreview(
                        imageUrl: previewImage.image.imageUrl,
                        mediaType: previewImage.image.mediaType,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholderColor: PrismColors.surfaceGray,
                      )
                    : Container(decoration: BoxDecoration(gradient: gradient)),
              ),

              // Gradient Overlay for Text Readability
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      PrismColors.voidBlack.withValues(alpha: 0.3),
                      PrismColors.voidBlack.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PrismColors.glassFrostedWhite,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: PrismColors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, color: PrismColors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          title,
                          style: PrismTextStyles.h3.copyWith(
                            color: PrismColors.white,
                          ),
                        ),
                        Text(
                          '$count items',
                          style: PrismTextStyles.bodySmall.copyWith(
                            color: PrismColors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
