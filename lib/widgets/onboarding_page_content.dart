import 'package:flutter/material.dart';
import 'package:prism/utils/theme.dart';
import 'package:prism/utils/responsive_helper.dart';

class OnboardingPageContent extends StatelessWidget {
  final String imagePath;
  final String title;
  final String description;

  const OnboardingPageContent({
    super.key,
    required this.imagePath,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final horizontalPadding = ResponsiveHelper.horizontalPadding(context);
    final spacingXL = ResponsiveHelper.spacingXL(context);
    final spacingM = ResponsiveHelper.spacingM(context);

    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Image with subtle animation (Hero or simple fade)
          Expanded(flex: 5, child: Image.asset(imagePath, fit: BoxFit.contain)),

          SizedBox(height: spacingXL),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText(context),
              height: 1.2,
            ),
          ),

          SizedBox(height: spacingM),

          // Description
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.secondaryText(context),
              height: 1.5,
              fontSize: isSmallScreen ? 14 : 16,
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
