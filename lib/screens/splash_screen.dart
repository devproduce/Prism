import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:prism/screens/onboarding_screen.dart';
import 'package:prism/screens/home_screen.dart';
import 'package:prism/screens/share_upload_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/models/auth_gate.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/activity_feed_provider.dart';
import 'package:prism/screens/secure_account_screen.dart';
import 'package:prism/screens/verify_email_screen.dart';
import 'package:prism/services/share_handler_service.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ShareHandlerService _shareHandler = ShareHandlerService();
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    debugPrint('SplashScreen: Starting initialization');

    try {
      // Wait for splash animation (minimum duration)
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      // Initialize auth
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.initializeAuth();
      debugPrint(
        'SplashScreen: Auth initialized, isAuthenticated: ${authProvider.isAuthenticated}',
      );

      // Request notification permissions
      if (mounted) {
        Provider.of<ActivityFeedProvider>(
          context,
          listen: false,
        ).requestPermissions();
      }

      if (!mounted) return;

      // Check for shared files AFTER Flutter engine is fully initialized
      debugPrint('SplashScreen: Checking for shared files...');
      final sharedFiles = await _shareHandler.getSharedFiles();
      debugPrint('SplashScreen: Shared files received: $sharedFiles');

      if (!mounted) return;

      // Determine navigation destination
      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        try {
          await authProvider.apiClient.getCurrentUser();

          if (!mounted) return;

          final gate = authProvider.authGate;
          if (gate == AuthGate.verifyEmail) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
            );
            return;
          }
          if (gate == AuthGate.migrateAccount) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SecureAccountScreen()),
            );
            return;
          }

          // If we have shared files, go to share screen
          if (sharedFiles.isNotEmpty) {
            debugPrint(
              'SplashScreen: Navigating to ShareUploadScreen with ${sharedFiles.length} files',
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    ShareUploadScreen(sharedFilePaths: sharedFiles),
              ),
            );
          } else {
            // Normal navigation to home
            debugPrint('SplashScreen: Navigating to HomeScreen');
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) =>
                    HomeScreen(key: HomeScreen.homeScreenKey),
                transitionsBuilder: (_, animation, __, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          }
        } catch (e) {
          debugPrint('SplashScreen: Session validation failed: $e');
          if (!mounted) return;

          final gate = authProvider.authGate;
          if (gate == AuthGate.verifyEmail) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
            );
            return;
          }
          if (gate == AuthGate.migrateAccount) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SecureAccountScreen()),
            );
            return;
          }

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
        debugPrint(
          'SplashScreen: Not authenticated, going to OnboardingScreen',
        );
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
    } catch (e) {
      // Handle initialization errors gracefully
      debugPrint('SplashScreen: Initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to initialize app. Please try again.';
        });
      }
    }
  }

  void _retryInitialization() {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
    _initializeAndNavigate();
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive logo size (larger for center display)
    final logoSize = (screenWidth * 0.5).clamp(180.0, 300.0);

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      body: Center(
        child: _hasError
            ? _buildErrorState(screenWidth)
            : Center(
                child: Image.asset(
                  'assets/Images/Prism Logo.png',
                  width: logoSize,
                  height: logoSize,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.auto_awesome,
                      size: logoSize,
                      color: PrismColors.white,
                    );
                  },
                ).animate().fade(duration: 1000.ms, curve: Curves.easeOut),
              ),
      ),
    );
  }

  Widget _buildErrorState(double screenWidth) {
    final iconSize = (screenWidth * 0.15).clamp(48.0, 80.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PrismColors.destructiveRed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: iconSize,
              color: PrismColors.destructiveRed,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Oops!',
            style: PrismTextStyles.h1.copyWith(color: PrismColors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            style: PrismTextStyles.bodyMedium.copyWith(
              color: PrismColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: _retryInitialization,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: TextButton.styleFrom(
              foregroundColor: PrismColors.prismYellow,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
