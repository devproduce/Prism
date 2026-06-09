import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_button.dart';

/// Fixed bottom action bar for the review screen (Cancel + Share).
class ReviewBottomBar extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback? onShare;
  final bool isSharing;
  final bool showNoRecipientsWarning;
  final double contentInset;

  const ReviewBottomBar({
    super.key,
    required this.onCancel,
    required this.onShare,
    required this.isSharing,
    this.showNoRecipientsWarning = false,
    this.contentInset = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      padding: EdgeInsets.fromLTRB(
        contentInset,
        isTablet ? 20 : 16,
        contentInset,
        MediaQuery.of(context).padding.bottom + (isTablet ? 20 : 16),
      ),
      decoration: BoxDecoration(
        color: PrismColors.surfaceGray,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: PrismColors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showNoRecipientsWarning)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Select at least one friend to share with',
                    style: PrismTextStyles.bodySmall.copyWith(
                      color: PrismColors.destructiveRed,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(
                        Icons.close,
                        color: PrismColors.secondaryText,
                      ),
                      label: Text(
                        'Cancel',
                        style: PrismTextStyles.button.copyWith(
                          color: PrismColors.secondaryText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: PrismButton(
                      text: 'Share Memories',
                      isLoading: isSharing,
                      icon: Icons.send_rounded,
                      onPressed: onShare,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
