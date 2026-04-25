import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Responsive padding
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 16.0 : 20.0;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: PrismTextStyles.h2.copyWith(fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PrismColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          children: [
            // Account Section
            _buildSectionHeader('Account'),
            PrismCard(
              child: Column(
                children: [
                  _buildSettingsTile(
                    context,
                    icon: Icons.person_outline_rounded,
                    title: 'Profile',
                    subtitle: 'Manage your profile information',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pushNamed('/profile');
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      color: PrismColors.white.withValues(alpha: 0.1),
                      height: 1,
                    ),
                  ),
                  // V2: Phone Number tile
                  _buildPhoneNumberTile(context, authProvider),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      color: PrismColors.white.withValues(alpha: 0.1),
                      height: 1,
                    ),
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.block_rounded,
                    title: 'Blocked Users',
                    subtitle: 'Manage blocked accounts',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pushNamed(context, '/blocked_users');
                    },
                  ),

                ],
              ),
            ),

            const SizedBox(height: 32),

            // App Info Section
            _buildSectionHeader('About'),
            PrismCard(
              child: Column(
                children: [
                  _buildSettingsTile(
                    context,
                    icon: Icons.shield_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'View our privacy policy',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pushNamed(context, '/privacy_policy');
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      color: PrismColors.white.withValues(alpha: 0.1),
                      height: 1,
                    ),
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: 'About Prism',
                    subtitle: 'Learn more about Prism',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pushNamed(context, '/about');
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      color: PrismColors.white.withValues(alpha: 0.1),
                      height: 1,
                    ),
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.edit_outlined,
                    title: 'Write to Us',
                    subtitle: 'Share your thoughts with us',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pushNamed(context, '/feedback');
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      color: PrismColors.white.withValues(alpha: 0.1),
                      height: 1,
                    ),
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.email_outlined,
                    title: 'Contact Us',
                    subtitle: 'prismapp.in@gmail.com',
                    onTap: () => _launchEmail(context),
                    showChevron: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      color: PrismColors.white.withValues(alpha: 0.1),
                      height: 1,
                    ),
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.numbers_rounded,
                    title: 'App Version',
                    subtitle: '1.0.0',
                    onTap: () {},
                    showChevron: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: PrismButton(
                text: 'Logout',
                type: PrismButtonType.destructive,
                onPressed: () => _handleLogout(context, authProvider),
              ),
            ),
            const SizedBox(height: 16),

            // Delete Account Button
            Center(
              child: TextButton(
                onPressed: () => _handleDeleteAccount(context, authProvider),
                style: TextButton.styleFrom(
                  foregroundColor: PrismColors.destructiveRed,
                ),
                child: Text(
                  'Delete Account',
                  style: PrismTextStyles.bodyMedium.copyWith(
                    color: PrismColors.destructiveRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    HapticFeedback.selectionClick();

    final confirmed = await ErrorHandler.showConfirmationDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      HapticFeedback.mediumImpact();
      try {
        await authProvider.logout(context);
        if (context.mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/onboarding', (route) => false);
        }
      } catch (e) {
        if (context.mounted) {
          ErrorHandler.showErrorSnackbar(
            context,
            message: 'Failed to logout. Please try again.',
          );
        }
      }
    }
  }

  Future<void> _handleDeleteAccount(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    HapticFeedback.selectionClick();

    final passwordController = TextEditingController();
    final reasonController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: PrismColors.surfaceGray,
              title: Text('Delete Account', style: PrismTextStyles.h3),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to delete your account? This action cannot be undone. Please enter your password and a reason to confirm.',
                    style: PrismTextStyles.bodyMedium.copyWith(color: PrismColors.secondaryText),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: PrismTextStyles.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: PrismTextStyles.bodyMedium.copyWith(color: PrismColors.secondaryText),
                      filled: true,
                      fillColor: PrismColors.inputGray,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    style: PrismTextStyles.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Reason (e.g. not_using)',
                      hintStyle: PrismTextStyles.bodyMedium.copyWith(color: PrismColors.secondaryText),
                      filled: true,
                      fillColor: PrismColors.inputGray,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: PrismTextStyles.button.copyWith(color: PrismColors.secondaryText)),
                ),
                PrismButton(
                  text: 'Delete',
                  isLoading: isLoading,
                  type: PrismButtonType.destructive,
                  onPressed: () async {
                    if (passwordController.text.isEmpty || reasonController.text.isEmpty) {
                      ErrorHandler.showErrorSnackbar(context, message: 'Password and reason are required');
                      return;
                    }
                    setState(() => isLoading = true);
                    try {
                      await authProvider.deleteAccount(
                        password: passwordController.text,
                        reason: reasonController.text,
                        context: context,
                      );
                      if (context.mounted) {
                        Navigator.pop(dialogContext); // Close dialog
                        Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Account scheduled for deletion',
                              style: PrismTextStyles.bodyMedium.copyWith(color: PrismColors.white),
                            ),
                            backgroundColor: PrismColors.voidBlack,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ErrorHandler.showErrorSnackbar(
                          context,
                          message: ErrorHandler.getErrorMessage(e),
                        );
                      }
                    } finally {
                      if (context.mounted) setState(() => isLoading = false);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    HapticFeedback.selectionClick();

    final Uri emailUri = Uri(scheme: 'mailto', path: 'prismapp.in@gmail.com');

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (context.mounted) {
          ErrorHandler.showErrorSnackbar(
            context,
            message:
                'Could not open email app. Please email us at prismapp.in@gmail.com',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: 'Failed to open email app',
        );
      }
    }
  }

  Widget _buildPhoneNumberTile(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    final hasWarning = authProvider.phoneSyncWarning;
    final currentPhone = authProvider.currentUser?.phoneNumber;
    final currentCode = authProvider.currentUser?.countryCode;
    final subtitle = (currentCode != null && currentPhone != null)
        ? '$currentCode $currentPhone'
        : hasWarning
        ? 'Tap to fix — couldn\'t be verified'
        : 'Not set';

    return InkWell(
      onTap: () => _showPhoneEditSheet(context, authProvider),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PrismColors.voidBlack,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasWarning
                      ? PrismColors.warningYellow.withValues(alpha: 0.6)
                      : PrismColors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Icon(
                Icons.phone_outlined,
                color: hasWarning
                    ? PrismColors.warningYellow
                    : PrismColors.prismYellow,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Phone Number', style: PrismTextStyles.bodyLarge),
                      if (hasWarning) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: PrismColors.warningYellow,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: PrismTextStyles.bodySmall.copyWith(
                      color: hasWarning
                          ? PrismColors.warningYellow
                          : PrismColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: PrismColors.secondaryText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showPhoneEditSheet(BuildContext context, AuthProvider authProvider) {
    final codeCtrl = TextEditingController(
      text: authProvider.currentUser?.countryCode ?? '91',
    );
    final phoneCtrl = TextEditingController(
      text: authProvider.currentUser?.phoneNumber ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PrismColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Update Phone Number', style: PrismTextStyles.h3),
              const SizedBox(height: 4),
              Text(
                'Used for contact-based friend discovery.',
                style: PrismTextStyles.bodySmall.copyWith(
                  color: PrismColors.secondaryText,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      controller: codeCtrl,
                      keyboardType: TextInputType.number,
                      style: PrismTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Code',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (int.tryParse(v.replaceAll('+', '')) == null) {
                          return 'Digits';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: PrismTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                        if (digits.length < 7) return 'Too short';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    await authProvider.updateProfile(
                      username: authProvider.currentUser!.username,
                      firstName: authProvider.currentUser!.firstName,
                      countryCode: codeCtrl.text.replaceAll('+', '').trim(),
                      phoneNumber: phoneCtrl.text
                          .replaceAll(RegExp(r'[^\d]'), ''),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Phone number updated!'),
                          backgroundColor: PrismColors.successGreen,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: PrismColors.prismYellow,
                    foregroundColor: PrismColors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Save', style: PrismTextStyles.bodyLarge),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: PrismTextStyles.bodySmall.copyWith(
            color: PrismColors.secondaryText,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PrismColors.voidBlack,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: PrismColors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Icon(icon, color: PrismColors.prismYellow, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: PrismTextStyles.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: PrismTextStyles.bodySmall.copyWith(
                      color: PrismColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            if (showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                color: PrismColors.secondaryText,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
