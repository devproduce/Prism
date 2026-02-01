import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/models/gallery_image_model.dart';
import 'package:prism/widgets/image_info_sheet.dart';
import 'package:prism/widgets/description_editor_dialog.dart';
import 'package:prism/widgets/video_player_widget.dart'; // Import video player
import 'package:provider/provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/pin_dialog.dart';
import 'package:prism/utils/error_handler.dart';

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
    HapticFeedback.selectionClick();
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
          ErrorHandler.showErrorSnackbar(
            context,
            message:
                'Failed to toggle favourite: ${ErrorHandler.getErrorMessage(e)}',
          );
        }
      }
    }
  }

  Future<void> _toggleArchive() async {
    HapticFeedback.selectionClick();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final galleryProvider = Provider.of<GalleryProvider>(
      context,
      listen: false,
    );

    if (authProvider.currentUser != null) {
      // Security Check
      if (!currentImage.galleryMeta.archive) {
        // We are Archiving (Moving to Secure Archive)
        if (!authProvider.hasArchivePin) {
          // Pin not set, force set
          final success = await showDialog<bool>(
            context: context,
            builder: (context) => PinDialog(
              isSettingPin: true,
              onConfirm: (pin) {
                authProvider.setArchivePin(pin);
                return true;
              },
            ),
          );
          if (success != true) return; // User cancelled
        }
        // If Pin is set, we proceed to archive.
      } else {
        // Un-Archiving?
        // If we are viewing an archived image (accessed via Edit Profile -> Pin),
        // we might want to allow un-archiving freely or require PIN again?
        // Since we are already IN the secure view (implied), we can probably allow un-archiving.
        // But if we are in Home Screen and somehow viewing it (shouldn't happen),
        // anyway current logic is fine.
      }

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
          ErrorHandler.showErrorSnackbar(
            context,
            message:
                'Failed to toggle archive: ${ErrorHandler.getErrorMessage(e)}',
          );
        }
      }
    }
  }

  Future<void> _moveToBin() async {
    HapticFeedback.selectionClick();

    // Show enhanced dialog with delete from phone option
    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (context) => _DeleteConfirmationDialog(),
    );

    if (result == null || result['confirmed'] != true) {
      return; // User cancelled
    }

    final deleteFromPhone = result['deleteFromPhone'] ?? false;

    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final galleryProvider = Provider.of<GalleryProvider>(
        context,
        listen: false,
      );

      if (authProvider.currentUser != null) {
        try {
          final imageIdToDelete = currentImage.image.id;

          if (deleteFromPhone) {
            // Delete from backend bin AND phone gallery
            await galleryProvider.deleteImagePermanently(
              imageId: imageIdToDelete,
              userId: authProvider.currentUser!.userId,
            );
          } else {
            // Just move to bin on backend (existing behavior)
            await galleryProvider.toggleImageStatus(
              userId: authProvider.currentUser!.userId,
              imageId: imageIdToDelete,
              field: 'bin',
            );
          }

          if (mounted) {
            // Always close viewer to return to home screen
            Navigator.pop(context);
          }
        } catch (e) {
          if (mounted) {
            ErrorHandler.showErrorSnackbar(
              context,
              message:
                  'Failed to delete image: ${ErrorHandler.getErrorMessage(e)}',
            );
          }
        }
      }
    }
  }

  Future<void> _restoreFromBin() async {
    HapticFeedback.selectionClick();
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
          ErrorHandler.showErrorSnackbar(
            context,
            message: 'Failed to restore: ${ErrorHandler.getErrorMessage(e)}',
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
      backgroundColor: PrismColors.surfaceGray,
      builder: (context) => ImageInfoSheet(image: currentImage),
    );
  }

  Widget _buildBottomActionBar() {
    // If image is in bin, only show restore option
    if (widget.isFromBin || currentImage.galleryMeta.bin) {
      return Container(
        color: PrismColors.voidBlack.withValues(alpha: 0.9),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionButton(
              icon: Icons.restore_from_trash,
              label: 'Restore',
              color: PrismColors.successGreen,
              onTap: _restoreFromBin,
            ),
            const SizedBox(width: 40),
            _buildActionButton(
              icon: Icons.info_outline,
              label: 'Info',
              color: PrismColors.white,
              onTap: _showImageInfo,
            ),
          ],
        ),
      );
    }

    // Normal action bar for non-bin images
    return Container(
      color: PrismColors.voidBlack.withValues(alpha: 0.9),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            color: PrismColors.white,
            onTap: () async {
              if (widget.onShare != null) {
                try {
                  final file = await DefaultCacheManager().getSingleFile(
                    currentImage.image.imageUrl,
                  );
                  widget.onShare!(file);
                } catch (e) {
                  if (mounted) {
                    ErrorHandler.showErrorSnackbar(
                      context,
                      message:
                          'Failed to prepare image: ${ErrorHandler.getErrorMessage(e)}',
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
                ? PrismColors.destructiveRed
                : PrismColors.white,
            onTap: _toggleFavourite,
          ),
          _buildActionButton(
            icon: currentImage.galleryMeta.archive
                ? Icons.unarchive
                : Icons.archive_outlined,
            label: 'Archive',
            color: PrismColors.white,
            onTap: _toggleArchive,
          ),
          _buildActionButton(
            icon: Icons.rotate_right,
            label: 'Rotate',
            color: PrismColors.white,
            onTap: _rotateImage,
          ),
          _buildActionButton(
            icon: Icons.edit_outlined,
            label: 'Edit',
            color: PrismColors.white,
            onTap: _showDescriptionEditor,
          ),
          _buildActionButton(
            icon: Icons.info_outline,
            label: 'Info',
            color: PrismColors.white,
            onTap: _showImageInfo,
          ),
          _buildActionButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: PrismColors.destructiveRed,
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
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
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
              style: PrismTextStyles.bodySmall.copyWith(
                color: color,
                fontSize: 10,
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
      backgroundColor: PrismColors.voidBlack,
      extendBodyBehindAppBar: true,
      appBar: _showControls
          ? AppBar(
              backgroundColor: PrismColors.voidBlack.withValues(alpha: 0.5),
              elevation: 0,
              iconTheme: const IconThemeData(color: PrismColors.white),
              systemOverlayStyle: SystemUiOverlayStyle.light,
              title: Text(
                '${_currentIndex + 1} / ${widget.images.length}',
                style: PrismTextStyles.h3.copyWith(color: PrismColors.white),
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
                        child: image.image.mediaType.startsWith('video/')
                            ? VideoPlayerWidget(
                                key: ValueKey('video_${image.image.id}_$index'),
                                videoUrl: image.image.imageUrl,
                                autoPlay:
                                    index ==
                                    _currentIndex, // Only autoplay on current page
                                looping: true,
                              )
                            : CachedNetworkImage(
                                imageUrl: image.image.imageUrl,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                    color: PrismColors.prismYellow,
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: PrismColors.secondaryText,
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

/// Dialog for confirming delete with option to delete from phone storage
class _DeleteConfirmationDialog extends StatefulWidget {
  @override
  State<_DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<_DeleteConfirmationDialog> {
  bool _deleteFromPhone = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PrismColors.surfaceGray,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Delete Image?',
        style: PrismTextStyles.h3.copyWith(color: PrismColors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This image will be moved to the bin.',
            style: PrismTextStyles.bodyMedium.copyWith(
              color: PrismColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              setState(() {
                _deleteFromPhone = !_deleteFromPhone;
              });
              HapticFeedback.selectionClick();
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _deleteFromPhone
                            ? PrismColors.destructiveRed
                            : PrismColors.secondaryText,
                        width: 2,
                      ),
                      color: _deleteFromPhone
                          ? PrismColors.destructiveRed
                          : Colors.transparent,
                    ),
                    child: _deleteFromPhone
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: PrismColors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Also delete from phone storage',
                      style: PrismTextStyles.bodyMedium.copyWith(
                        color: PrismColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_deleteFromPhone)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 4),
              child: Text(
                'The image will be removed from your photo gallery.',
                style: PrismTextStyles.bodySmall.copyWith(
                  color: PrismColors.destructiveRed.withValues(alpha: 0.8),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, null);
          },
          child: Text(
            'Cancel',
            style: PrismTextStyles.button.copyWith(
              color: PrismColors.secondaryText,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, {
              'confirmed': true,
              'deleteFromPhone': _deleteFromPhone,
            });
          },
          child: Text(
            'Delete',
            style: PrismTextStyles.button.copyWith(
              color: PrismColors.destructiveRed,
            ),
          ),
        ),
      ],
    );
  }
}
