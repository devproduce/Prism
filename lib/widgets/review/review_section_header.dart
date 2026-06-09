import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

/// Section label row for the review screen (e.g. SUGGESTIONS + VIEW ALL).
class ReviewSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ReviewSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Text(
            title,
            style: PrismTextStyles.bodySmall.copyWith(
              color: PrismColors.prismYellow,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onAction!();
              },
              child: Text(
                actionLabel!,
                style: PrismTextStyles.bodySmall.copyWith(
                  color: PrismColors.prismYellow,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
