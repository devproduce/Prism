import 'package:flutter/material.dart';
import 'package:prism/utils/theme.dart';

class OnboardingPageTwo extends StatelessWidget {
  const OnboardingPageTwo({super.key});

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
            'assets/Images/onboarding2.png',
            height: imageHeight,
            fit: BoxFit.contain,
          ),

          SizedBox(height: AppTheme.verticalSpacing(context, 0.06)),

          // Headline
          Text(
            'Keep What Matters.\nNothing Else.',
            textAlign: TextAlign.center,
            style: AppTheme.headlineStyle(context),
          ),

          SizedBox(height: AppTheme.verticalSpacing(context, 0.025)),

          // Description
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
            child: Text(
              'Easily share your media and let your device automatically shed the irrelevant photos and videos you don\'t want to keep.',
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
