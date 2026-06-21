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
import 'package:prism/screens/complete_profile_screen.dart';
import 'package:prism/screens/secure_account_screen.dart';
import 'package:prism/utils/auth_navigation.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:prism/api/api_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginPhase { username, password, google }

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  _LoginPhase _phase = _LoginPhase.username;
  String? _resolvedEmail;
  bool _isResolving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _resetToUsername() {
    setState(() {
      _phase = _LoginPhase.username;
      _resolvedEmail = null;
      _passwordController.clear();
    });
  }

  Future<void> _handleContinueUsername() async {
    if (_phase != _LoginPhase.username) return;
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    final username = _usernameController.text.trim();
    final authProvider = context.read<AuthProvider>();

    setState(() => _isResolving = true);
    authProvider.clearError();

    try {
      final result = await authProvider.resolveUsername(username);

      if (!mounted) return;

      if (result.useGoogle) {
        setState(() {
          _phase = _LoginPhase.google;
          _resolvedEmail = null;
        });
        return;
      }

      if (result.needsMigration) {
        authProvider.beginLegacyMigration(result);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SecureAccountScreen(
              prefilledEmail: result.prefilledEmail,
            ),
          ),
        );
        return;
      }

      final email = result.email;
      if (email == null || email.isEmpty) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: 'Could not resolve this username. Please try again.',
          onRetry: _handleContinueUsername,
        );
        return;
      }

      setState(() {
        _phase = _LoginPhase.password;
        _resolvedEmail = email;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ErrorHandler.showErrorSnackbar(
        context,
        message: e.statusCode == 429
            ? 'Too many attempts. Please wait a moment and try again.'
            : e.message,
        onRetry: _handleContinueUsername,
      );
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showErrorSnackbar(
        context,
        message: ErrorHandler.getErrorMessage(e),
        onRetry: _handleContinueUsername,
      );
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _handlePasswordLogin() async {
    if (_phase != _LoginPhase.password) return;
    if (!_formKey.currentState!.validate()) return;

    final email = _resolvedEmail;
    if (email == null || email.isEmpty) {
      _resetToUsername();
      return;
    }

    HapticFeedback.lightImpact();
    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.loginWithFirebaseEmail(
      email: email,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      navigateAfterAuthentication(context, authProvider);
    } else if (authProvider.error != null && authProvider.error!.isNotEmpty) {
      ErrorHandler.showErrorSnackbar(
        context,
        message: authProvider.error!,
        onRetry: _handlePasswordLogin,
      );
    }
  }

  Future<void> _handleGoogleLogin() async {
    HapticFeedback.lightImpact();
    final authProvider = context.read<AuthProvider>();
    authProvider.clearGoogleRegistrationRequired();

    final success = await authProvider.loginWithGoogle();

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

  void _handlePrimaryAction() {
    switch (_phase) {
      case _LoginPhase.username:
        _handleContinueUsername();
      case _LoginPhase.password:
        _handlePasswordLogin();
      case _LoginPhase.google:
        _handleGoogleLogin();
    }
  }

  String get _primaryButtonLabel {
    switch (_phase) {
      case _LoginPhase.username:
        return 'Continue';
      case _LoginPhase.password:
        return 'Log In';
      case _LoginPhase.google:
        return 'Continue with Google';
    }
  }

  bool _isPrimaryLoading(AuthProvider authProvider) {
    if (_phase == _LoginPhase.username) {
      return _isResolving;
    }
    return authProvider.isLoading;
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
                          // Username field (step 1)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _phase == _LoginPhase.username
                                      ? 'Username'
                                      : 'Signing in as',
                                  style: PrismTextStyles.bodyMedium,
                                ),
                              ),
                              if (_phase != _LoginPhase.username)
                                TextButton(
                                  onPressed: _isResolving
                                      ? null
                                      : () {
                                          HapticFeedback.selectionClick();
                                          _resetToUsername();
                                        },
                                  child: Text(
                                    'Change',
                                    style: PrismTextStyles.bodySmall.copyWith(
                                      color: PrismColors.prismYellow,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ).animate().fadeIn(delay: 300.ms),
                          SizedBox(height: labelToInputSpacing),
                          TextFormField(
                            controller: _usernameController,
                            style: PrismTextStyles.bodyLarge,
                            textInputAction: _phase == _LoginPhase.username
                                ? TextInputAction.done
                                : TextInputAction.next,
                            autocorrect: false,
                            readOnly: _phase != _LoginPhase.username,
                            onFieldSubmitted: (_) {
                              if (_phase == _LoginPhase.username) {
                                _handleContinueUsername();
                              }
                            },
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

                          if (_phase == _LoginPhase.password) ...[
                            SizedBox(height: inputToInputSpacing),
                            if (_resolvedEmail != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  _resolvedEmail!,
                                  style: PrismTextStyles.bodySmall.copyWith(
                                    color: PrismColors.secondaryText,
                                  ),
                                ),
                              ),
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
                              onFieldSubmitted: (_) => _handlePasswordLogin(),
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
                          ],

                          if (_phase == _LoginPhase.google) ...[
                            SizedBox(height: inputToInputSpacing),
                            Text(
                              'This account uses Google Sign-In.',
                              textAlign: TextAlign.center,
                              style: PrismTextStyles.bodyMedium.copyWith(
                                color: PrismColors.secondaryText,
                              ),
                            ).animate().fadeIn(delay: 400.ms),
                          ],

                          SizedBox(height: inputToInputSpacing),

                          Consumer<AuthProvider>(
                                builder: (context, authProvider, child) {
                                  return PrismButton(
                                    text: _primaryButtonLabel,
                                    isLoading: _isPrimaryLoading(authProvider),
                                    onPressed: _isPrimaryLoading(authProvider)
                                        ? null
                                        : _handlePrimaryAction,
                                    type: _phase == _LoginPhase.google
                                        ? PrismButtonType.secondary
                                        : PrismButtonType.primary,
                                    icon: _phase == _LoginPhase.google
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
