import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onActionTap;
  final String? actionLabel;
  final IconData? actionIcon;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onActionTap,
    this.actionLabel,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PrismTextStyles.h3.copyWith(
                    color: PrismColors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: PrismTextStyles.bodySmall.copyWith(
                      color: PrismColors.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onActionTap != null)
            GestureDetector(
              onTap: onActionTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: PrismColors.surfaceGray.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: PrismColors.white.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actionLabel != null)
                      Text(
                        actionLabel!,
                        style: PrismTextStyles.bodySmall.copyWith(
                          color: PrismColors.prismYellow,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (actionLabel != null && actionIcon != null)
                      const SizedBox(width: 4),
                    if (actionIcon != null)
                      Icon(
                        actionIcon,
                        size: 14,
                        color: PrismColors.prismYellow,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
