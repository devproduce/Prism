import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/screens/processing_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/responsive_helper.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:prism/utils/error_handler.dart';

class ShareUploadScreen extends StatefulWidget {
  final List<String>? sharedFilePaths;

  const ShareUploadScreen({super.key, this.sharedFilePaths});

  @override
  State<ShareUploadScreen> createState() => _ShareUploadScreenState();
}

class _ShareUploadScreenState extends State<ShareUploadScreen> {
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load shared files if provided
    if (widget.sharedFilePaths != null && widget.sharedFilePaths!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSharedFiles();
      });
    }
  }

  void _loadSharedFiles() {
    debugPrint('Loading shared files: ${widget.sharedFilePaths}');

    // Filter to only files that exist
    final validFiles = <File>[];
    for (final path in widget.sharedFilePaths!) {
      debugPrint('Checking file: $path');
      final file = File(path);
      if (file.existsSync()) {
        debugPrint('File exists: $path (${file.lengthSync()} bytes)');
        validFiles.add(file);
      } else {
        debugPrint('File does NOT exist: $path');
      }
    }

    if (mounted && validFiles.isNotEmpty) {
      context.read<SharingProvider>().setSelectedImages(validFiles);

      // Show feedback to user
      ErrorHandler.showSuccessSnackbar(
        context,
        message:
            'Loaded ${validFiles.length} ${validFiles.length == 1 ? 'file' : 'files'} from gallery',
      );
    } else if (mounted && validFiles.isEmpty) {
      // Show error if no valid files
      ErrorHandler.showErrorSnackbar(
        context,
        message: 'Could not load shared files. Please try again.',
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      final List<AssetEntity>? assets = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(requestType: RequestType.common),
      );

      if (assets != null && assets.isNotEmpty) {
        final List<File> files = [];

        for (final asset in assets) {
          final file = await asset.file;
          if (file != null) {
            files.add(file);
          }
        }

        if (mounted && files.isNotEmpty) {
          context.read<SharingProvider>().addImages(files);
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: 'Failed to pick media: ${ErrorHandler.getErrorMessage(e)}',
        );
      }
    }
  }

  Future<void> _uploadAndProcess() async {
    final sharingProvider = context.read<SharingProvider>();
    final authProvider = context.read<AuthProvider>();

    if (!sharingProvider.hasImages) {
      ErrorHandler.showInfoSnackbar(
        context,
        message: 'Please select at least one item',
      );
      return;
    }

    final userId = authProvider.currentUser?.userId;
    if (userId == null) {
      ErrorHandler.showErrorSnackbar(
        context,
        message: 'User not authenticated',
      );
      return;
    }

    // Set description from text field
    sharingProvider.setDescription(_descriptionController.text);

    // Haptic feedback for action
    HapticFeedback.mediumImpact();

    // Start upload BEFORE navigation to ensure state is ready
    sharingProvider.uploadImages(userId);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProcessingScreen()),
      );
    }
  }

  bool _isVideo(String path) {
    final ext = path.split('.').last.toLowerCase();
    // Common mobile video formats
    return [
      'mp4',
      'mov',
      'avi',
      'mkv',
      'webm',
      '3gp',
      'flv',
      'f4v',
      'mpg',
      'mpeg',
      'm4v',
    ].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final sharingProvider = Provider.of<SharingProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = ResponsiveHelper.horizontalPadding(context);
    const crossAxisSpacing = 12.0;
    final crossAxisCount = screenWidth >= ResponsiveHelper.tablet ? 3 : 2;
    final columnWidth = (screenWidth -
            horizontalPadding * 2 -
            crossAxisSpacing * (crossAxisCount - 1)) /
        crossAxisCount;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text('Share Memories', style: PrismTextStyles.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          if (sharingProvider.hasImages)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: PrismButton(
                text: 'Share',
                onPressed: sharingProvider.isUploading
                    ? null
                    : _uploadAndProcess,
                width: 100,
                height: 36,
                type: PrismButtonType.primary,
                isLoading: sharingProvider.isUploading,
              ),
            ),
        ],
      ),
      body: sharingProvider.isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: PrismColors.prismYellow),
                  SizedBox(height: 16),
                  Text(
                    'Starting upload...',
                    style: TextStyle(color: PrismColors.secondaryText),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Description Input
                        // Text('Caption', style: PrismTextStyles.h3),
                        // const SizedBox(height: 8),
                        // PrismTextField(
                        //   controller: _descriptionController,
                        //   hintText: 'What\'s happening in these moments?',
                        //   maxLines: 4,
                        // ),

                        //const SizedBox(height: 24),

                        // Image Grid Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Selected Media', style: PrismTextStyles.h3),
                            Text(
                              '${sharingProvider.selectedImages.length} Items',
                              style: PrismTextStyles.bodySmall.copyWith(
                                color: PrismColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Image Grid
                        MasonryGridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: crossAxisSpacing,
                          itemCount: sharingProvider.selectedImages.length + 1,
                          itemBuilder: (context, index) {
                            if (index ==
                                sharingProvider.selectedImages.length) {
                              return _AddMediaTile(
                                width: columnWidth,
                                onTap: _pickMedia,
                              );
                            }

                            final file = sharingProvider.selectedImages[index];
                            return _SelectedMediaTile(
                              file: file,
                              width: columnWidth,
                              isVideo: _isVideo(file.path),
                              onRemove: () => sharingProvider.removeImage(index),
                            );
                          },
                        ),
                        const SizedBox(height: 100), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AddMediaTile extends StatelessWidget {
  final double width;
  final VoidCallback onTap;

  const _AddMediaTile({
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: width,
        decoration: BoxDecoration(
          color: PrismColors.inputGray,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PrismColors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PrismColors.voidBlack,
                shape: BoxShape.circle,
                border: Border.all(
                  color: PrismColors.white.withValues(alpha: 0.12),
                ),
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                color: PrismColors.prismYellow,
                size: 32,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add Media',
              style: PrismTextStyles.bodySmall.copyWith(
                color: PrismColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedMediaTile extends StatefulWidget {
  final File file;
  final double width;
  final bool isVideo;
  final VoidCallback onRemove;

  const _SelectedMediaTile({
    required this.file,
    required this.width,
    required this.isVideo,
    required this.onRemove,
  });

  @override
  State<_SelectedMediaTile> createState() => _SelectedMediaTileState();
}

class _SelectedMediaTileState extends State<_SelectedMediaTile> {
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(_SelectedMediaTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _aspectRatio = null;
      _resolveAspectRatio();
    }
  }

  Future<void> _resolveAspectRatio() async {
    if (widget.isVideo) {
      if (mounted) setState(() => _aspectRatio = 16 / 9);
      return;
    }

    try {
      final bytes = await widget.file.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 240,
      );
      final frame = await codec.getNextFrame();
      final width = frame.image.width.toDouble();
      final height = frame.image.height.toDouble();
      frame.image.dispose();

      if (!mounted || height <= 0) return;
      setState(() => _aspectRatio = width / height);
    } catch (_) {
      if (mounted) setState(() => _aspectRatio = 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = _aspectRatio;
    final tileHeight = aspectRatio == null
        ? widget.width
        : widget.width / aspectRatio;

    return SizedBox(
      width: widget.width,
      height: tileHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: PrismColors.surfaceGray,
              child: aspectRatio == null
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PrismColors.prismYellow,
                        ),
                      ),
                    )
                  : widget.isVideo
                      ? const ColoredBox(
                          color: PrismColors.black,
                          child: Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              color: PrismColors.white,
                              size: 48,
                            ),
                          ),
                        )
                      : Image.file(
                          widget.file,
                          fit: BoxFit.cover,
                          width: widget.width,
                          height: tileHeight,
                          errorBuilder: (context, error, stackTrace) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.broken_image,
                                  color: PrismColors.secondaryText,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Error',
                                  style: PrismTextStyles.bodySmall.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: widget.onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: PrismColors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: PrismColors.white,
                ),
              ),
            ),
          ),
          if (widget.isVideo)
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: PrismColors.prismYellow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'VIDEO',
                  style: TextStyle(
                    color: PrismColors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
