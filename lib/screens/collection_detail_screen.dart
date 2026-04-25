import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/models/gallery_image_model.dart';
import 'package:prism/screens/image_viewer_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:prism/widgets/prism_media_preview.dart';
import 'package:prism/widgets/empty_state_widget.dart';
import 'package:prism/widgets/shimmer_placeholder.dart';
import 'package:prism/utils/responsive_helper.dart';

class CollectionDetailScreen extends StatefulWidget {
  final String title;

  const CollectionDetailScreen({super.key, required this.title});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final galleryProvider = Provider.of<GalleryProvider>(context);

    // Get images based on title
    Map<String, List<GalleryImage>> groupedImages;
    switch (widget.title) {
      case 'Favourites':
        groupedImages = galleryProvider.getGroupedImagesByTab('Favourites');
        break;
      case 'Archived':
        groupedImages = galleryProvider.getGroupedImagesByTab('Archived');
        break;
      case 'Bin':
        groupedImages = galleryProvider.getGroupedImagesByTab('Bin');
        break;
      default:
        groupedImages = {};
    }

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text(widget.title, style: PrismTextStyles.h2),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: BackButton(
          color: PrismColors.white,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: galleryProvider.isLoading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: ShimmerLayouts.galleryGrid(
                itemCount: 12,
                crossAxisCount: ResponsiveHelper.galleryGridCount(context),
              ),
            )
          : groupedImages.isEmpty
          ? _buildEmptyState()
          : CustomScrollView(
              slivers: groupedImages.entries.map((entry) {
                return SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child: Text(
                          entry.key,
                          style: PrismTextStyles.h3.copyWith(
                            color: PrismColors.prismYellow,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: ResponsiveHelper.galleryGridCount(
                          context,
                        ),
                        mainAxisSpacing: ResponsiveHelper.spacingS(context),
                        crossAxisSpacing: ResponsiveHelper.spacingS(context),
                        childCount: entry.value.length,
                        itemBuilder: (context, index) {
                          final image = entry.value[index];
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ImageViewerScreen(
                                    images: entry.value,
                                    initialIndex: index,
                                    isFromBin: widget.title == 'Bin',
                                    heroTagPrefix: 'collection_${widget.title}_',
                                  ),
                                ),
                              );
                            },
                            child: Hero(
                              tag:
                                  'collection_${widget.title}_${image.image.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: PrismMediaPreview(
                                  imageUrl: image.image.imageUrl,
                                  mediaType: image.image.mediaType,
                                  fit: BoxFit.cover,
                                  placeholderColor: PrismColors.surfaceGray,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }

  IconData _getIconForTitle(String title) {
    switch (title) {
      case 'Favourites':
        return Icons.favorite_border_rounded;
      case 'Archived':
        return Icons.archive_outlined;
      case 'Bin':
        return Icons.delete_outline_rounded;
      default:
        return Icons.image_outlined;
    }
  }

  Widget _buildEmptyState() {
    switch (widget.title) {
      case 'Favourites':
        return EmptyStateWidget.noFavorites();
      case 'Bin':
        return EmptyStateWidget(
          icon: Icons.delete_outline_rounded,
          title: 'Bin is empty',
          message:
              'Deleted items will appear here for 30 days before permanent deletion.',
        );
      case 'Archived':
        return EmptyStateWidget(
          icon: Icons.archive_outlined,
          title: 'No archived items',
          message: 'Archived photos will appear here.',
        );
      default:
        return EmptyStateWidget.noMedia();
    }
  }
}
