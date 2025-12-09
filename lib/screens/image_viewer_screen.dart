import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/models/gallery_image_model.dart';
import 'package:prism/widgets/image_info_sheet.dart';
import 'package:prism/widgets/description_editor_dialog.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:flutter/services.dart';

class ImageViewerScreen extends StatefulWidget {
  final List<GalleryImage> images;
  final int initialIndex;
  final bool isFromBin;
  final Function(File)? onShare;

  const ImageViewerScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    this.isFromBin = false,
    this.onShare,
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
  late List<GalleryImage> _localImages;
  double _rotationAngle = 0.0; // Rotation angle in radians

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _localImages = List.from(widget.images); // Create mutable copy
    _pageController = PageController(initialPage: widget.initialIndex);
    // Hide status bar for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    // Restore status bar
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  GalleryImage get currentImage {
    // Protect against out-of-bounds access
    if (_currentIndex < 0 || _currentIndex >= _localImages.length) {
      // Return a dummy image if index is invalid (should not happen in normal flow)
      throw StateError(
        'Invalid current index: $_currentIndex (list length: ${_localImages.length})',
      );
    }
    return _localImages[_currentIndex];
  }

  void _updateCurrentImage(GalleryImage updatedImage) {
    if (_currentIndex >= 0 && _currentIndex < _localImages.length) {
      setState(() {
        _localImages[_currentIndex] = updatedImage;
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _rotateImage() {
    setState(() {
      _rotationAngle += 1.5708; // Rotate by 90 degrees (π/2 radians)
      if (_rotationAngle >= 6.2832) {
        _rotationAngle = 0; // Reset after 360 degrees
      }
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
        // Optimistically update UI immediately
        final newValue = !currentImage.galleryMeta.favourite;
        _updateCurrentImage(
          GalleryImage(
            image: currentImage.image,
            faces: currentImage.faces,
            galleryMeta: GalleryMeta(
              favourite: newValue,
              archive: currentImage.galleryMeta.archive,
              bin: currentImage.galleryMeta.bin,
            ),
          ),
        );

        // Then update backend
        await galleryProvider.toggleImageStatus(
          userId: authProvider.currentUser!.userId,
          imageId: currentImage.image.id,
          field: 'favourite',
        );

        // Success - no snackbar needed
      } catch (e) {
        // Revert on error
        _updateCurrentImage(
          GalleryImage(
            image: currentImage.image,
            faces: currentImage.faces,
            galleryMeta: GalleryMeta(
              favourite: !currentImage.galleryMeta.favourite,
              archive: currentImage.galleryMeta.archive,
              bin: currentImage.galleryMeta.bin,
            ),
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to toggle favourite: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
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
        // Optimistically update UI immediately
        final newValue = !currentImage.galleryMeta.archive;
        _updateCurrentImage(
          GalleryImage(
            image: currentImage.image,
            faces: currentImage.faces,
            galleryMeta: GalleryMeta(
              favourite: currentImage.galleryMeta.favourite,
              archive: newValue,
              bin: currentImage.galleryMeta.bin,
            ),
          ),
        );

        // Then update backend
        await galleryProvider.toggleImageStatus(
          userId: authProvider.currentUser!.userId,
          imageId: currentImage.image.id,
          field: 'archive',
        );

        // Success - no snackbar needed
      } catch (e) {
        // Revert on error
        _updateCurrentImage(
          GalleryImage(
            image: currentImage.image,
            faces: currentImage.faces,
            galleryMeta: GalleryMeta(
              favourite: currentImage.galleryMeta.favourite,
              archive: !currentImage.galleryMeta.archive,
              bin: currentImage.galleryMeta.bin,
            ),
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to toggle archive: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
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
        title: const Text('Move to Bin?'),
        content: const Text(
          'This image will be moved to the bin. You can restore it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Move to Bin'),
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
        try {
          final imageIdToDelete = currentImage.image.id;

          // Update backend first
          await galleryProvider.toggleImageStatus(
            userId: authProvider.currentUser!.userId,
            imageId: imageIdToDelete,
            field: 'bin',
          );

          if (mounted) {
            // Success - no snackbar needed

            // Always close viewer to return to home screen
            Navigator.pop(context);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to move to bin: $e'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 2),
              ),
            );
          }
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
          // Success - no snackbar needed
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to restore: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
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
      showDragHandle: true,
      builder: (context) => ImageInfoSheet(image: currentImage),
    );
  }

  Widget _buildBottomActionBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // If image is in bin, only show restore option
    if (widget.isFromBin || currentImage.galleryMeta.bin) {
      return Container(
        color: Colors.black.withOpacity(0.7),
        padding: const EdgeInsets.symmetric(vertical: 8),
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
              color: Colors.white,
              onTap: _showImageInfo,
            ),
          ],
        ),
      );
    }

    // Normal action bar for non-bin images
    return Container(
      color: Colors.black.withOpacity(0.7),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            color: Colors.white,
            onTap: () async {
              if (widget.onShare != null) {
                try {
                  final file = await DefaultCacheManager().getSingleFile(
                    currentImage.image.imageUrl,
                  );
                  widget.onShare!(file);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to prepare image: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              } else {
                Navigator.pushNamed(context, '/share');
              }
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
            color: Colors.white,
            onTap: _toggleArchive,
          ),
          _buildActionButton(
            icon: Icons.rotate_right,
            label: 'Rotate',
            color: Colors.white,
            onTap: _rotateImage,
          ),
          _buildActionButton(
            icon: Icons.edit_outlined,
            label: 'Edit',
            color: Colors.white,
            onTap: _showDescriptionEditor,
          ),
          _buildActionButton(
            icon: Icons.info_outline,
            label: 'Info',
            color: Colors.white,
            onTap: _showImageInfo,
          ),
          _buildActionButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: colorScheme.error,
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
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
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
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showControls
          ? AppBar(
              backgroundColor: Colors.black.withOpacity(0.5),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              systemOverlayStyle: SystemUiOverlayStyle.light,
              title: Text(
                '${_currentIndex + 1} / ${widget.images.length}',
                style: const TextStyle(color: Colors.white),
              ),
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
                _rotationAngle = 0.0; // Reset rotation when changing images
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
                    child: Transform.rotate(
                      angle: _rotationAngle,
                      child: Hero(
                        tag: 'image_${image.image.id}',
                        child: CachedNetworkImage(
                          imageUrl: image.image.imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 64,
                            ),
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
              child: SafeArea(top: false, child: _buildBottomActionBar()),
            ),
        ],
      ),
    );
  }
}
