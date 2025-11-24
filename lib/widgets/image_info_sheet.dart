import 'package:flutter/material.dart';
import 'package:prism/models/gallery_image_model.dart';
import 'package:prism/utils/theme.dart';

class ImageInfoSheet extends StatelessWidget {
  final GalleryImage image;

  const ImageInfoSheet({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.darkTertiaryText,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      'Image Info',
                      style: TextStyle(
                        color: AppTheme.darkPrimaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.darkPrimaryText),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildSection(
                      title: 'Basic Info',
                      children: [
                        _buildInfoRow('Image ID', image.image.id),
                        if (image.image.takenAt != null)
                          _buildInfoRow(
                            'Date Taken',
                            _formatDateTime(image.image.takenAt!),
                          ),
                        _buildInfoRow('Storage Path', image.image.storagePath),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Dimensions',
                      children: [
                        if (image.image.width != null)
                          _buildInfoRow('Width', '${image.image.width} px'),
                        if (image.image.height != null)
                          _buildInfoRow('Height', '${image.image.height} px'),
                        if (image.image.width != null &&
                            image.image.height != null)
                          _buildInfoRow(
                            'Aspect Ratio',
                            _calculateAspectRatio(
                              image.image.width!,
                              image.image.height!,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Faces Detected',
                      children: [
                        _buildInfoRow('Face Count', '${image.faces.length}'),
                        if (image.faces.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ...image.faces
                              .map(
                                (face) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppTheme.primaryAccent
                                            .withOpacity(0.2),
                                        child: Icon(
                                          Icons.person,
                                          color: AppTheme.primaryAccent,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              face.username ?? 'Unknown',
                                              style: TextStyle(
                                                color: AppTheme.darkPrimaryText,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (face.userId != null)
                                              Text(
                                                'ID: ${face.userId}',
                                                style: TextStyle(
                                                  color:
                                                      AppTheme.darkTertiaryText,
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Status',
                      children: [
                        _buildInfoRow(
                          'Favourite',
                          image.galleryMeta.favourite ? 'Yes' : 'No',
                          valueColor: image.galleryMeta.favourite
                              ? Colors.red
                              : null,
                        ),
                        _buildInfoRow(
                          'Archived',
                          image.galleryMeta.archive ? 'Yes' : 'No',
                        ),
                        _buildInfoRow(
                          'In Bin',
                          image.galleryMeta.bin ? 'Yes' : 'No',
                          valueColor: image.galleryMeta.bin ? Colors.red : null,
                        ),
                      ],
                    ),
                    if (image.image.metadata != null &&
                        image.image.metadata!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        title: 'Metadata',
                        children: image.image.metadata!.entries
                            .where((entry) => entry.key != 'description')
                            .map(
                              (entry) => _buildInfoRow(
                                _formatMetadataKey(entry.key),
                                entry.value?.toString() ?? 'N/A',
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppTheme.darkSecondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.darkDotInactive.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: AppTheme.darkTertiaryText, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppTheme.darkPrimaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _calculateAspectRatio(int width, int height) {
    final gcd = _gcd(width, height);
    return '${width ~/ gcd}:${height ~/ gcd}';
  }

  int _gcd(int a, int b) {
    while (b != 0) {
      final temp = b;
      b = a % b;
      a = temp;
    }
    return a;
  }

  String _formatMetadataKey(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
