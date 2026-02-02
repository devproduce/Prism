import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

class NotificationSectionHeader extends StatelessWidget {
  final String title;
  final bool showDivider;

  const NotificationSectionHeader({
    super.key,
    required this.title,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: PrismTextStyles.bodySmall.copyWith(
              color: PrismColors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
