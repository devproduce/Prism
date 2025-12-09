import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/widgets/gradient_scaffold.dart';
import 'package:prism/models/gallery_image_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/screens/image_viewer_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

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

    // Flatten logic for Staggered Grid if we wanted single list, but keeping sections is better for "Month" headers
    // For Staggered Grid with Sections, we can use SliverStaggeredGrid or similar, but simplified Masonry is easiest for now.
    // However, sticking to the existing grouped structure is fine, just replacing the GridView with MasonryGridView.

    return GradientScaffold(
      appBar: AppBar(
        title: Text(widget.title, style: PrismTextStyles.h2),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
      ),
      body: groupedImages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getIconForTitle(widget.title),
                    size: 64,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No items in ${widget.title}',
                    style: PrismTextStyles.bodyMedium.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: groupedImages.entries.map((entry) {
                return SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          entry.key,
                          style: PrismTextStyles.h3.copyWith(color: PrismColors.electricBlue),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childCount: entry.value.length,
                        itemBuilder: (context, index) {
                          final image = entry.value[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ImageViewerScreen(
                                    images: entry.value,
                                    initialIndex: index,
                                    isFromBin: widget.title == 'Bin',
                                  ),
                                ),
                              );
                            },
                            child: Hero(
                              tag: 'collection_${widget.title}_${image.image.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: image.image.imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: PrismColors.glassFrostedWhite),
                                  errorWidget: (context, url, error) => Container(
                                    color: PrismColors.glassFrostedWhite,
                                    child: const Icon(Icons.broken_image, color: Colors.white24),
                                  ),
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
}
