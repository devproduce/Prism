import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/screens/processing_screen.dart';
import 'package:prism/utils/theme.dart';

class ShareUploadScreen extends StatefulWidget {
  const ShareUploadScreen({super.key});

  @override
  State<ShareUploadScreen> createState() => _ShareUploadScreenState();
}

class _ShareUploadScreenState extends State<ShareUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      debugPrint('📷 [ShareUploadScreen] Opening image picker...');
      final List<XFile> images = await _picker.pickMultiImage();
      debugPrint('📷 [ShareUploadScreen] Selected ${images.length} images');

      if (images.isNotEmpty) {
        final files = images.map((xfile) => File(xfile.path)).toList();
        if (mounted) {
          context.read<SharingProvider>().addImages(files);
          debugPrint(
            '✅ [ShareUploadScreen] Added ${files.length} images to provider',
          );
        }
      } else {
        debugPrint('⚠️ [ShareUploadScreen] No images selected');
      }
    } catch (e) {
      debugPrint('❌ [ShareUploadScreen] Image picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick images: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _uploadAndProcess() async {
    debugPrint('🚀 [ShareUploadScreen] Starting upload process...');
    final sharingProvider = context.read<SharingProvider>();
    final authProvider = context.read<AuthProvider>();

    if (!sharingProvider.hasImages) {
      debugPrint('⚠️ [ShareUploadScreen] No images to upload');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image')),
      );
      return;
    }

    final userId = authProvider.currentUser?.userId;
    if (userId == null) {
      debugPrint('❌ [ShareUploadScreen] User not authenticated');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    debugPrint('✅ [ShareUploadScreen] User ID: $userId');
    debugPrint('   Images: ${sharingProvider.selectedCount}');
    debugPrint('   Description: ${_descriptionController.text}');
    debugPrint('   Auto Clean: ${sharingProvider.autoClean}');

    // Set description from text field
    sharingProvider.setDescription(_descriptionController.text);

    // Navigate to processing screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProcessingScreen()),
      );
    }

    // Start upload
    debugPrint('📤 [ShareUploadScreen] Calling uploadImages...');
    final batchId = await sharingProvider.uploadImages(userId);

    if (batchId == null) {
      debugPrint('❌ [ShareUploadScreen] Upload returned null batch ID');
      if (mounted && sharingProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${sharingProvider.error}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } else {
      debugPrint(
        '✅ [ShareUploadScreen] Upload initiated with batch ID: $batchId',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer<SharingProvider>(
          builder: (context, sharingProvider, _) {
            return Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(size.width * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Photos',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: size.height * 0.01),
                      Text(
                        'Upload photos to your gallery and share them with friends.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: sharingProvider.hasImages
                      ? _buildImageGrid(sharingProvider, size, theme, isDark)
                      : _buildEmptyState(size, theme, isDark),
                ),

                // Description Field
                if (sharingProvider.hasImages)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.05,
                      vertical: size.height * 0.02,
                    ),
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Add a description (optional)',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.04,
                          vertical: size.height * 0.015,
                        ),
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),

                // Auto-Clean Toggle
                if (sharingProvider.hasImages)
                  Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: size.width * 0.05,
                      vertical: size.height * 0.01,
                    ),
                    padding: EdgeInsets.all(size.width * 0.04),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(size.width * 0.02),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            color: AppTheme.primaryAccent,
                            size: size.width * 0.06,
                          ),
                        ),
                        SizedBox(width: size.width * 0.03),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-Clean Media',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: size.height * 0.003),
                              Text(
                                'Automatically move media to recipients if you or your faces aren\'t detected.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: sharingProvider.autoClean,
                          onChanged: (_) => sharingProvider.toggleAutoClean(),
                          activeColor: AppTheme.primaryAccent,
                        ),
                      ],
                    ),
                  ),

                // Action Buttons
                Padding(
                  padding: EdgeInsets.all(size.width * 0.05),
                  child: sharingProvider.hasImages
                      ? Row(
                          children: [
                            // Add More Button
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _pickImages,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppTheme.primaryAccent,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: size.height * 0.02,
                                  ),
                                ),
                                child: Text(
                                  'Add More',
                                  style: TextStyle(
                                    color: AppTheme.primaryAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: size.width * 0.04,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: size.width * 0.03),
                            // Send Button
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: sharingProvider.isUploading
                                    ? null
                                    : _uploadAndProcess,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: size.height * 0.02,
                                  ),
                                ),
                                child: sharingProvider.isUploading
                                    ? SizedBox(
                                        height: size.width * 0.05,
                                        width: size.width * 0.05,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        'Send',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: size.width * 0.04,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        )
                      : ElevatedButton(
                          onPressed: _pickImages,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: size.height * 0.02,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Select Files',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: size.width * 0.04,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(Size size, ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: size.width * 0.3,
            height: size.width * 0.3,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.upload_outlined,
              size: size.width * 0.15,
              color: AppTheme.primaryAccent,
            ),
          ),
          SizedBox(height: size.height * 0.03),
          Text(
            'Click to upload',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: size.height * 0.01),
          Text(
            'Drag and drop or click to browse multiple files',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(
    SharingProvider sharingProvider,
    Size size,
    ThemeData theme,
    bool isDark,
  ) {
    return Column(
      children: [
        // Image count header
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.05,
            vertical: size.height * 0.01,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected (${sharingProvider.selectedCount})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              TextButton.icon(
                onPressed: () => sharingProvider.clearImages(),
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ),

        // Image grid
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: size.width * 0.02,
              mainAxisSpacing: size.width * 0.02,
              childAspectRatio: 1,
            ),
            itemCount: sharingProvider.selectedImages.length,
            itemBuilder: (context, index) {
              final image = sharingProvider.selectedImages[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(image, fit: BoxFit.cover),
                  ),
                  // Remove button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => sharingProvider.removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
