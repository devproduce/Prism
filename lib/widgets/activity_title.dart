import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

class ActivityTitle extends StatelessWidget {
  static final RegExp _actionVerbsRegex = RegExp(
    r'(.*?)( started| requested| liked| commented| shared)(.*)',
  );

  final String title;
  final TextStyle? style;

  const ActivityTitle({
    super.key,
    required this.title,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ??
        PrismTextStyles.bodyMedium.copyWith(
          color: PrismColors.white,
          height: 1.3,
        );
    final match = _actionVerbsRegex.firstMatch(title);

    if (match == null) {
      return Text(title, style: baseStyle);
    }

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(
            text: match.group(1),
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: match.group(2)),
          TextSpan(text: match.group(3)),
        ],
      ),
    );
  }
}
