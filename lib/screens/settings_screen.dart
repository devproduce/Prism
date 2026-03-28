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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      color: PrismColors.white.withValues(alpha: 0.1),
                      height: 1,
                    ),
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.visibility_off_rounded,
                    title: 'Keep Users',
                    subtitle: 'Manage kept users',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pushNamed(context, '/keep_users');
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

    final confirmed = await ErrorHandler.showConfirmationDialog(
      context,
      title: 'Delete Account',
      message:
          'Are you sure you want to delete your account? This action cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      HapticFeedback.heavyImpact();
      try {
        // Just logout for now as per requirements
        await authProvider.logout(context);

        if (context.mounted) {
          // Navigate to onboarding first
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/onboarding', (route) => false);

          // Show snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Your account is deleted',
                style: PrismTextStyles.bodyMedium.copyWith(
                  color: PrismColors.white,
                ),
              ),
              backgroundColor: PrismColors.voidBlack,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: PrismColors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ErrorHandler.showErrorSnackbar(
            context,
            message: 'Failed to delete account. Please try again.',
          );
        }
      }
    }
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
