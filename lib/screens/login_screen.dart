import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/models/auth_gate.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/screens/forgot_password_screen.dart';
import 'package:prism/screens/register_screen.dart';
import 'package:prism/screens/complete_profile_screen.dart';
import 'package:prism/screens/secure_account_screen.dart';
import 'package:prism/utils/auth_navigation.dart';
import 'package:prism/utils/error_handler.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _googleSignInRequired = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_googleSignInRequired) {
      await _handleGoogleLogin();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    final authProvider = context.read<AuthProvider>();
    final password = _passwordController.text;

    setState(() => _isSubmitting = true);
    authProvider.clearError();

    try {
      // Per mobile_auth_implementation_guide.md: POST /auth/login with
      // identifier (username or email) + password.
      await _completeLogin(
        authProvider,
        legacyDirect: true,
        password: password,
      );
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: ErrorHandler.getErrorMessage(e),
          onRetry: _handleLogin,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _completeLogin(
    AuthProvider authProvider, {
    String? email,
    required String password,
    bool legacyDirect = false,
  }) async {
    final bool success;
    if (legacyDirect) {
      success = await authProvider.login(
        identifier: _usernameController.text.trim(),
        password: password,
        manageLoadingState: false,
      );
    } else {
      success = await authProvider.loginWithFirebaseEmail(
        email: email!,
        password: password,
        manageLoadingState: false,
      );
    }

    if (!mounted) return;

    if (!success && authProvider.authGate == AuthGate.migrateAccount) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SecureAccountScreen()),
      );
      return;
    }

    if (success) {
      HapticFeedback.mediumImpact();
      navigateAfterAuthentication(context, authProvider);
    } else if (authProvider.error != null && authProvider.error!.isNotEmpty) {
      ErrorHandler.showErrorSnackbar(
        context,
        message: authProvider.error!,
        onRetry: _handleLogin,
      );
    }
  }

  Future<void> _handleGoogleLogin() async {
    HapticFeedback.lightImpact();
    final authProvider = context.read<AuthProvider>();
    authProvider.clearGoogleRegistrationRequired();

    setState(() => _isSubmitting = true);
    final success = await authProvider.loginWithGoogle();
    if (mounted) setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      navigateAfterAuthentication(context, authProvider);
      return;
    }

    if (authProvider.googleRegistrationRequired) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
      );
      return;
    }

    if (authProvider.error != null && authProvider.error!.isNotEmpty) {
      ErrorHandler.showErrorSnackbar(
        context,
        message: authProvider.error!,
        onRetry: _handleGoogleLogin,
      );
    }
  }

  void _resetGoogleSignIn() {
    setState(() => _googleSignInRequired = false);
  }

  bool _isLoading(AuthProvider authProvider) {
    return _isSubmitting || authProvider.isLoading;
  }

  InputDecoration _prismInputDecoration(
    BuildContext context,
    String hint,
    IconData icon,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentPadding = screenWidth < 360 ? 12.0 : 14.0;
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final horizontalPadding = screenWidth < 360 ? 16.0 : 24.0;
    final headerIconSize = (screenWidth * 0.1).clamp(32.0, 48.0);
    final headerIconPadding = (screenWidth * 0.04).clamp(12.0, 20.0);
    final isCompact = screenHeight < 700 || screenWidth < 360;
    final headerToFormSpacing = isCompact ? 24.0 : 40.0;
    final formToFooterSpacing = isCompact ? 20.0 : 32.0;
    final labelGap = isCompact ? 6.0 : 8.0;
    final fieldGap = isCompact ? 12.0 : 18.0;
    final buttonGap = isCompact ? 12.0 : 16.0;
    final cardPadding = EdgeInsets.symmetric(
      horizontal: screenWidth < 360 ? 16.0 : 20.0,
      vertical: isCompact ? 14.0 : 18.0,
    );

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: isCompact ? 16 : 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
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
                      SizedBox(height: fieldGap),
                      Text(
                        'Welcome Back',
                        textAlign: TextAlign.center,
                        style: PrismTextStyles.h1,
                      ).animate().fadeIn().moveY(begin: 10, end: 0),
                      SizedBox(height: labelGap),
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
                  PrismCard(
                    padding: cardPadding,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_googleSignInRequired) ...[
                            Text(
                              'Signing in as ${_usernameController.text.trim()}',
                              style: PrismTextStyles.bodyMedium,
                            ),
                            SizedBox(height: labelGap),
                            Text(
                              'This account uses Google Sign-In.',
                              style: PrismTextStyles.bodyMedium.copyWith(
                                color: PrismColors.secondaryText,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: _isSubmitting ? null : _resetGoogleSignIn,
                                child: Text(
                                  'Use a different account',
                                  style: PrismTextStyles.bodySmall.copyWith(
                                    color: PrismColors.prismYellow,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Username',
                              style: PrismTextStyles.bodyMedium,
                            ).animate().fadeIn(delay: 300.ms),
                            SizedBox(height: labelGap),
                            TextFormField(
                              controller: _usernameController,
                              style: PrismTextStyles.bodyLarge,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              decoration: _prismInputDecoration(
                                context,
                                'Enter your username',
                                Icons.person_outline_rounded,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your username';
                                }
                                if (value.trim().length < 3) {
                                  return 'Must be at least 3 characters';
                                }
                                return null;
                              },
                            ).animate().fadeIn(delay: 350.ms),
                            SizedBox(height: fieldGap),
                            Text(
                              'Password',
                              style: PrismTextStyles.bodyMedium,
                            ).animate().fadeIn(delay: 400.ms),
                            SizedBox(height: labelGap),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: PrismTextStyles.bodyLarge,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleLogin(),
                              decoration: _prismInputDecoration(
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
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.only(top: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style: PrismTextStyles.bodySmall.copyWith(
                                    color: PrismColors.prismYellow,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(delay: 500.ms),
                          ],
                          SizedBox(height: buttonGap),
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return PrismButton(
                                text: _googleSignInRequired
                                    ? 'Continue with Google'
                                    : 'Log In',
                                isLoading: _isLoading(authProvider),
                                onPressed: _isLoading(authProvider)
                                    ? null
                                    : _handleLogin,
                                type: _googleSignInRequired
                                    ? PrismButtonType.secondary
                                    : PrismButtonType.primary,
                                icon: _googleSignInRequired
                                    ? Icons.g_mobiledata_rounded
                                    : null,
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
