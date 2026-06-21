import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/auth_navigation.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/widgets/prism_card.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  int _resendCooldown = 0;

  Future<void> _startResendCooldown() async {
    setState(() => _resendCooldown = 60);
    while (_resendCooldown > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _resendCooldown--);
    }
  }

  Future<void> _handleResend() async {
    if (_resendCooldown > 0 || _isResending) return;
    HapticFeedback.lightImpact();
    setState(() => _isResending = true);
    try {
      await context.read<AuthProvider>().resendVerificationEmail();
      if (mounted) {
        ErrorHandler.showSuccessSnackbar(
          context,
          message: 'Verification email sent. Check your inbox.',
        );
        await _startResendCooldown();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: ErrorHandler.getErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _handleVerifiedCheck() async {
    if (_isChecking) return;
    HapticFeedback.mediumImpact();
    setState(() => _isChecking = true);
    try {
      final auth = context.read<AuthProvider>();
      final success = await auth.confirmEmailVerified();
      if (!mounted) return;
      if (success) {
        HapticFeedback.heavyImpact();
        navigateAfterAuthentication(context, auth);
      } else {
        ErrorHandler.showErrorSnackbar(
          context,
          message:
              'Email not verified yet. Check your inbox and spam folder, then try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: ErrorHandler.getErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _handleLogout() async {
    await context.read<AuthProvider>().forceLogout(context);
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthProvider>().currentUser?.email;
    final maskedEmail = email != null && email.isNotEmpty ? email : 'your email';

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _handleLogout,
            child: Text(
              'Log out',
              style: PrismTextStyles.bodyMedium.copyWith(
                color: PrismColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.mark_email_unread_outlined,
                size: 72,
                color: PrismColors.prismYellow.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify your email',
                style: PrismTextStyles.h2.copyWith(color: PrismColors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to $maskedEmail. Open it in your inbox, then return here.',
                style: PrismTextStyles.bodyMedium.copyWith(
                  color: PrismColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              PrismCard(
                child: Column(
                  children: [
                    PrismButton(
                      text: _isChecking ? 'Checking...' : "I've verified my email",
                      onPressed: _isChecking ? null : _handleVerifiedCheck,
                      isLoading: _isChecking,
                    ),
                    const SizedBox(height: 12),
                    PrismButton(
                      text: _resendCooldown > 0
                          ? 'Resend in ${_resendCooldown}s'
                          : 'Resend email',
                      onPressed: (_resendCooldown > 0 || _isResending)
                          ? null
                          : _handleResend,
                      isLoading: _isResending,
                      type: PrismButtonType.secondary,
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
