import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/screens/forgot_password_screen.dart';
import 'package:prism/screens/register_screen.dart';
import 'package:prism/screens/home_screen.dart';
import 'package:prism/utils/error_handler.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Add haptic feedback
    HapticFeedback.lightImpact();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final success = await authProvider.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );

      if (success && mounted) {
        // Success haptic feedback
        HapticFeedback.mediumImpact();
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                HomeScreen(key: HomeScreen.homeScreenKey),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      } else if (mounted) {
        // Show error using centralized error handler
        ErrorHandler.showErrorSnackbar(
          context,
          message: authProvider.error ?? 'Login failed. Please try again.',
          onRetry: _handleLogin,
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: ErrorHandler.getErrorMessage(e),
          onRetry: _handleLogin,
        );
      }
    }
  }

  InputDecoration _prismInputDecoration(
    BuildContext context,
    String hint,
    IconData icon,
  ) {
    // Get responsive values
    final screenWidth = MediaQuery.of(context).size.width;
    final contentPadding = screenWidth < 360 ? 12.0 : 16.0;
    final borderRadius = screenWidth < 360 ? 10.0 : 12.0;

    return InputDecoration(
      hintText: hint,
      hintStyle: PrismTextStyles.bodyMedium.copyWith(
        color: PrismColors.secondaryText,
      ),
      prefixIcon: Icon(icon, color: PrismColors.secondaryText),
      filled: true,
      fillColor: PrismColors.inputGray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(
          color: PrismColors.prismYellow,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(
          color: PrismColors.destructiveRed,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(
          color: PrismColors.destructiveRed,
          width: 1.5,
        ),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: contentPadding,
        vertical: contentPadding,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive padding
    final horizontalPadding = screenWidth < 360 ? 16.0 : 24.0;

    // Responsive icon size
    final headerIconSize = (screenWidth * 0.1).clamp(32.0, 48.0);
    final headerIconPadding = (screenWidth * 0.04).clamp(12.0, 20.0);

    // Responsive spacing
    final headerToFormSpacing = (screenHeight * 0.05).clamp(32.0, 56.0);
    final formToFooterSpacing = (screenHeight * 0.03).clamp(24.0, 40.0);
    final labelToInputSpacing = screenHeight < 700 ? 6.0 : 8.0;
    final inputToInputSpacing = screenHeight < 700 ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  // Header
                  Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(headerIconPadding),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: PrismColors.surfaceGray,
                          border: Border.all(
                            color: PrismColors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Icon(
                          Icons.waving_hand_rounded,
                          size: headerIconSize,
                          color: PrismColors.prismYellow,
                        ),
                      ).animate().scale(
                        duration: 500.ms,
                        curve: Curves.elasticOut,
                      ),
                      SizedBox(height: inputToInputSpacing),

                      Text(
                        'Welcome Back',
                        textAlign: TextAlign.center,
                        style: PrismTextStyles.h1,
                      ).animate().fadeIn().moveY(begin: 10, end: 0),

                      SizedBox(height: labelToInputSpacing),

                      Text(
                        'Login to continue your vibe.',
                        textAlign: TextAlign.center,
                        style: PrismTextStyles.bodyMedium.copyWith(
                          color: PrismColors.secondaryText,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                    ],
                  ),

                  SizedBox(height: headerToFormSpacing),

                  // Form Card
                  PrismCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Username or Email Field
                          Text(
                            'Username or Email',
                            style: PrismTextStyles.bodyMedium,
                          ).animate().fadeIn(delay: 300.ms),
                          SizedBox(height: labelToInputSpacing),
                          TextFormField(
                            controller: _identifierController,
                            style: PrismTextStyles.bodyLarge,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: _prismInputDecoration(
                              context,
                              'Enter username or email',
                              Icons.person_outline_rounded,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your username or email';
                              }
                              if (value.trim().length < 3) {
                                return 'Must be at least 3 characters';
                              }
                              return null;
                            },
                          ).animate().fadeIn(delay: 350.ms),

                          SizedBox(height: inputToInputSpacing),

                          // Password Field
                          Text(
                            'Password',
                            style: PrismTextStyles.bodyMedium,
                          ).animate().fadeIn(delay: 400.ms),
                          SizedBox(height: labelToInputSpacing),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: PrismTextStyles.bodyLarge,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                            decoration:
                                _prismInputDecoration(
                                  context,
                                  'Enter your password',
                                  Icons.lock_outline_rounded,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: PrismColors.secondaryText,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ).animate().fadeIn(delay: 450.ms),

                          // Forgot Password Link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Forgot Password?',
                                style: PrismTextStyles.bodySmall.copyWith(
                                  color: PrismColors.prismYellow,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 500.ms),

                          //SizedBox(height: inputToInputSpacing),

                          // Login Button
                          Consumer<AuthProvider>(
                                builder: (context, authProvider, child) {
                                  return PrismButton(
                                    text: 'Log In',
                                    isLoading: authProvider.isLoading,
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : _handleLogin,
                                    type: PrismButtonType.primary,
                                  );
                                },
                              )
                              .animate()
                              .fadeIn(delay: 550.ms)
                              .moveY(begin: 10, end: 0),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: formToFooterSpacing),

                  // Create Account Link
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        'New here? ',
                        style: PrismTextStyles.bodyMedium.copyWith(
                          color: PrismColors.secondaryText,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) =>
                                  const RegisterScreen(),
                              transitionsBuilder: (_, animation, __, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Create Account',
                          style: PrismTextStyles.button.copyWith(
                            color: PrismColors.prismYellow,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 600.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
