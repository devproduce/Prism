import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/widgets/gradient_background.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/screens/forgot_password_screen.dart';
import 'package:prism/screens/register_screen.dart';
import 'package:prism/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      // Navigate immediately for better UX
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Login failed'),
          backgroundColor: PrismColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showContactSyncDialog(AuthProvider authProvider) async {
    // Keep existing dialog logic but maybe style it later if needed globally
    // For now, focusing on the main screen UI
    // ... logic remains same ...
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: PrismColors.darkCard,
        surfaceTintColor: Colors.transparent,
        title: Text('Sync Contacts', style: PrismTextStyles.h3),
        content: Text(
          'Prism would like to access your contacts to help you find and connect with friends who are already using the app.',
          style: PrismTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Not Now',
              style: TextStyle(color: PrismColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: PrismColors.purple),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            Center(child: CircularProgressIndicator(color: PrismColors.purple)),
      );

      final success = await authProvider.syncContacts();

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Contacts synced successfully!'
                  : 'Failed to sync contacts. You can try again later in settings.',
            ),
            backgroundColor: success
                ? PrismColors.successGreen
                : PrismColors.warningYellow,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  InputDecoration _glassInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: PrismTextStyles.bodyMedium.copyWith(color: Colors.white38),
      prefixIcon: Icon(icon, color: PrismColors.electricBlue),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: PrismColors.electricBlue.withOpacity(0.5),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Header
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: PrismColors.electricBlue.withOpacity(0.1),
                      ),
                      child: Icon(
                        Icons.waving_hand_rounded,
                        size: 40,
                        color: PrismColors.electricBlue,
                      ),
                    ).animate().scale(
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: PrismTextStyles.h1,
                    ).animate().fadeIn().moveY(begin: 10, end: 0),

                    const SizedBox(height: 8),

                    Text(
                      'Login to continue your vibe.',
                      textAlign: TextAlign.center,
                      style: PrismTextStyles.bodyMedium,
                    ).animate().fadeIn(delay: 200.ms),
                  ],
                ),

                const SizedBox(height: 48),

                // Form Card
                GlassCard(
                  borderRadius: 30,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email Field
                        Text(
                          'Email',
                          style: PrismTextStyles.bodyMedium,
                        ).animate().fadeIn(delay: 300.ms),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          style: PrismTextStyles.bodyLarge,
                          decoration: _glassInputDecoration(
                            'Enter your email',
                            Icons.email_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            return null;
                          },
                        ).animate().fadeIn(delay: 350.ms),

                        const SizedBox(height: 24),

                        // Password Field
                        Text(
                          'Password',
                          style: PrismTextStyles.bodyMedium,
                        ).animate().fadeIn(delay: 400.ms),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: PrismTextStyles.bodyLarge,
                          decoration:
                              _glassInputDecoration(
                                'Enter your password',
                                Icons.lock_outline,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () {
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
                            return null;
                          },
                        ).animate().fadeIn(delay: 450.ms),

                        // Forgot Password Link
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
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
                                color: PrismColors.electricBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 500.ms),

                        const SizedBox(height: 24),

                        // Login Button
                        Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                return GlassButton(
                                  text: 'Log In',
                                  isLoading: authProvider.isLoading,
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _handleLogin,
                                  isPrimary: true,
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

                const SizedBox(height: 32),

                // Create Account Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'New here? ',
                      style: PrismTextStyles.bodyMedium.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const RegisterScreen(),
                            transitionsBuilder: (_, animation, __, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                      child: Text(
                        'Create Account',
                        style: PrismTextStyles.button.copyWith(
                          color: PrismColors.neoPink,
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
    );
  }
}
