import 'package:flutter/material.dart';
import 'package:prism/models/gallery_image_model.dart';

class ImageInfoSheet extends StatelessWidget {
  final GalleryImage image;

  const ImageInfoSheet({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      'Image Info',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildSection(
                      context: context,
                      title: 'Basic Info',
                      children: [
                        _buildInfoRow(context, 'Image ID', image.image.id),
                        if (image.image.takenAt != null)
                          _buildInfoRow(
                            context,
                            'Date Taken',
                            _formatDateTime(image.image.takenAt!),
                          ),
                        _buildInfoRow(
                          context,
                          'Storage Path',
                          image.image.storagePath,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context: context,
                      title: 'Dimensions',
                      children: [
                        if (image.image.width != null)
                          _buildInfoRow(
                            context,
                            'Width',
                            '${image.image.width} px',
                          ),
                        if (image.image.height != null)
                          _buildInfoRow(
                            context,
                            'Height',
                            '${image.image.height} px',
                          ),
                        if (image.image.width != null &&
                            image.image.height != null)
                          _buildInfoRow(
                            context,
                            'Aspect Ratio',
                            _calculateAspectRatio(
                              image.image.width!,
                              image.image.height!,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context: context,
                      title: 'Faces Detected',
                      children: [
                        _buildInfoRow(
                          context,
                          'Face Count',
                          '${image.faces.length}',
                        ),
                        if (image.faces.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ...image.faces.map(
                            (face) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: Icon(
                                    Icons.person,
                                    color: theme.colorScheme.onPrimaryContainer,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  face.username ?? 'Unknown',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: face.userId != null
                                    ? Text(
                                        'ID: ${face.userId}',
                                        style: theme.textTheme.bodySmall,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context: context,
                      title: 'Status',
                      children: [
                        _buildInfoRow(
                          context,
                          'Favourite',
                          image.galleryMeta.favourite ? 'Yes' : 'No',
                          valueColor: image.galleryMeta.favourite
                              ? Colors.red
                              : null,
                        ),
                        _buildInfoRow(
                          context,
                          'Archived',
                          image.galleryMeta.archive ? 'Yes' : 'No',
                        ),
                        _buildInfoRow(
                          context,
                          'In Bin',
                          image.galleryMeta.bin ? 'Yes' : 'No',
                          valueColor: image.galleryMeta.bin
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ],
                    ),
                    if (image.image.metadata != null &&
                        image.image.metadata!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSection(
                        context: context,
                        title: 'Metadata',
                        children: image.image.metadata!.entries
                            .where((entry) => entry.key != 'description')
                            .map(
                              (entry) => _buildInfoRow(
                                context,
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
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor ?? theme.colorScheme.onSurface,
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
