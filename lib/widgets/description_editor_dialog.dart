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
            SnackBar(
              content: const Text('Description updated successfully'),
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
            backgroundColor: Colors.red,
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
    final size = MediaQuery.of(context).size;
    final remainingChars = _maxLength - _controller.text.length;

    return Dialog(
      backgroundColor: AppTheme.darkBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Edit Description',
                  style: TextStyle(
                    color: AppTheme.darkPrimaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.darkSecondaryText),
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              enabled: !_isLoading,
              maxLines: 5,
              maxLength: _maxLength,
              style: TextStyle(color: AppTheme.darkPrimaryText, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Add a description...',
                hintStyle: TextStyle(color: AppTheme.darkTertiaryText),
                filled: true,
                fillColor: AppTheme.darkDotInactive.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterText: '',
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '$remainingChars characters remaining',
                  style: TextStyle(
                    color: remainingChars < 50
                        ? Colors.orange
                        : AppTheme.darkTertiaryText,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.darkSecondaryText),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveDescription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
