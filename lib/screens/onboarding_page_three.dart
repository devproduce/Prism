import 'package:flutter/material.dart';
import 'package:prism/utils/theme.dart';

class OnboardingPageThree extends StatelessWidget {
  const OnboardingPageThree({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final horizontalPadding = AppTheme.horizontalPadding(context);

    // Responsive image size
    final imageHeight = size.height * 0.40;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Illustration
          Image.asset(
            'assets/Images/onboarding3.png',
            height: imageHeight,
            fit: BoxFit.contain,
          ),

          SizedBox(height: AppTheme.verticalSpacing(context, 0.06)),

          // Headline
          Text(
            'Trusted Sharing.\nZero Risk.',
            textAlign: TextAlign.center,
            style: AppTheme.headlineStyle(context),
          ),

          SizedBox(height: AppTheme.verticalSpacing(context, 0.025)),

          // Description
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
            child: Text(
              'Distribute your personal moments within a trusted network. Our platform ensures your memories are always private and protected.',
              textAlign: TextAlign.center,
              style: AppTheme.subHeadlineStyle(context),
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
