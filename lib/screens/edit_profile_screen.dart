import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/profile_provider.dart';
import 'package:prism/utils/theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _pronounsController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  late TextEditingController _countryCodeController;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = profileProvider.currentUser ?? authProvider.currentUser;

    _usernameController = TextEditingController(text: user?.username ?? '');
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _pronounsController = TextEditingController(text: user?.pronouns ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _countryCodeController = TextEditingController(
      text: user?.countryCode ?? '',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _pronounsController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _countryCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    final userId = authProvider.currentUser?.userId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryAccent),
      ),
    );

    try {
      final success = await profileProvider.updateProfile(
        userId: userId,
        username: _usernameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim().isEmpty
            ? null
            : _lastNameController.text.trim(),
        pronouns: _pronounsController.text.trim().isEmpty
            ? null
            : _pronounsController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        countryCode: _countryCodeController.text.trim().isEmpty
            ? null
            : _countryCodeController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        if (success) {
          // Update auth provider as well
          await authProvider.refreshUser();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Go back to profile screen
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                profileProvider.error ?? 'Failed to update profile',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final profileProvider = Provider.of<ProfileProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = profileProvider.currentUser ?? authProvider.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primaryText(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: AppTheme.headlineStyle(
            context,
          ).copyWith(fontSize: size.width * 0.045),
        ),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: Text(
              'Save',
              style: TextStyle(
                color: AppTheme.primaryAccent,
                fontSize: size.width * 0.04,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.horizontalPadding(context),
              vertical: size.height * 0.02,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Picture Section
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: size.width * 0.3,
                          height: size.width * 0.3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryAccent,
                              width: 2,
                            ),
                            color: AppTheme.darkDotInactive,
                          ),
                          child: _selectedImage != null
                              ? ClipOval(
                                  child: Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : user?.profilePictureUrl != null
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: user!.profilePictureUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(
                                        color: AppTheme.primaryAccent,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.person,
                                      size: size.width * 0.15,
                                      color: AppTheme.tertiaryText(context),
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: size.width * 0.15,
                                  color: AppTheme.tertiaryText(context),
                                ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: EdgeInsets.all(size.width * 0.02),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: size.width * 0.05,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: size.height * 0.03),

                  // Username Field
                  _buildTextField(
                    controller: _usernameController,
                    label: 'Username',
                    hint: 'Enter your username',
                    size: size,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Username is required';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: size.height * 0.02),

                  // First Name Field
                  _buildTextField(
                    controller: _firstNameController,
                    label: 'First Name',
                    hint: 'Enter your first name',
                    size: size,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'First name is required';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: size.height * 0.02),

                  // Last Name Field
                  _buildTextField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    hint: 'Enter your last name',
                    size: size,
                  ),

                  SizedBox(height: size.height * 0.02),

                  // Pronouns Field
                  _buildTextField(
                    controller: _pronounsController,
                    label: 'Pronouns',
                    hint: 'e.g., she/her, he/him, they/them',
                    size: size,
                  ),

                  SizedBox(height: size.height * 0.02),

                  // Bio Field
                  _buildTextField(
                    controller: _bioController,
                    label: 'Bio',
                    hint: 'Write something about yourself',
                    size: size,
                    maxLines: 3,
                  ),

                  SizedBox(height: size.height * 0.02),

                  // Phone Number Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: _countryCodeController,
                          label: 'Code',
                          hint: '+1',
                          size: size,
                        ),
                      ),
                      SizedBox(width: size.width * 0.03),
                      Expanded(
                        flex: 5,
                        child: _buildTextField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          hint: 'Enter your phone number',
                          size: size,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: size.height * 0.02),

                  // Email (Read-only)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email',
                        style: AppTheme.headlineStyle(
                          context,
                        ).copyWith(fontSize: size.width * 0.035),
                      ),
                      SizedBox(height: size.height * 0.01),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.04,
                          vertical: size.height * 0.02,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.darkDotInactive.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.darkDotInactive,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                user?.email ?? '',
                                style: TextStyle(
                                  color: AppTheme.tertiaryText(context),
                                  fontSize: size.width * 0.038,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.lock_outline,
                              size: size.width * 0.04,
                              color: AppTheme.tertiaryText(context),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: size.height * 0.005),
                      Text(
                        'Email cannot be changed',
                        style: TextStyle(
                          color: AppTheme.tertiaryText(context),
                          fontSize: size.width * 0.03,
                          fontStyle: FontStyle.italic,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Size size,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.headlineStyle(
            context,
          ).copyWith(fontSize: size.width * 0.035),
        ),
        SizedBox(height: size.height * 0.01),
        TextFormField(
          controller: controller,
          style: TextStyle(color: AppTheme.primaryText(context)),
          maxLines: maxLines,
          keyboardType: keyboardType,
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
        ),
      ],
    );
  }
}
