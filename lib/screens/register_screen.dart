import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:prism/utils/theme.dart';
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

  // Form controllers
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _pronounsController = TextEditingController();
  final _dobController = TextEditingController();

  // Form keys for each step
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _step4Key = GlobalKey<FormState>();
  final _step5Key = GlobalKey<FormState>();
  final _step6Key = GlobalKey<FormState>();

  File? _profileImage;
  DateTime? _selectedDob;

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
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 5) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 6570),
      ), // 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryAccent,
              onPrimary: AppTheme.buttonText,
              surface: AppTheme.darkBackground,
              onSurface: AppTheme.darkPrimaryText,
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
    if (_profileImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a profile image'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim().isEmpty
        ? null
        : _lastNameController.text.trim();

    final success = await authProvider.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: firstName,
      lastName: lastName,
      profileImage: _profileImage!,
    );

    if (success && mounted) {
      // Update profile with additional info if provided
      if (_pronounsController.text.trim().isNotEmpty || _selectedDob != null) {
        // Send existing user data along with new fields to prevent null values
        await authProvider.updateProfile(
          username: _usernameController.text.trim(),
          firstName: firstName,
          lastName: lastName,
          pronouns: _pronounsController.text.trim().isEmpty
              ? null
              : _pronounsController.text.trim(),
          dob: _selectedDob,
        );
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Registration failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                  _buildStep5(),
                  _buildStep6(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return _buildStepTemplate(
      formKey: _step1Key,
      title: 'Let\'s Create your account',
      fields: [
        _buildLabel('Create Username'),
        _buildTextField(
          controller: _usernameController,
          hint: 'Enter username',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a username';
            }
            if (value.length < 3) {
              return 'Username must be at least 3 characters';
            }
            return null;
          },
        ),
      ],
      onNext: () {
        if (_step1Key.currentState!.validate()) {
          _nextPage();
        }
      },
    );
  }

  Widget _buildStep2() {
    return _buildStepTemplate(
      formKey: _step2Key,
      title: 'Let\'s Create your account',
      fields: [
        _buildLabel('First Name'),
        _buildTextField(
          controller: _firstNameController,
          hint: 'Enter your first name',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your first name';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildLabel('Last Name (Optional)'),
        _buildTextField(
          controller: _lastNameController,
          hint: 'Enter your last name',
          validator: null, // Optional field
        ),
      ],
      onNext: () {
        if (_step2Key.currentState!.validate()) {
          _nextPage();
        }
      },
    );
  }

  Widget _buildStep3() {
    return _buildStepTemplate(
      formKey: _step3Key,
      title: 'Let\'s Create your account',
      fields: [
        _buildLabel('Email'),
        _buildTextField(
          controller: _emailController,
          hint: 'Enter your Email',
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!value.contains('@') || !value.contains('.')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
      ],
      onNext: () {
        if (_step3Key.currentState!.validate()) {
          _nextPage();
        }
      },
    );
  }

  Widget _buildStep4() {
    return _buildStepTemplate(
      formKey: _step4Key,
      title: 'Let\'s Create your account',
      fields: [
        _buildLabel('Password'),
        _buildPasswordField(
          controller: _passwordController,
          hint: 'Enter a password',
        ),
        const SizedBox(height: 20),
        _buildLabel('Confirm Password'),
        _buildPasswordField(
          controller: _confirmPasswordController,
          hint: 'Confirm your password',
          isConfirm: true,
        ),
      ],
      onNext: () {
        if (_step4Key.currentState!.validate()) {
          _nextPage();
        }
      },
    );
  }

  Widget _buildStep5() {
    return _buildStepTemplate(
      formKey: _step5Key,
      title: 'Let\'s Create your account',
      fields: [
        _buildLabel('Pronouns (Optional)'),
        _buildTextField(
          controller: _pronounsController,
          hint: 'Enter he/him, she/her, they/them',
          validator: null, // Optional field
        ),
        const SizedBox(height: 20),
        _buildLabel('DOB (Optional)'),
        _buildTextField(
          controller: _dobController,
          hint: 'Enter your date of birth',
          readOnly: true,
          onTap: _selectDate,
          validator: null, // Optional field
        ),
      ],
      onNext: () {
        if (_step5Key.currentState!.validate()) {
          _nextPage();
        }
      },
    );
  }

  Widget _buildStep6() {
    return _buildStepTemplate(
      formKey: _step6Key,
      title: 'Let\'s Create your account',
      fields: [_buildProfileImagePicker()],
      onNext: () async {
        if (_step6Key.currentState!.validate()) {
          await _handleRegister();
        }
      },
      isLastStep: true,
    );
  }

  Widget _buildStepTemplate({
    required GlobalKey<FormState> formKey,
    required String title,
    required List<Widget> fields,
    required VoidCallback onNext,
    bool isLastStep = false,
  }) {
    final size = MediaQuery.of(context).size;
    final horizontalPadding = AppTheme.horizontalPadding(context);
    final buttonHeight = AppTheme.buttonHeight(context);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: size.height * 0.08),

              Text(title, style: AppTheme.headlineStyle(context)),

              SizedBox(height: size.height * 0.05),

              ...fields,

              SizedBox(height: size.height * 0.04),

              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return GestureDetector(
                    onTap: authProvider.isLoading ? null : onNext,
                    child: Container(
                      height: buttonHeight,
                      decoration: AppTheme.primaryButtonDecoration(),
                      child: Center(
                        child: authProvider.isLoading
                            ? CircularProgressIndicator(
                                color: AppTheme.buttonText,
                              )
                            : Text(
                                'Next',
                                style: AppTheme.buttonTextStyle(context),
                              ),
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: size.height * 0.02),

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
    );
  }

  Widget _buildLabel(String text) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTheme.subHeadlineStyle(
          context,
        ).copyWith(fontSize: size.width * 0.035),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final size = MediaQuery.of(context).size;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      style: TextStyle(color: AppTheme.primaryText(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.tertiaryText(context)),
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
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    bool isConfirm = false,
  }) {
    final size = MediaQuery.of(context).size;

    return TextFormField(
      controller: controller,
      obscureText: true,
      style: TextStyle(color: AppTheme.primaryText(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.tertiaryText(context)),
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
          return isConfirm
              ? 'Please confirm your password'
              : 'Please enter a password';
        }
        if (!isConfirm && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        if (isConfirm && value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildProfileImagePicker() {
    final size = MediaQuery.of(context).size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Profile Photo'),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: size.height * 0.3,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.darkDotInactive,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _profileImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        color: AppTheme.primaryText(context),
                        size: size.width * 0.15,
                      ),
                      SizedBox(height: size.height * 0.02),
                      Text(
                        'Take Profile Photo',
                        style: AppTheme.subHeadlineStyle(
                          context,
                        ).copyWith(fontSize: size.width * 0.04),
                      ),
                      SizedBox(height: size.height * 0.01),
                      Text(
                        'Tap to open camera',
                        style: AppTheme.subHeadlineStyle(context).copyWith(
                          fontSize: size.width * 0.03,
                          color: AppTheme.tertiaryText(context),
                        ),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _profileImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
          ),
        ),
        if (_profileImage != null) ...[
          SizedBox(height: size.height * 0.02),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: size.height * 0.06,
              decoration: BoxDecoration(
                color: AppTheme.darkDotInactive,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryAccent, width: 1.5),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.refresh,
                      color: AppTheme.primaryAccent,
                      size: size.width * 0.05,
                    ),
                    SizedBox(width: size.width * 0.02),
                    Text(
                      'Retake Photo',
                      style: AppTheme.buttonTextStyle(context).copyWith(
                        color: AppTheme.primaryAccent,
                        fontSize: size.width * 0.04,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
