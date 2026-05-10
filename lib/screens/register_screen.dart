import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';

import 'package:prism/providers/auth_provider.dart';
import 'package:prism/screens/login_screen.dart';
import 'package:prism/screens/home_screen.dart';
import 'package:prism/screens/multi_view_capture_screen.dart';
import 'package:prism/utils/error_handler.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 5; // Step: Username, Phone, Password, FaceID, ProfilePic

  // Form controllers
  final _usernameController = TextEditingController();
  final _countryCodeController = TextEditingController(text: '91');
  final _phoneNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Form keys
  final _step1Key = GlobalKey<FormState>(); // Username
  final _step2Key = GlobalKey<FormState>(); // Phone
  final _step3Key = GlobalKey<FormState>(); // Name (optional)
  final _step4Key = GlobalKey<FormState>(); // Email (optional)
  final _step5Key = GlobalKey<FormState>(); // Password
  final _step6Key = GlobalKey<FormState>(); // Face ID
  final _step7Key = GlobalKey<FormState>(); // Profile Pic

  List<String>? _faceIds;
  File? _profilePicImage;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  Timer? _usernameDebounce;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _pageController.dispose();
    _usernameController.dispose();
    _countryCodeController.dispose();
    _phoneNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  void _onUsernameChanged(String value) {
    if (_usernameDebounce?.isActive ?? false) _usernameDebounce!.cancel();
    if (value.trim().length < 3) {
      if (mounted) setState(() { _isUsernameAvailable = null; _isCheckingUsername = false; });
      return;
    }
    
    if (mounted) setState(() { _isCheckingUsername = true; _isUsernameAvailable = null; });
    
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isAvailable = await authProvider.checkUsernameAvailability(value.trim());
      if (mounted && _usernameController.text.trim() == value.trim()) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = isAvailable;
        });
      }
    });
  }

  Future<void> _fetchPhoneNumber() async {
    try {
      final hint = await SmsAutoFill().hint;
      if (hint != null && hint.isNotEmpty && mounted) {
        String digitsOnly = hint.replaceAll(RegExp(r'[^\d+]'), '');
        if (digitsOnly.startsWith('+')) {
          if (digitsOnly.startsWith('+91') && digitsOnly.length > 3) {
            _countryCodeController.text = '91';
            _phoneNumberController.text = digitsOnly.substring(3);
          } else if (digitsOnly.startsWith('+1') && digitsOnly.length > 2) {
            _countryCodeController.text = '1';
            _phoneNumberController.text = digitsOnly.substring(2);
          } else if (digitsOnly.startsWith('+44') && digitsOnly.length > 3) {
            _countryCodeController.text = '44';
            _phoneNumberController.text = digitsOnly.substring(3);
          } else {
            // If unknown country code, put everything in phone number field
            _phoneNumberController.text = digitsOnly;
          }
        } else {
           _phoneNumberController.text = digitsOnly;
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch phone number hint: $e');
    }
  }

  Future<void> _startFaceIdScan() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const MultiViewCaptureScreen()),
    );

    if (result != null) {
      if (result is Map) {
        // New format with image path
        final faces = result['faceIds'];
        final imagePath = result['imagePath'] as String?;

        if (faces is List<String>) {
          setState(() {
            _faceIds = faces;
            // Set captured face as default profile picture
            if (imagePath != null) {
              _profilePicImage = File(imagePath);
            }
          });
        }
      } else if (result is List<String>) {
        // Fallback for list only
        setState(() {
          _faceIds = result;
        });
      }
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

  /// Handle registration on Face ID screen (Step 6)
  Future<void> _handleFaceRevealNext() async {
    if (_faceIds == null || _faceIds!.isEmpty) {
      ErrorHandler.showErrorSnackbar(
        context,
        message: 'Please complete the Face ID scan to continue.',
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.clearDatabaseBeforeRegistration();

    final success = await authProvider.register(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      countryCode: _countryCodeController.text.trim(),
      phoneNumber: _phoneNumberController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      firstName: _firstNameController.text.trim().isEmpty
          ? null
          : _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim().isEmpty
          ? null
          : _lastNameController.text.trim(),
      profileImage: _profilePicImage,
      faceIds: _faceIds,
    );

    if (success && mounted) {
      if (authProvider.phoneSyncWarning) {
        ErrorHandler.showInfoSnackbar(
          context,
          message: 'Phone number couldn\'t be verified. Update it in Settings to appear in contact searches.',
          duration: const Duration(seconds: 6),
        );
      }
      _nextPage();
    } else if (mounted) {
      ErrorHandler.showErrorSnackbar(
        context,
        message: authProvider.error ?? 'Registration failed. Please try again.',
      );
    }
  }

  /// Handle profile picture upload and navigation to home (Step 7)
  Future<void> _handleProfilePictureNext() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Upload profile picture if provided
    if (_profilePicImage != null && mounted) {
      final profilePicSuccess = await authProvider.uploadProfilePicture(
        _profilePicImage!,
      );
      if (!profilePicSuccess && mounted) {
        ErrorHandler.showInfoSnackbar(
          context,
          message: authProvider.error ?? 'Profile picture upload failed. You can update it later in Settings.',
        );
      }
    }

    // Navigate to home screen and clear all previous routes
    // This prevents the app from going back to splash/onboarding on rebuild
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              HomeScreen(key: HomeScreen.homeScreenKey),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
        (route) => false, // Remove all previous routes from the stack
      );
    }
  }

  InputDecoration _glassInputDecoration(String hint, [IconData? icon]) {
    return InputDecoration(
      labelText: hint,
      labelStyle: PrismTextStyles.bodyMedium.copyWith(color: Colors.white54),
      prefixIcon: icon != null ? Icon(icon, color: PrismColors.electricBlue) : null,
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
    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
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
                              pageBuilder: (_, __, ___) => const LoginScreen(),
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
                                    color: PrismColors.electricBlue.withOpacity(
                                      0.5,
                                    ),
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
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                  if (page == 1) {
                    _fetchPhoneNumber();
                  }
                },
                children: [
                  _buildStepTemplate(
                    key: const ValueKey('step1'),
                    formKey: _step1Key,
                    title: 'Claim Your Name',
                    subtitle: 'Create a unique handle for your Prism identity.',
                    fields: [
                      TextFormField(
                        controller: _usernameController,
                        style: PrismTextStyles.bodyLarge,
                        onChanged: _onUsernameChanged,
                        decoration: _glassInputDecoration(
                          'Username',
                          Icons.alternate_email,
                        ).copyWith(
                          suffixIcon: _usernameController.text.trim().length >= 3
                              ? (_isCheckingUsername
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(PrismColors.electricBlue),
                                        ),
                                      ),
                                    )
                                  : (_isUsernameAvailable != null
                                      ? (_isUsernameAvailable!
                                          ? const Icon(Icons.check_circle, color: Colors.green)
                                          : const Icon(Icons.cancel, color: Colors.red))
                                      : null))
                              : null,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a username';
                          }
                          if (value.trim().length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          if (_isUsernameAvailable == false) {
                            return 'Username is already taken';
                          }
                          return null;
                        },
                      ),
                    ],
                    onNext: () async {
                      if (_step1Key.currentState!.validate()) {
                        if (_isCheckingUsername) {
                          ErrorHandler.showInfoSnackbar(context, message: 'Checking username availability...');
                        } else if (_isUsernameAvailable == true) {
                          _nextPage();
                        } else if (_isUsernameAvailable == null) {
                          setState(() { _isCheckingUsername = true; });
                          final isAvailable = await Provider.of<AuthProvider>(context, listen: false).checkUsernameAvailability(_usernameController.text.trim());
                          if (mounted) {
                            setState(() { _isCheckingUsername = false; _isUsernameAvailable = isAvailable; });
                            if (isAvailable) {
                              _nextPage();
                            } else {
                              _step1Key.currentState!.validate();
                            }
                          }
                        } else {
                          _step1Key.currentState!.validate();
                        }
                      }
                    },
                  ),
                  // Step 2: Phone Number (MANDATORY - V2)
                  _buildStepTemplate(
                    key: const ValueKey('step2'),
                    formKey: _step2Key,
                    title: 'Your Phone Number',
                    subtitle: 'Used to find friends from your contacts.',
                    fields: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Country code field
                          SizedBox(
                            width: 65, // Reduced width
                            child: TextFormField(
                              controller: _countryCodeController,
                              keyboardType: TextInputType.number,
                              style: PrismTextStyles.bodyLarge,
                              decoration: _glassInputDecoration('').copyWith(
                                hintText: '91',
                                prefixText: '+',
                                prefixStyle: PrismTextStyles.bodyLarge.copyWith(color: Colors.white),
                                hintStyle: PrismTextStyles.bodyLarge.copyWith(color: Colors.white54),
                                floatingLabelBehavior: FloatingLabelBehavior.never,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                final digits = value.replaceAll('+', '').trim();
                                if (digits.isEmpty ||
                                    int.tryParse(digits) == null) {
                                  return 'Digits only';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Phone number field
                          Expanded(
                            child: TextFormField(
                              controller: _phoneNumberController,
                              keyboardType: TextInputType.phone,
                              style: PrismTextStyles.bodyLarge,
                              decoration: _glassInputDecoration(
                                'Phone Number',
                                Icons.phone_outlined,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                final digits = value.replaceAll(
                                  RegExp(r'[^\d]'),
                                  '',
                                );
                                if (digits.length < 7 || digits.length > 15) {
                                  return 'Enter a valid phone number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    onNext: () {
                      if (_step2Key.currentState!.validate()) _nextPage();
                    },
                  ),
                  // Step 3: Password
                  _buildStepTemplate(
                    key: const ValueKey('step3'),
                    formKey: _step5Key,
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
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
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
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                    onNext: () {
                      if (_step5Key.currentState!.validate()) _nextPage();
                    },
                  ),

                  // Step 4: Face ID Recognition (Required)
                  _buildStepTemplate(
                    key: const ValueKey('step4'),
                    formKey: _step6Key,
                    title: 'Face ID Recognition',
                    subtitle:
                        'For secure face recognition. Required for account creation.',
                    fields: [
                      Center(
                        child: GestureDetector(
                          onTap: _startFaceIdScan,
                          child:
                              Container(
                                width: MediaQuery.of(context).size.width * 0.45,
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
                                  ),
                                  child:
                                      _faceIds != null && _faceIds!.isNotEmpty
                                      ? const Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 80,
                                          color: PrismColors.successGreen,
                                        )
                                      : const Icon(
                                          Icons.face_retouching_natural_rounded,
                                          size: 60,
                                          color: Colors.white,
                                        ),
                                ),
                              ).animate().scale(
                                curve: Curves.elasticOut,
                                duration: 800.ms,
                              ),
                        ),
                      ),
                      if (_faceIds != null && _faceIds!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Center(
                            child: const Text(
                              'Face ID Captured! ✨',
                              style: TextStyle(color: PrismColors.successGreen),
                            ).animate().fadeIn().moveY(begin: 10, end: 0),
                          ),
                        ),
                      if (_faceIds == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Center(
                            child: const Text(
                              'Tap to start face scan',
                              style: TextStyle(color: Colors.white60),
                            ).animate().fadeIn(),
                          ),
                        ),
                    ],
                    onNext: () async {
                      if (_faceIds != null && _faceIds!.isNotEmpty) {
                        await _handleFaceRevealNext();
                      } else {
                        ErrorHandler.showErrorSnackbar(
                          context,
                          message: 'Please complete the Face ID scan to continue.',
                        );
                      }
                    },
                    buttonText: 'Register',
                  ),
                  // Step 5: Profile Picture (Optional)
                  SingleChildScrollView(
                    key: const ValueKey('step5'),
                    padding: const EdgeInsets.all(24.0),
                    child: GlassCard(
                      borderRadius: 30,
                      child: Form(
                        key: _step7Key,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Skip button aligned to the right
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () async {
                                  await _handleProfilePictureNext();
                                },
                                icon: const Icon(
                                  Icons.skip_next_rounded,
                                  color: Colors.white60,
                                ),
                                label: Text(
                                  'Skip',
                                  style: PrismTextStyles.bodyMedium.copyWith(
                                    color: Colors.white60,
                                  ),
                                ),
                              ).animate().fadeIn(),
                            ),

                            Text(
                              'Profile Picture',
                              textAlign: TextAlign.center,
                              style: PrismTextStyles.h2,
                            ).animate().fadeIn().moveY(begin: 10, end: 0),

                            const SizedBox(height: 8),

                            Text(
                              'Optional - Skip to use your Face ID photo as your profile picture.',
                              textAlign: TextAlign.center,
                              style: PrismTextStyles.bodyMedium.copyWith(
                                color: Colors.white60,
                              ),
                            ).animate().fadeIn(delay: 200.ms),

                            const SizedBox(height: 32),
                            Center(
                              child: GestureDetector(
                                onTap: _pickProfilePicture,
                                child:
                                    Container(
                                      width:
                                          MediaQuery.of(context).size.width *
                                          0.45,
                                      height:
                                          MediaQuery.of(context).size.width *
                                          0.45,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: _profilePicImage != null
                                            ? PrismColors.prismSignature
                                            : LinearGradient(
                                                colors: [
                                                  PrismColors.electricBlue
                                                      .withOpacity(0.3),
                                                  PrismColors.purple
                                                      .withOpacity(0.3),
                                                ],
                                              ),
                                        boxShadow: _profilePicImage != null
                                            ? [
                                                BoxShadow(
                                                  color: PrismColors
                                                      .electricBlue
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
                                                Icons
                                                    .add_photo_alternate_rounded,
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
                            const SizedBox(height: 40),

                            Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                return GlassButton(
                                  text: 'Start Exploring',
                                  isLoading: authProvider.isLoading,
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _handleProfilePictureNext,
                                  isPrimary: true,
                                  icon: Icons.rocket_launch_rounded,
                                );
                              },
                            ).animate().fadeIn(delay: 600.ms),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
