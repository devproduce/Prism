import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:prism/screens/onboarding_screen.dart';
import 'package:prism/screens/home_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/widgets/gradient_background.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Minimum splash duration
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.initializeAuth();

    // Request notification permissions
    if (mounted) {
      // Don't await this to avoid blocking navigation too long if permission dialog is slow
      Provider.of<NotificationsProvider>(
        context,
        listen: false,
      ).requestPermissions();
    }

    if (!mounted) return;

    if (authProvider.isAuthenticated && authProvider.currentUser != null) {
      // Validate session with backend to ensure it's still valid
      // (handles cases like app reinstall, expired tokens, etc.)
      try {
        await authProvider.apiClient.getCurrentUser(
          authProvider.currentUser!.userId,
        );

        // Session is valid, navigate to home
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                HomeScreen(key: HomeScreen.homeScreenKey),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      } catch (e) {
        debugPrint('Session validation failed: $e');
        // If session check fails, consider as logged out
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const OnboardingScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } else {
      // Not authenticated, navigate to onboarding
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const OnboardingScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                    'assets/Images/image.png',
                    width: 100,
                    height: 100,
                    color: Colors.white,
                  )
                  .animate()
                  .fade(duration: 1200.ms, curve: Curves.easeOutCubic)
                  .moveY(
                    begin: 30,
                    end: 0,
                    duration: 1200.ms,
                    curve: Curves.easeOutCubic,
                  ),

              const SizedBox(height: 32),

              // Title
              Text(
                    'Prism',
                    style: PrismTextStyles.h1.copyWith(
                      fontSize: 48,
                      letterSpacing: -1,
                      shadows: [
                        BoxShadow(
                          color: PrismColors.purple.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fade(
                    delay: 300.ms,
                    duration: 1200.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .moveY(
                    begin: 30,
                    end: 0,
                    delay: 300.ms,
                    duration: 1200.ms,
                    curve: Curves.easeOutCubic,
                  ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                    'Your Gallery, Smarter.',
                    style: PrismTextStyles.bodyLarge.copyWith(
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 2,
                    ),
                  )
                  .animate()
                  .fade(
                    delay: 600.ms,
                    duration: 1200.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .moveY(
                    begin: 30,
                    end: 0,
                    delay: 600.ms,
                    duration: 1200.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
