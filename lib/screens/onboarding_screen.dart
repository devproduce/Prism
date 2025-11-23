import 'package:flutter/material.dart';
import 'package:prism/utils/theme.dart';
import 'package:prism/screens/onboarding_page_one.dart';
import 'package:prism/screens/onboarding_page_two.dart';
import 'package:prism/screens/onboarding_page_three.dart';
import 'package:prism/screens/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

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

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipToEnd() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _navigateToRegister() {
    // TODO: Navigate to register screen when created
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            const Placeholder(), // Replace with RegisterScreen
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final horizontalPadding = AppTheme.horizontalPadding(context);
    final buttonHeight = AppTheme.buttonHeight(context);

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground(context),
      body: SafeArea(
        child: Stack(
          children: [
            // Skip button (only show on first two pages)
            if (_currentPage < 2)
              Positioned(
                top: size.height * 0.02,
                right: horizontalPadding,
                child: TextButton(
                  onPressed: _skipToEnd,
                  child: Text('Skip', style: AppTheme.skipButtonStyle(context)),
                ),
              ),

            // PageView with onboarding pages
            Column(
              children: [
                // Pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    children: const [
                      OnboardingPageOne(),
                      OnboardingPageTwo(),
                      OnboardingPageThree(),
                    ],
                  ),
                ),

                // Page indicators
                Padding(
                  padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppTheme.dotActive(context)
                              : AppTheme.dotInactive(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom buttons
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: size.height * 0.03,
                  ),
                  child: _currentPage < 2
                      ? _buildContinueButton(buttonHeight)
                      : _buildAuthButtons(buttonHeight),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton(double height) {
    return GestureDetector(
      onTap: _nextPage,
      child: Container(
        height: height,
        decoration: AppTheme.primaryButtonDecoration(),
        child: Center(
          child: Text('Continue', style: AppTheme.buttonTextStyle(context)),
        ),
      ),
    );
  }

  Widget _buildAuthButtons(double height) {
    return Column(
      children: [
        // Login button
        GestureDetector(
          onTap: _navigateToLogin,
          child: Container(
            height: height,
            decoration: AppTheme.primaryButtonDecoration(),
            child: Center(
              child: Text('Login', style: AppTheme.buttonTextStyle(context)),
            ),
          ),
        ),

        SizedBox(height: AppTheme.verticalSpacing(context, 0.02)),

        // Register button
        GestureDetector(
          onTap: _navigateToRegister,
          child: Container(
            height: height,
            decoration: AppTheme.secondaryButtonDecoration(),
            child: Center(
              child: Text(
                'Register',
                style: AppTheme.buttonTextStyle(
                  context,
                ).copyWith(color: AppTheme.primaryAccent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
