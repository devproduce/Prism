import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/screens/collection_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final galleryProvider = Provider.of<GalleryProvider>(context);

    // Calculate counts
    final favouriteCount = galleryProvider.favouriteImages.length;
    final archivedCount = galleryProvider.archivedImages.length;
    final binCount = galleryProvider.binImages.length;

    // Get preview images (first one for cover)
    final favPreview = galleryProvider.favouriteImages.isNotEmpty
        ? galleryProvider.favouriteImages.first
        : null;
    final archPreview = galleryProvider.archivedImages.isNotEmpty
        ? galleryProvider.archivedImages.first
        : null;
    final binPreview = galleryProvider.binImages.isNotEmpty
        ? galleryProvider.binImages.first
        : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Collections', style: PrismTextStyles.h2),
        backgroundColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        children: [
          _buildCollectionCard(
            context,
            title: 'Favourites',
            count: favouriteCount,
            previewImage: favPreview,
            icon: Icons.favorite_rounded,
            gradient: PrismColors.sunsetGlow,
            onTap: () => _navigateToDetail(context, 'Favourites'),
          ),
          const SizedBox(height: 16),
          _buildCollectionCard(
            context,
            title: 'Archived',
            count: archivedCount,
            previewImage: archPreview,
            icon: Icons.archive_rounded,
            gradient: LinearGradient(colors: [Colors.amber.shade300, Colors.orange.shade400]),
            onTap: () => _navigateToDetail(context, 'Archived'),
          ),
          const SizedBox(height: 16),
          _buildCollectionCard(
            context,
            title: 'Bin',
            count: binCount,
            previewImage: binPreview,
            icon: Icons.delete_rounded,
            gradient: LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade600]),
            onTap: () => _navigateToDetail(context, 'Bin'),
          ),
          const SizedBox(height: 100), // Space for nav bar
        ],
      ),
    );
  }

  void _navigateToDetail(BuildContext context, String title) {
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
    dynamic previewImage,
    required IconData icon,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: 24,
        child: SizedBox(
          height: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image or Gradient
              if (previewImage != null)
                CachedNetworkImage(
                  imageUrl: previewImage.image.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  memCacheWidth: 600,
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(gradient: gradient),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(gradient: gradient),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(gradient: gradient),
                ),

              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.8),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          title,
                          style: PrismTextStyles.h3.copyWith(color: Colors.white),
                        ),
                        Text(
                          '$count items',
                          style: PrismTextStyles.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.8),
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
