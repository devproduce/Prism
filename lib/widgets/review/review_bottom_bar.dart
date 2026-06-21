import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/responsive_helper.dart';
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

  static const double _maxContentWidth = 800;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final isCompact = screenWidth < ResponsiveHelper.mediumScreen;
    final isVerySmall = screenWidth < ResponsiveHelper.smallScreen;
    final bottomInset = media.padding.bottom;
    final buttonHeight = ResponsiveHelper.buttonHeight(context);
    final horizontalGap = isVerySmall ? 8.0 : 12.0;
    final shareLabel = isCompact ? 'Share' : 'Share Memories';

    return Container(
      padding: EdgeInsets.fromLTRB(
        contentInset,
        isCompact ? 14 : 16,
        contentInset,
        bottomInset + (isCompact ? 14 : 16),
      ),
      decoration: BoxDecoration(
        color: PrismColors.surfaceGray,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isCompact ? 24 : 32),
        ),
        border: Border(
          top: BorderSide(color: PrismColors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showNoRecipientsWarning)
                Padding(
                  padding: EdgeInsets.only(bottom: isCompact ? 10 : 12),
                  child: Text(
                    'Select at least one friend to share with',
                    style: PrismTextStyles.bodySmall.copyWith(
                      color: PrismColors.destructiveRed,
                      fontSize: ResponsiveHelper.scaledFontSize(context, 12),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CancelButton(
                    onPressed: onCancel,
                    height: buttonHeight,
                    iconOnly: isVerySmall,
                    isCompact: isCompact,
                  ),
                  SizedBox(width: horizontalGap),
                  Expanded(
                    child: PrismButton(
                      text: shareLabel,
                      isLoading: isSharing,
                      icon: Icons.send_rounded,
                      height: buttonHeight,
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

class _CancelButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double height;
  final bool iconOnly;
  final bool isCompact;

  const _CancelButton({
    required this.onPressed,
    required this.height,
    required this.iconOnly,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = ResponsiveHelper.iconSizeS(context);
    final fontSize = ResponsiveHelper.scaledFontSize(context, 16);

    if (iconOnly) {
      return SizedBox(
        height: height,
        width: height,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(Icons.close, color: PrismColors.secondaryText, size: iconSize),
          style: IconButton.styleFrom(
            backgroundColor: PrismColors.inputGray.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16),
          minimumSize: Size(isCompact ? 88 : 100, height),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close, color: PrismColors.secondaryText, size: iconSize),
            SizedBox(width: isCompact ? 4 : 6),
            Text(
              'Cancel',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: PrismTextStyles.button.copyWith(
                color: PrismColors.secondaryText,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
