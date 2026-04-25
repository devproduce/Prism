import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/screens/processing_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
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
  final ImagePicker _picker = ImagePicker();
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
      final List<XFile> media = await _picker.pickMultipleMedia();

      if (media.isNotEmpty) {
        // Filter to only allow image and video extensions
        final allowedExtensions = {
          // Image formats
          'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif',
          // Video formats
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
        };

        final validMedia = media.where((xfile) {
          final ext = xfile.path.split('.').last.toLowerCase();
          return allowedExtensions.contains(ext);
        }).toList();

        if (validMedia.isEmpty) {
          if (mounted) {
            ErrorHandler.showErrorSnackbar(
              context,
              message: 'Please select only image or video files',
            );
          }
          return;
        }

        final files = validMedia.map((xfile) => File(xfile.path)).toList();
        if (mounted) {
          context.read<SharingProvider>().addImages(files);
        }

        // Show warning if some files were filtered out
        if (validMedia.length < media.length) {
          if (mounted) {
            ErrorHandler.showInfoSnackbar(
              context,
              message:
                  'Some files were skipped (only images and videos allowed)',
            );
          }
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
                    padding: const EdgeInsets.all(16.0),
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
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          itemCount: sharingProvider.selectedImages.length + 1,
                          itemBuilder: (context, index) {
                            if (index ==
                                sharingProvider.selectedImages.length) {
                              return GestureDetector(
                                onTap: _pickMedia, // Changed to pickMedia
                                child: Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: PrismColors
                                        .inputGray, // Dark matte gray
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: PrismColors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      style: BorderStyle.solid,
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
                                            color: PrismColors.white.withValues(
                                              alpha: 0.12,
                                            ),
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
                                        style: PrismTextStyles.bodySmall
                                            .copyWith(
                                              color: PrismColors.secondaryText,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final file = sharingProvider.selectedImages[index];
                            final isVideo = _isVideo(file.path);

                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    height: 150, // Fixed height for grid
                                    color: PrismColors.surfaceGray,
                                    child: isVideo
                                        ? Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              // Placeholder for video thumb
                                              Container(
                                                color: PrismColors.black,
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.play_circle_fill,
                                                    color: PrismColors.white,
                                                    size: 48,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Image.file(
                                            file,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    color:
                                                        PrismColors.surfaceGray,
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        const Icon(
                                                          Icons.broken_image,
                                                          color: PrismColors
                                                              .secondaryText,
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          'Error',
                                                          style: PrismTextStyles
                                                              .bodySmall
                                                              .copyWith(
                                                                fontSize: 10,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                          ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () =>
                                        sharingProvider.removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: PrismColors.black.withValues(
                                          alpha: 0.6,
                                        ),
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
                                if (isVideo)
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
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
