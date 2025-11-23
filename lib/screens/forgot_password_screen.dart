import 'package:flutter/material.dart';
import 'package:prism/utils/theme.dart';
import 'package:prism/screens/login_screen.dart';

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

    setState(() => _isLoading = true);

    // TODO: Implement forgot password API call
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset link sent to your email'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
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
                  SizedBox(height: size.height * 0.12),

                  // Header
                  Text(
                    'Forgot Password?',
                    style: AppTheme.headlineStyle(context),
                  ),

                  SizedBox(height: size.height * 0.015),

                  // Subtitle
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.05,
                    ),
                    child: Text(
                      'Enter your email and we\'ll send you a link to reset your password.',
                      textAlign: TextAlign.center,
                      style: AppTheme.subHeadlineStyle(context),
                    ),
                  ),

                  SizedBox(height: size.height * 0.05),

                  // Email Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email',
                        style: AppTheme.subHeadlineStyle(
                          context,
                        ).copyWith(fontSize: size.width * 0.035),
                      ),
                      SizedBox(height: size.height * 0.01),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: AppTheme.primaryText(context)),
                        decoration: InputDecoration(
                          hintText: 'Enter Email',
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
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: size.height * 0.04),

                  // Send Link Button
                  GestureDetector(
                    onTap: _isLoading ? null : _handleSendLink,
                    child: Container(
                      height: buttonHeight,
                      decoration: AppTheme.primaryButtonDecoration(),
                      child: Center(
                        child: _isLoading
                            ? CircularProgressIndicator(
                                color: AppTheme.buttonText,
                              )
                            : Text(
                                'Send Link',
                                style: AppTheme.buttonTextStyle(context),
                              ),
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.35),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTheme.subHeadlineStyle(
                          context,
                        ).copyWith(fontSize: size.width * 0.035),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Log in',
                          style: TextStyle(
                            color: const Color(0xFF4A90E2),
                            fontSize: size.width * 0.035,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
