import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:prism/screens/login_screen.dart';
import 'package:prism/screens/sign_up_choice_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/utils/responsive_helper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'image': 'assets/Images/onboarding1.png',
      'title': "Group photos shouldn’t feel like work.",
      'description':
          '',
    },
    {
      'image': 'assets/Images/onboarding2.png',
      'title': 'Trust built into every share.',
      'description':
          '',
    },
    {
      'image': 'assets/Images/onboarding3.png',
      'title': 'Finally, sharing done right.',
      'description':
          '',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _navigateToLogin() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _navigateToRegister() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SignUpChoiceScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = ResponsiveHelper.screenWidth(context);
    final horizontalPadding = ResponsiveHelper.horizontalPadding(context);
    final spacingS = ResponsiveHelper.spacingS(context);
    final spacingM = ResponsiveHelper.spacingM(context);
    final spacingL = ResponsiveHelper.spacingL(context);
    final spacingXL = ResponsiveHelper.spacingXL(context);

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      body: Stack(
        children: [
          // Content
          Column(
            children: [
              // Skip Button
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: spacingS,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_currentPage < _pages.length - 1)
                        TextButton(
                          onPressed: _navigateToLogin,
                          child: Text(
                            'Skip',
                            style: PrismTextStyles.button.copyWith(
                              color: PrismColors.secondaryText,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ).animate().fadeIn(),
                    ],
                  ),
                ),
              ),

              // Page View
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Graphic
                          Expanded(
                            flex: 5,
                            child: Container(
                              margin: EdgeInsets.all(spacingM),
                              padding: EdgeInsets.all(spacingM),
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage(page['image']!),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ).animate().scale(duration: 600.ms, delay: 200.ms),
                          ),

                          // Text Content
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                Text(
                                  page['title']!,
                                  textAlign: TextAlign.center,
                                  style: PrismTextStyles.h1.copyWith(
                                    height: 1.1,
                                    shadows: [
                                      BoxShadow(
                                        color: PrismColors.purple.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 20,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                ).animate().fadeIn().moveY(begin: 30, end: 0),

                                SizedBox(height: spacingM),

                                Text(
                                  page['description']!,
                                  textAlign: TextAlign.center,
                                  style: PrismTextStyles.bodyMedium.copyWith(
                                    height: 1.5,
                                    color: PrismColors.secondaryText,
                                  ),
                                ).animate().fadeIn(delay: 200.ms),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom Control Area
              Container(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  spacingXL,
                ),
                child: Column(
                  children: [
                    // Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: EdgeInsets.symmetric(
                            horizontal: spacingS * 0.5,
                          ),
                          width: _currentPage == index
                              ? screenWidth * 0.08
                              : screenWidth * 0.02,
                          height: screenWidth * 0.02,
                          decoration: BoxDecoration(
                            gradient: _currentPage == index
                                ? PrismColors.prismSignature
                                : null,
                            color: _currentPage == index
                                ? null
                                : PrismColors.surfaceGray,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: spacingL),

                    // Actions
                    if (_currentPage == _pages.length - 1) ...[
                      PrismButton(
                        text: 'Get Started',
                        onPressed: _navigateToRegister,
                        type: PrismButtonType.primary,
                      ).animate().fadeIn().moveY(begin: 20, end: 0),
                      SizedBox(height: spacingM),
                      PrismButton(
                            text: 'I already have an account',
                            onPressed: _navigateToLogin,
                            type: PrismButtonType.secondary,
                          )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .moveY(begin: 20, end: 0),
                    ] else ...[
                      PrismButton(
                        text: 'Next',
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        type: PrismButtonType.primary,
                        icon: Icons.arrow_forward_rounded,
                      ),
                      SizedBox(
                        height:
                            ResponsiveHelper.buttonHeight(context) + spacingM,
                      ), // Height of secondary button + margin
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
