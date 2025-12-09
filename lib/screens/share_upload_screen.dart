import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/screens/processing_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/widgets/gradient_scaffold.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

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
      final List<XFile> images = await _picker.pickMultiImage();

      if (images.isNotEmpty) {
        final files = images.map((xfile) => File(xfile.path)).toList();
        if (mounted) {
          context.read<SharingProvider>().addImages(files);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick images: $e', style: PrismTextStyles.bodyMedium),
            backgroundColor: PrismColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _uploadAndProcess() async {
    final sharingProvider = context.read<SharingProvider>();
    final authProvider = context.read<AuthProvider>();

    if (!sharingProvider.hasImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one image', style: PrismTextStyles.bodyMedium),
          behavior: SnackBarBehavior.floating,
          backgroundColor: PrismColors.warningYellow,
        ),
      );
      return;
    }

    final userId = authProvider.currentUser?.userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User not authenticated', style: PrismTextStyles.bodyMedium),
          backgroundColor: PrismColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
    final batchId = await sharingProvider.uploadImages(userId);

    if (batchId == null) {
      if (mounted && sharingProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${sharingProvider.error}', style: PrismTextStyles.bodyMedium),
            backgroundColor: PrismColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharingProvider = Provider.of<SharingProvider>(context);

    return GradientScaffold(
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
               child: GlassButton(
                  text: 'Share',
                  onPressed: sharingProvider.isUploading ? null : _uploadAndProcess,
                  width: 80,
                  height: 36,
                  isPrimary: true,
               ),
            ),
        ],
      ),
      body: sharingProvider.isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   CircularProgressIndicator(color: PrismColors.purple),
                   const SizedBox(height: 16),
                   Text('Sharing your moments...', style: PrismTextStyles.bodyMedium),
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
                        GlassCard(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Text('Caption', style: PrismTextStyles.h3),
                               const SizedBox(height: 8),
                               TextField(
                                 controller: _descriptionController,
                                 style: const TextStyle(color: Colors.white),
                                 maxLines: 3,
                                 decoration: InputDecoration(
                                   hintText: 'What\'s happening in these photos?',
                                   hintStyle: const TextStyle(color: Colors.white38),
                                   border: InputBorder.none,
                                 ),
                               ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Image Grid
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Selected Photos', style: PrismTextStyles.h3),
                            Text('${sharingProvider.selectedImages.length} Photos', style: PrismTextStyles.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        MasonryGridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          itemCount: sharingProvider.selectedImages.length + 1,
                          itemBuilder: (context, index) {
                            if (index == sharingProvider.selectedImages.length) {
                              return GestureDetector(
                                onTap: _pickImages,
                                child: Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: PrismColors.glassSnowMist,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                           color: PrismColors.purple.withOpacity(0.2),
                                           shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.add_photo_alternate_rounded, color: PrismColors.purple, size: 32),
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Add Photos', style: PrismTextStyles.bodySmall),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final image = sharingProvider.selectedImages[index];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    File(image.path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => sharingProvider.removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
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
