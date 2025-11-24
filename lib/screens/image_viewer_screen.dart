import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/models/gallery_image_model.dart';
import 'package:prism/utils/theme.dart';
import 'package:prism/widgets/image_info_sheet.dart';
import 'package:prism/widgets/description_editor_dialog.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/providers/auth_provider.dart';

class ImageViewerScreen extends StatefulWidget {
  final List<GalleryImage> images;
  final int initialIndex;
  final bool isFromBin;

  const ImageViewerScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    this.isFromBin = false,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  GalleryImage get currentImage => widget.images[_currentIndex];

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  Future<void> _toggleFavourite() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final galleryProvider = Provider.of<GalleryProvider>(
      context,
      listen: false,
    );

    if (authProvider.currentUser != null) {
      try {
        await galleryProvider.toggleImageStatus(
          userId: authProvider.currentUser!.userId,
          imageId: currentImage.image.id,
          field: 'favourite',
        );
        setState(() {});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                currentImage.galleryMeta.favourite
                    ? 'Added to favourites'
                    : 'Removed from favourites',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to toggle favourite: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleArchive() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final galleryProvider = Provider.of<GalleryProvider>(
      context,
      listen: false,
    );

    if (authProvider.currentUser != null) {
      try {
        await galleryProvider.toggleImageStatus(
          userId: authProvider.currentUser!.userId,
          imageId: currentImage.image.id,
          field: 'archive',
        );
        setState(() {});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                currentImage.galleryMeta.archive ? 'Archived' : 'Unarchived',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to toggle archive: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _moveToBin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkBackground,
        title: Text(
          'Move to Bin?',
          style: TextStyle(color: AppTheme.darkPrimaryText),
        ),
        content: Text(
          'This image will be moved to the bin. You can restore it later.',
          style: TextStyle(color: AppTheme.darkSecondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.darkSecondaryText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Move to Bin', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final galleryProvider = Provider.of<GalleryProvider>(
        context,
        listen: false,
      );

      if (authProvider.currentUser != null) {
        await galleryProvider.toggleImageStatus(
          userId: authProvider.currentUser!.userId,
          imageId: currentImage.image.id,
          field: 'bin',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image moved to bin'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _restoreFromBin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final galleryProvider = Provider.of<GalleryProvider>(
      context,
      listen: false,
    );

    if (authProvider.currentUser != null) {
      try {
        await galleryProvider.restoreFromBin(
          userId: authProvider.currentUser!.userId,
          imageId: currentImage.image.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image restored successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to restore: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showDescriptionEditor() {
    showDialog(
      context: context,
      builder: (context) => DescriptionEditorDialog(
        imageId: currentImage.image.id,
        currentDescription: currentImage.image.metadata?['description'] ?? '',
      ),
    );
  }

  void _showImageInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ImageInfoSheet(image: currentImage),
    );
  }

  Widget _buildBottomActionBar(Size size) {
    // If image is in bin, only show restore option
    if (widget.isFromBin || currentImage.galleryMeta.bin) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.02,
          vertical: size.height * 0.02,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.6),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionButton(
              icon: Icons.restore_from_trash,
              label: 'Restore',
              color: Colors.green,
              onTap: _restoreFromBin,
            ),
            const SizedBox(width: 40),
            _buildActionButton(
              icon: Icons.info_outline,
              label: 'Info',
              onTap: _showImageInfo,
            ),
          ],
        ),
      );
    }

    // Normal action bar for non-bin images
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.02,
        vertical: size.height * 0.02,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () {
              Navigator.pushNamed(context, '/share');
            },
          ),
          _buildActionButton(
            icon: currentImage.galleryMeta.favourite
                ? Icons.favorite
                : Icons.favorite_border,
            label: 'Favourite',
            color: currentImage.galleryMeta.favourite
                ? Colors.red
                : Colors.white,
            onTap: _toggleFavourite,
          ),
          _buildActionButton(
            icon: currentImage.galleryMeta.archive
                ? Icons.unarchive
                : Icons.archive_outlined,
            label: 'Archive',
            onTap: _toggleArchive,
          ),
          _buildActionButton(
            icon: Icons.edit_outlined,
            label: 'Edit',
            onTap: _showDescriptionEditor,
          ),
          _buildActionButton(
            icon: Icons.info_outline,
            label: 'Info',
            onTap: _showImageInfo,
          ),
          _buildActionButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: Colors.red,
            onTap: _moveToBin,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showControls
          ? AppBar(
              backgroundColor: Colors.black.withOpacity(0.5),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                '${_currentIndex + 1} / ${widget.images.length}',
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _transformationController.value = Matrix4.identity();
              });
            },
            itemBuilder: (context, index) {
              final image = widget.images[index];
              return GestureDetector(
                onTap: _toggleControls,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Hero(
                      tag: 'image_${image.image.id}',
                      child: CachedNetworkImage(
                        imageUrl: image.image.imageUrl,
                        fit: BoxFit.contain,
                        maxHeightDiskCache: 1920,
                        maxWidthDiskCache: 1920,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryAccent,
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white.withOpacity(0.5),
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Bottom action bar
          if (_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomActionBar(size),
            ),
        ],
      ),
    );
  }
}
