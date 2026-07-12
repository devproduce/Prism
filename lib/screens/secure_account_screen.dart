import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/utils/auth_navigation.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/widgets/prism_text_field.dart';

class SecureAccountScreen extends StatefulWidget {
  const SecureAccountScreen({super.key, this.prefilledEmail});

  final String? prefilledEmail;

  @override
  State<SecureAccountScreen> createState() => _SecureAccountScreenState();
}

class _SecureAccountScreenState extends State<SecureAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.prefilledEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.migrateLegacyAccount(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      if (success) {
        HapticFeedback.heavyImpact();
        navigateAfterAuthentication(context, authProvider);
      } else if (authProvider.error != null) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: authProvider.error!,
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleLogout() async {
    await context.read<AuthProvider>().forceLogout(context);
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Secure your account',
          style: PrismTextStyles.h3.copyWith(color: PrismColors.white),
        ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Please provide your email address to secure your account.',
                  style: PrismTextStyles.bodyMedium.copyWith(
                    color: PrismColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 24),
                PrismCard(
                  child: Column(
                    children: [
                      PrismTextField(
                        controller: _emailController,
                        hintText: 'Email address',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      PrismButton(
                        text: 'Secure my account',
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        isLoading: _isSubmitting,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
