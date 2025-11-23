import 'package:flutter/material.dart';
import 'package:prism/utils/theme.dart';

class OnboardingPageOne extends StatelessWidget {
  const OnboardingPageOne({super.key});

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
            'assets/Images/onboarding1.png',
            height: imageHeight,
            fit: BoxFit.contain,
          ),

          SizedBox(height: AppTheme.verticalSpacing(context, 0.06)),

          // Headline
          Text(
            'Effortless Sharing.\nIn Seconds.',
            textAlign: TextAlign.center,
            style: AppTheme.headlineStyle(context),
          ),

          SizedBox(height: AppTheme.verticalSpacing(context, 0.025)),

          // Description
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
            child: Text(
              'Upload your media and our AI will instantly take care of the heavy work, distributing relevant media to the right people.',
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
