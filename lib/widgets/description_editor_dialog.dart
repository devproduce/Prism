import 'package:flutter/material.dart';
import 'package:prism/utils/theme.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class DescriptionEditorDialog extends StatefulWidget {
  final String imageId;
  final String currentDescription;

  const DescriptionEditorDialog({
    super.key,
    required this.imageId,
    required this.currentDescription,
  });

  @override
  State<DescriptionEditorDialog> createState() =>
      _DescriptionEditorDialogState();
}

class _DescriptionEditorDialogState extends State<DescriptionEditorDialog> {
  late TextEditingController _controller;
  bool _isLoading = false;
  static const int _maxLength = 500;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentDescription);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveDescription() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final galleryProvider = Provider.of<GalleryProvider>(
        context,
        listen: false,
      );

      if (authProvider.currentUser != null) {
        await galleryProvider.updateDescription(
          userId: authProvider.currentUser!.userId,
          imageId: widget.imageId,
          description: _controller.text.trim(),
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Description updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update description: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remainingChars = _maxLength - _controller.text.length;

    return AlertDialog(
      title: const Text('Edit Description'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            enabled: !_isLoading,
            maxLines: 5,
            maxLength: _maxLength,
            decoration: InputDecoration(
              hintText: 'Add a description...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          Text(
            '$remainingChars characters remaining',
            style: theme.textTheme.bodySmall?.copyWith(
              color: remainingChars < 50
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveDescription,
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
