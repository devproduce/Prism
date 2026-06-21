import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/screens/multi_view_capture_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/auth_navigation.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/widgets/prism_text_field.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  Timer? _usernameDebounce;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  List<String>? _faceIds;
  File? _profilePicImage;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = null;
      });
      return;
    }
    setState(() {
      _isCheckingUsername = true;
      _isUsernameAvailable = null;
    });
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      final available = await context
          .read<AuthProvider>()
          .checkUsernameAvailability(value.trim());
      if (mounted && _usernameController.text.trim() == value.trim()) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = available;
        });
      }
    });
  }

  Future<void> _startFaceScan() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MultiViewCaptureScreen()),
    );
    if (result == null || !mounted) return;

    if (result is Map) {
      final faces = result['faceIds'];
      final imagePath = result['imagePath'] as String?;
      if (faces is List<String>) {
        setState(() {
          _faceIds = faces;
          if (imagePath != null) _profilePicImage = File(imagePath);
        });
      }
    } else if (result is List<String>) {
      setState(() => _faceIds = result);
    }
  }

  Future<void> _handleComplete() async {
    if (!_formKey.currentState!.validate()) return;
    if (_faceIds == null || _faceIds!.isEmpty) {
      ErrorHandler.showErrorSnackbar(
        context,
        message: 'Please complete the face scan to continue.',
      );
      return;
    }
    if (_isUsernameAvailable == false) {
      ErrorHandler.showErrorSnackbar(
        context,
        message: 'That username is already taken.',
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final auth = context.read<AuthProvider>();
    final success = await auth.completeGoogleRegistration(
      username: _usernameController.text.trim(),
      faceIds: _faceIds,
      profileImage: _profilePicImage,
    );

    if (!mounted) return;
    if (success) {
      HapticFeedback.heavyImpact();
      navigateAfterAuthentication(context, auth, clearStack: true);
    } else if (auth.error != null && auth.error!.isNotEmpty) {
      ErrorHandler.showErrorSnackbar(context, message: auth.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Complete your profile',
          style: PrismTextStyles.h3.copyWith(color: PrismColors.white),
        ),
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
                  'Pick a username and scan your face to finish setting up your Prism account.',
                  style: PrismTextStyles.bodyMedium.copyWith(
                    color: PrismColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 24),
                PrismCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PrismTextField(
                        controller: _usernameController,
                        hintText: 'Choose a username',
                        prefixIcon: Icons.alternate_email,
                        onChanged: _onUsernameChanged,
                        validator: (value) {
                          if (value == null || value.trim().length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          if (_isUsernameAvailable == false) {
                            return 'Username is already taken';
                          }
                          return null;
                        },
                      ),
                      if (_isCheckingUsername)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Checking availability...',
                            style: PrismTextStyles.bodySmall.copyWith(
                              color: PrismColors.secondaryText,
                            ),
                          ),
                        )
                      else if (_isUsernameAvailable == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Username is available',
                            style: PrismTextStyles.bodySmall.copyWith(
                              color: Colors.greenAccent,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _startFaceScan,
                        icon: Icon(
                          _faceIds != null && _faceIds!.isNotEmpty
                              ? Icons.check_circle_outline
                              : Icons.face_retouching_natural,
                          color: PrismColors.prismYellow,
                        ),
                        label: Text(
                          _faceIds != null && _faceIds!.isNotEmpty
                              ? 'Face scan complete'
                              : 'Scan your face',
                          style: PrismTextStyles.button.copyWith(
                            color: PrismColors.white,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: PrismColors.white.withValues(alpha: 0.15),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          return PrismButton(
                            text: 'Create account',
                            isLoading: auth.isLoading,
                            onPressed: auth.isLoading ? null : _handleComplete,
                          );
                        },
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
