import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:prism/screens/login_screen.dart';
import 'package:prism/screens/register_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/widgets/gradient_background.dart';

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
      'title': 'Your Gallery,\nSmarter.',
      'description':
          'AI-powered organization for your chaotic gallery. Finding memories has never been this smooth.',
    },
    {
      'image': 'assets/Images/onboarding2.png',
      'title': 'Share in\nSeconds.',
      'description':
          'Instant, intelligent sharing with the people who matter most. No clutter, just vibes.',
    },
    {
      'image': 'assets/Images/onboarding3.png',
      'title': 'Private &\nProtected.',
      'description':
          'Your moments stay yours. Zero risk, 100% control over who sees what.',
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
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RegisterScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
          // Content
          Column(
            children: [
              // Skip Button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_currentPage < _pages.length - 1)
                        TextButton(
                          onPressed: _navigateToLogin,
                          child: Text(
                            'Skip',
                            style: PrismTextStyles.button.copyWith(
                              color: Colors.white.withOpacity(0.6),
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
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Graphic
                          Expanded(
                            flex: 5,
                            child: Container(
                              margin: const EdgeInsets.all(20),
                              padding: const EdgeInsets.all(20),
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
                                        color: PrismColors.purple.withOpacity(0.5),
                                        blurRadius: 20,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                ).animate().fadeIn().moveY(begin: 30, end: 0),
                                
                                const SizedBox(height: 16),
                                
                                Text(
                                  page['description']!,
                                  textAlign: TextAlign.center,
                                  style: PrismTextStyles.bodyMedium.copyWith(
                                    height: 1.5,
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
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Column(
                  children: [
                    // Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 32 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: _currentPage == index 
                                ? PrismColors.prismSignature 
                                : null,
                            color: _currentPage == index 
                                ? null 
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Actions
                    if (_currentPage == _pages.length - 1) ...[
                      GlassButton(
                        text: 'Get Started',
                        onPressed: _navigateToRegister,
                        isPrimary: true,
                      ).animate().fadeIn().moveY(begin: 20, end: 0),
                      const SizedBox(height: 16),
                      GlassButton(
                        text: 'I already have an account',
                        onPressed: _navigateToLogin,
                        isPrimary: false,
                      ).animate().fadeIn(delay: 200.ms).moveY(begin: 20, end: 0),
                    ] else ...[
                       GlassButton(
                        text: 'Next',
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        isPrimary: true,
                         icon: Icons.arrow_forward_rounded,
                      ),
                      const SizedBox(height: 72), // Height of secondary button + margin to keep layout stable
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}
