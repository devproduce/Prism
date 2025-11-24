import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/utils/theme.dart';
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
      // Check if contacts need to be synced
      if (!authProvider.contactsSynced) {
        await _showContactSyncDialog(authProvider);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Login failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showContactSyncDialog(AuthProvider authProvider) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkDotInactive,
        title: Text(
          'Sync Contacts',
          style: TextStyle(color: AppTheme.primaryText(context)),
        ),
        content: Text(
          'Prism would like to access your contacts to help you find and connect with friends who are already using the app.',
          style: TextStyle(color: AppTheme.secondaryText(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Not Now',
              style: TextStyle(color: AppTheme.tertiaryText(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Allow',
              style: TextStyle(color: Color(0xFF4A90E2)),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: AppTheme.primaryAccent),
        ),
      );

      // Sync contacts
      final success = await authProvider.syncContacts();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Contacts synced successfully!'
                  : 'Failed to sync contacts. You can try again later in settings.',
            ),
            backgroundColor: success ? Colors.green : Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final horizontalPadding = AppTheme.horizontalPadding(context);
    final buttonHeight = AppTheme.buttonHeight(context);

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.05),

                  // Bookmark Icon
                  Icon(
                    Icons.bookmark,
                    size: size.width * 0.10,
                    color: AppTheme.primaryAccent,
                  ),

                  SizedBox(height: size.height * 0.02),

                  // Welcome Back Header
                  Text('Welcome Back', style: AppTheme.headlineStyle(context)),

                  SizedBox(height: size.height * 0.005),

                  // Subtitle
                  Text(
                    'Login to your Prism account',
                    style: AppTheme.subHeadlineStyle(context),
                  ),

                  SizedBox(height: size.height * 0.04),

                  // Username/Email Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Username',
                        style: AppTheme.headlineStyle(
                          context,
                        ).copyWith(fontSize: size.width * 0.035),
                      ),
                      SizedBox(height: size.height * 0.01),
                      TextFormField(
                        controller: _emailController,
                        style: TextStyle(color: AppTheme.primaryText(context)),
                        decoration: InputDecoration(
                          hintText: 'Username',
                          hintStyle: TextStyle(
                            color: AppTheme.tertiaryText(context),
                          ),
                          filled: true,
                          fillColor: AppTheme.darkDotInactive,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: size.width * 0.04,
                            vertical: size.height * 0.02,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your username or email';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: size.height * 0.02),

                  // Password Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Password',
                        style: AppTheme.headlineStyle(
                          context,
                        ).copyWith(fontSize: size.width * 0.035),
                      ),
                      SizedBox(height: size.height * 0.01),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: AppTheme.primaryText(context)),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(
                            color: AppTheme.tertiaryText(context),
                          ),
                          filled: true,
                          fillColor: AppTheme.darkDotInactive,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: size.width * 0.04,
                            vertical: size.height * 0.02,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppTheme.tertiaryText(context),
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
                      ),
                    ],
                  ),

                  // Forgot Password Link
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Forgot your password?',
                        style: TextStyle(
                          color: const Color(0xFF4A90E2),
                          fontSize: size.width * 0.035,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.025),

                  // Login Button
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      return GestureDetector(
                        onTap: authProvider.isLoading ? null : _handleLogin,
                        child: Container(
                          height: buttonHeight,
                          decoration: AppTheme.primaryButtonDecoration(),
                          child: Center(
                            child: authProvider.isLoading
                                ? CircularProgressIndicator(
                                    color: AppTheme.buttonText,
                                  )
                                : Text(
                                    'Log In',
                                    style: AppTheme.buttonTextStyle(context),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: size.height * 0.025),

                  // Or continue with
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppTheme.darkDotInactive,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.03,
                        ),
                        child: Text(
                          'Or continue with',
                          style: AppTheme.subHeadlineStyle(
                            context,
                          ).copyWith(fontSize: size.width * 0.032),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppTheme.darkDotInactive,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: size.height * 0.02),

                  // SSO Buttons
                  _buildSSOButton(context, 'Google', Icons.g_mobiledata, () {
                    // TODO: Implement Google SSO
                  }),

                  SizedBox(height: size.height * 0.012),

                  _buildSSOButton(context, 'Apple', Icons.apple, () {
                    // TODO: Implement Apple SSO
                  }),

                  SizedBox(height: size.height * 0.025),

                  // Create Account Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: AppTheme.subHeadlineStyle(
                          context,
                        ).copyWith(fontSize: size.width * 0.035),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            color: const Color(0xFF4A90E2),
                            fontSize: size.width * 0.035,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: size.height * 0.03),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSSOButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    final size = MediaQuery.of(context).size;
    final buttonHeight = AppTheme.buttonHeight(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: buttonHeight,
        decoration: BoxDecoration(
          color: AppTheme.darkDotInactive,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryText(context)),
            SizedBox(width: size.width * 0.02),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.primaryText(context),
                fontSize: size.width * 0.040,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
