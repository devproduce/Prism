import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/responsive_helper.dart';

/// Full-width Google auth button with the branded Google icon asset.
class ContinueWithGoogleButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const ContinueWithGoogleButton({
    super.key,
    this.text = 'Continue with Google',
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final height = ResponsiveHelper.buttonHeight(context);
    final iconSize = screenWidth < 360 ? 20.0 : 24.0;
    final fontSize = screenWidth < 360 ? 14.0 : 16.0;
    final horizontalPadding = screenWidth < 360 ? 16.0 : 20.0;
    final borderRadius = screenWidth < 360 ? 12.0 : 14.0;
    final disabled = onPressed == null || isLoading;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: PrismColors.inputGray,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: PrismColors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: AnimatedOpacity(
              opacity: disabled ? 0.6 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: PrismColors.white,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/Images/google.png',
                          width: iconSize,
                          height: iconSize,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(width: screenWidth < 360 ? 10.0 : 12.0),
                        Flexible(
                          child: Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PrismTextStyles.button.copyWith(
                              color: PrismColors.white,
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
