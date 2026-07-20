import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/screens/complete_profile_screen.dart';
import 'package:prism/screens/login_screen.dart';
import 'package:prism/screens/register_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/auth_navigation.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:prism/widgets/continue_with_google_button.dart';
import 'package:prism/widgets/prism_card.dart';

/// Entry screen before account creation: Google or email/password signup.
class SignUpChoiceScreen extends StatefulWidget {
  const SignUpChoiceScreen({super.key});

  @override
  State<SignUpChoiceScreen> createState() => _SignUpChoiceScreenState();
}

class _SignUpChoiceScreenState extends State<SignUpChoiceScreen> {
  bool _isSubmitting = false;

  bool _isLoading(AuthProvider authProvider) {
    return _isSubmitting || authProvider.isLoading;
  }

  Future<void> _handleGoogleSignUp() async {
    HapticFeedback.lightImpact();
    final authProvider = context.read<AuthProvider>();
    authProvider.clearGoogleRegistrationRequired();

    setState(() => _isSubmitting = true);
    final success = await authProvider.loginWithGoogle();
    if (mounted) setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      navigateAfterAuthentication(context, authProvider, clearStack: true);
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
        onRetry: _handleGoogleSignUp,
      );
    }
  }

  void _handleEmailSignUp() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RegisterScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _goToLogin() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
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
    final optionGap = isCompact ? 12.0 : 16.0;
    final cardPadding = EdgeInsets.symmetric(
      horizontal: screenWidth < 360 ? 16.0 : 20.0,
      vertical: isCompact ? 14.0 : 18.0,
    );
    final emailBoxHeight = screenWidth < 360 ? 44.0 : 48.0;
    final emailIconSize = screenWidth < 360 ? 20.0 : 22.0;
    final emailFontSize = screenWidth < 360 ? 14.0 : 16.0;
    final emailBorderRadius = screenWidth < 360 ? 12.0 : 14.0;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: PrismColors.white.withValues(alpha: 0.8),
            size: screenWidth < 360 ? 18 : 20,
          ),
          onPressed: _isSubmitting ? null : _goToLogin,
        ),
      ),
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
                          Icons.person_add_alt_1_rounded,
                          size: headerIconSize,
                          color: PrismColors.prismYellow,
                        ),
                      ).animate().scale(
                        duration: 500.ms,
                        curve: Curves.elasticOut,
                      ),
                      SizedBox(height: optionGap),
                      Text(
                        'Create your account',
                        textAlign: TextAlign.center,
                        style: PrismTextStyles.h1,
                      ).animate().fadeIn().moveY(begin: 10, end: 0),
                      SizedBox(height: isCompact ? 6.0 : 8.0),
                      Text(
                        'Choose how you want to join Prism.',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, child) {
                            return ContinueWithGoogleButton(
                              text: 'Sign up with Google',
                              isLoading: _isLoading(authProvider),
                              onPressed: _isLoading(authProvider)
                                  ? null
                                  : _handleGoogleSignUp,
                            );
                          },
                        )
                            .animate()
                            .fadeIn(delay: 300.ms)
                            .moveY(begin: 10, end: 0),
                        SizedBox(height: optionGap),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color:
                                    PrismColors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth < 360 ? 10.0 : 14.0,
                              ),
                              child: Text(
                                'or',
                                style: PrismTextStyles.bodySmall.copyWith(
                                  color: PrismColors.secondaryText,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color:
                                    PrismColors.white.withValues(alpha: 0.15),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 350.ms),
                        SizedBox(height: optionGap),
                        SizedBox(
                          width: double.infinity,
                          height: emailBoxHeight,
                          child: Material(
                            color: PrismColors.inputGray,
                            borderRadius:
                                BorderRadius.circular(emailBorderRadius),
                            child: InkWell(
                              onTap: _isSubmitting ? null : _handleEmailSignUp,
                              borderRadius:
                                  BorderRadius.circular(emailBorderRadius),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(emailBorderRadius),
                                  border: Border.all(
                                    color: PrismColors.white
                                        .withValues(alpha: 0.12),
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth < 360 ? 16.0 : 20.0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.email_outlined,
                                      color: PrismColors.prismYellow,
                                      size: emailIconSize,
                                    ),
                                    SizedBox(
                                      width: screenWidth < 360 ? 10.0 : 12.0,
                                    ),
                                    Flexible(
                                      child: Text(
                                        'Sign up with Email',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: PrismTextStyles.button.copyWith(
                                          color: PrismColors.white,
                                          fontSize: emailFontSize,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 400.ms)
                            .moveY(begin: 10, end: 0),
                      ],
                    ),
                  ),
                  SizedBox(height: isCompact ? 20.0 : 32.0),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: PrismTextStyles.bodyMedium.copyWith(
                          color: PrismColors.secondaryText,
                        ),
                      ),
                      TextButton(
                        onPressed: _isSubmitting ? null : _goToLogin,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Log In',
                          style: PrismTextStyles.button.copyWith(
                            color: PrismColors.prismYellow,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 450.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
