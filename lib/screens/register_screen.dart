import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/widgets/gradient_background.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/screens/login_screen.dart';
import 'package:prism/screens/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 7; // Updated from 6 to 7

  // Form controllers
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _pronounsController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();

  // Form keys
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _step4Key = GlobalKey<FormState>();
  final _step5Key = GlobalKey<FormState>();
  final _step6Key = GlobalKey<FormState>();
  final _step7Key = GlobalKey<FormState>();

  File? _faceIdImage; // For face recognition (required)
  File? _profilePicImage; // For profile display (optional)
  DateTime? _selectedDob;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pronounsController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _pickFaceIdImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera, // Camera only for face recognition
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _faceIdImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickProfilePicture() async {
    // Show dialog to choose camera or gallery
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PrismColors.darkCard,
        title: Text('Choose Image Source', style: PrismTextStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: PrismColors.electricBlue,
              ),
              title: Text('Camera', style: PrismTextStyles.bodyLarge),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: PrismColors.electricBlue,
              ),
              title: Text('Gallery', style: PrismTextStyles.bodyLarge),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() {
          _profilePicImage = File(pickedFile.path);
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: PrismColors.purple,
              onPrimary: Colors.white,
              surface: PrismColors.darkCard,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = '${picked.month}/${picked.day}/${picked.year}';
      });
    }
  }

  Future<void> _handleRegister() async {
    if (_faceIdImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture your face ID image'),
          backgroundColor: PrismColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim().isEmpty
        ? null
        : _lastNameController.text.trim();

    // Register with face ID image
    final success = await authProvider.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: firstName,
      lastName: lastName,
      profileImage: _faceIdImage!, // Use face ID image for registration
    );

    if (success && mounted) {
      // Update optional profile fields if provided
      if (_pronounsController.text.trim().isNotEmpty ||
          _selectedDob != null ||
          _phoneController.text.trim().isNotEmpty) {
        await authProvider.updateProfile(
          username: _usernameController.text.trim(),
          firstName: firstName,
          lastName: lastName,
          pronouns: _pronounsController.text.trim().isEmpty
              ? null
              : _pronounsController.text.trim(),
          dob: _selectedDob,
          phoneNumber: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
        );
      }

      // Upload profile picture if provided
      if (_profilePicImage != null && mounted) {
        final profilePicSuccess = await authProvider.uploadProfilePicture(
          _profilePicImage!,
        );
        if (!profilePicSuccess && mounted) {
          // Show warning but don't block registration completion
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                authProvider.error ?? 'Failed to upload profile picture',
              ),
              backgroundColor: PrismColors.warningYellow,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                HomeScreen(key: HomeScreen.homeScreenKey),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Registration failed'),
          backgroundColor: PrismColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  InputDecoration _glassInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      labelText: hint,
      labelStyle: PrismTextStyles.bodyMedium.copyWith(color: Colors.white54),
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
        body: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      onPressed: _currentPage > 0
                          ? _previousPage
                          : () => Navigator.of(context).pushReplacement(
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) =>
                                    const LoginScreen(),
                                transitionsBuilder: (_, animation, __, child) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                              ),
                            ),
                    ),
                    const Spacer(),
                    // Progress Dots
                    Row(
                      children: List.generate(_totalPages, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage >= index
                                ? PrismColors.electricBlue
                                : Colors.white.withOpacity(0.1),
                            boxShadow: _currentPage >= index
                                ? [
                                    BoxShadow(
                                      color: PrismColors.electricBlue
                                          .withOpacity(0.5),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),

              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    _buildStepTemplate(
                      key: const ValueKey('step1'),
                      formKey: _step1Key,
                      title: 'Claim Your Name',
                      subtitle:
                          'Create a unique handle for your Prism identity.',
                      fields: [
                        TextFormField(
                          controller: _usernameController,
                          style: PrismTextStyles.bodyLarge,
                          decoration: _glassInputDecoration(
                            'Username',
                            Icons.alternate_email,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Please enter a username';
                            if (value.length < 3)
                              return 'Username must be at least 3 characters';
                            return null;
                          },
                        ),
                      ],
                      onNext: () {
                        if (_step1Key.currentState!.validate()) _nextPage();
                      },
                    ),
                    _buildStepTemplate(
                      key: const ValueKey('step2'),
                      formKey: _step2Key,
                      title: 'Who Are You?',
                      subtitle: 'So your friends know it\'s really you.',
                      fields: [
                        TextFormField(
                          controller: _firstNameController,
                          style: PrismTextStyles.bodyLarge,
                          decoration: _glassInputDecoration(
                            'First Name',
                            Icons.person_outline,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Please enter your first name';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _lastNameController,
                          style: PrismTextStyles.bodyLarge,
                          decoration: _glassInputDecoration(
                            'Last Name (Optional)',
                            Icons.person_outline,
                          ),
                        ),
                      ],
                      onNext: () {
                        if (_step2Key.currentState!.validate()) _nextPage();
                      },
                    ),
                    _buildStepTemplate(
                      key: const ValueKey('step3'),
                      formKey: _step3Key,
                      title: 'Contact Info',
                      subtitle: 'For verification and keeping you in the loop.',
                      fields: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: PrismTextStyles.bodyLarge,
                          decoration: _glassInputDecoration(
                            'Email Address',
                            Icons.email_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Please enter your email';
                            if (!value.contains('@') || !value.contains('.'))
                              return 'Please enter a valid email';
                            return null;
                          },
                        ),
                      ],
                      onNext: () {
                        if (_step3Key.currentState!.validate()) _nextPage();
                      },
                    ),
                    _buildStepTemplate(
                      key: const ValueKey('step4'),
                      formKey: _step4Key,
                      title: 'Secure It',
                      subtitle: 'Make it strong. Make it safe.',
                      fields: [
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: PrismTextStyles.bodyLarge,
                          decoration:
                              _glassInputDecoration(
                                'Password',
                                Icons.lock_outline,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Please enter a password';
                            if (value.length < 6)
                              return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: PrismTextStyles.bodyLarge,
                          decoration:
                              _glassInputDecoration(
                                'Confirm Password',
                                Icons.lock_outline,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  ),
                                ),
                              ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Please confirm your password';
                            if (value != _passwordController.text)
                              return 'Passwords do not match';
                            return null;
                          },
                        ),
                      ],
                      onNext: () {
                        if (_step4Key.currentState!.validate()) _nextPage();
                      },
                    ),
                    _buildStepTemplate(
                      key: const ValueKey('step5'),
                      formKey: _step5Key,
                      title: 'Vibe Check',
                      subtitle:
                          'A few extra details to personalize your profile.',
                      fields: [
                        TextFormField(
                          controller: _pronounsController,
                          style: PrismTextStyles.bodyLarge,
                          decoration: _glassInputDecoration(
                            'Pronouns (Optional)',
                            Icons.face,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _dobController,
                          readOnly: true,
                          onTap: _selectDate,
                          style: PrismTextStyles.bodyLarge,
                          decoration: _glassInputDecoration(
                            'Date of Birth (Optional)',
                            Icons.calendar_today,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: PrismTextStyles.bodyLarge,
                          decoration: _glassInputDecoration(
                            'Phone Number (Optional)',
                            Icons.phone,
                          ),
                        ),
                      ],
                      onNext: () {
                        if (_step5Key.currentState!.validate()) _nextPage();
                      },
                    ),
                    // Step 6: Face ID Recognition (Required)
                    _buildStepTemplate(
                      key: const ValueKey('step6'),
                      formKey: _step6Key,
                      title: 'Face ID Recognition',
                      subtitle:
                          'For secure face recognition. Required for account creation.',
                      fields: [
                        Center(
                          child: GestureDetector(
                            onTap: _pickFaceIdImage,
                            child:
                                Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.45,
                                  height:
                                      MediaQuery.of(context).size.width * 0.45,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: PrismColors.prismSignature,
                                    boxShadow: [
                                      BoxShadow(
                                        color: PrismColors.purple.withOpacity(
                                          0.5,
                                        ),
                                        blurRadius: 30,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: PrismColors.darkBase,
                                      image: _faceIdImage != null
                                          ? DecorationImage(
                                              image: FileImage(_faceIdImage!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: _faceIdImage == null
                                        ? const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 50,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ).animate().scale(
                                  curve: Curves.elasticOut,
                                  duration: 800.ms,
                                ),
                          ),
                        ),
                        if (_faceIdImage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Center(
                              child: const Text(
                                'Face ID Captured! ✨',
                                style: TextStyle(
                                  color: PrismColors.successGreen,
                                ),
                              ).animate().fadeIn().moveY(begin: 10, end: 0),
                            ),
                          ),
                      ],
                      onNext: () {
                        if (_step6Key.currentState!.validate()) _nextPage();
                      },
                    ),
                    // Step 7: Profile Picture (Optional)
                    _buildStepTemplate(
                      key: const ValueKey('step7'),
                      formKey: _step7Key,
                      title: 'Profile Picture',
                      subtitle:
                          'Optional - Skip to use your Face ID photo as your profile picture.',
                      fields: [
                        Center(
                          child: GestureDetector(
                            onTap: _pickProfilePicture,
                            child:
                                Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.45,
                                  height:
                                      MediaQuery.of(context).size.width * 0.45,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: _profilePicImage != null
                                        ? PrismColors.prismSignature
                                        : LinearGradient(
                                            colors: [
                                              PrismColors.electricBlue
                                                  .withOpacity(0.3),
                                              PrismColors.purple.withOpacity(
                                                0.3,
                                              ),
                                            ],
                                          ),
                                    boxShadow: _profilePicImage != null
                                        ? [
                                            BoxShadow(
                                              color: PrismColors.electricBlue
                                                  .withOpacity(0.5),
                                              blurRadius: 30,
                                              offset: const Offset(0, 10),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: PrismColors.darkBase,
                                      image: _profilePicImage != null
                                          ? DecorationImage(
                                              image: FileImage(
                                                _profilePicImage!,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: _profilePicImage == null
                                        ? const Icon(
                                            Icons.add_photo_alternate_rounded,
                                            size: 50,
                                            color: Colors.white54,
                                          )
                                        : null,
                                  ),
                                ).animate().scale(
                                  curve: Curves.elasticOut,
                                  duration: 800.ms,
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            _profilePicImage == null
                                ? 'Tap to add a profile picture\nor skip to use Face ID photo'
                                : 'Looking good! 🎉',
                            textAlign: TextAlign.center,
                            style: PrismTextStyles.bodyMedium.copyWith(
                              color: _profilePicImage != null
                                  ? PrismColors.successGreen
                                  : Colors.white60,
                            ),
                          ).animate().fadeIn(),
                        ),
                      ],
                      onNext: () async {
                        if (_step7Key.currentState!.validate()) {
                          await _handleRegister();
                        }
                      },
                      isLastStep: true,
                      buttonText: 'Start Exploring',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepTemplate({
    required Key key,
    required GlobalKey<FormState> formKey,
    required String title,
    required String subtitle,
    required List<Widget> fields,
    required VoidCallback onNext,
    bool isLastStep = false,
    String buttonText = 'Next',
  }) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(24.0),
      child: GlassCard(
        borderRadius: 30,
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: PrismTextStyles.h2,
              ).animate().fadeIn().moveY(begin: 10, end: 0),

              const SizedBox(height: 8),

              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: PrismTextStyles.bodyMedium.copyWith(
                  color: Colors.white60,
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 32),

              ...fields
                  .animate(interval: 100.ms)
                  .fadeIn()
                  .moveX(begin: 20, end: 0),

              const SizedBox(height: 40),

              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return GlassButton(
                    text: buttonText,
                    isLoading: authProvider.isLoading,
                    onPressed: authProvider.isLoading ? null : onNext,
                    isPrimary: true,
                    icon: isLastStep
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                  );
                },
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}
