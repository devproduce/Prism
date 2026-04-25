import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:provider/provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendLink() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.forgotPassword(_emailController.text);

      if (mounted) {
        setState(() => _isLoading = false);

        ErrorHandler.showSuccessSnackbar(
          context,
          message: 'Password reset link sent to your email',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showErrorSnackbar(
          context,
          message: ErrorHandler.getErrorMessage(e),
        );
      }
    }
  }

  InputDecoration _prismInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: PrismTextStyles.bodyMedium.copyWith(
        color: PrismColors.secondaryText,
      ),
      prefixIcon: Icon(icon, color: PrismColors.secondaryText),
      filled: true,
      fillColor: PrismColors.inputGray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: PrismColors.prismYellow,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: PrismColors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Reset Password', style: PrismTextStyles.h3),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PrismColors.surfaceGray,
                  border: Border.all(
                    color: PrismColors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  size: 48,
                  color: PrismColors.prismYellow,
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

              const SizedBox(height: 32),

              PrismCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Forgot Password?',
                        textAlign: TextAlign.center,
                        style: PrismTextStyles.h2,
                      ).animate().fadeIn().moveY(begin: 10, end: 0),

                      const SizedBox(height: 12),

                      Text(
                        'Enter your email address and we\'ll send you a link to reset your password.',
                        textAlign: TextAlign.center,
                        style: PrismTextStyles.bodyMedium.copyWith(
                          color: PrismColors.secondaryText,
                        ),
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 32),

                      Text(
                        'Email Address',
                        style: PrismTextStyles.bodyMedium,
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: PrismTextStyles.bodyLarge,
                        decoration: _prismInputDecoration(
                          'Enter your email',
                          Icons.email_outlined,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ).animate().fadeIn(delay: 350.ms),

                      const SizedBox(height: 32),

                      PrismButton(
                            text: 'Send Reset Link',
                            isLoading: _isLoading,
                            onPressed: _handleSendLink,
                            type: PrismButtonType.primary,
                          )
                          .animate()
                          .fadeIn(delay: 450.ms)
                          .moveY(begin: 10, end: 0),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Back to Log In',
                  style: PrismTextStyles.button.copyWith(
                    color: PrismColors.secondaryText,
                  ),
                ),
              ).animate().fadeIn(delay: 550.ms),
            ],
          ),
        ),
      ),
    );
  }
}
