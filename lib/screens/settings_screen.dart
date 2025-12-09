import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/theme_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/widgets/gradient_background.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text('Settings', style: PrismTextStyles.h2),
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: isDark
                        ? PrismColors.primaryBlue
                        : PrismColors.deepBlue,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Appearance Section
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      color: isDark
                          ? PrismColors.glassDark
                          : PrismColors.glassLight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Appearance', style: PrismTextStyles.h3),
                          const SizedBox(height: 16),
                          // Theme Toggle
                          Row(
                            children: [
                              Icon(
                                isDark
                                    ? Icons.dark_mode_rounded
                                    : Icons.light_mode_rounded,
                                color: isDark
                                    ? PrismColors.primaryBlue
                                    : PrismColors.deepBlue,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dark Mode',
                                      style: PrismTextStyles.bodyLarge,
                                    ),
                                    Text(
                                      isDark ? 'Enabled' : 'Disabled',
                                      style: PrismTextStyles.bodySmall.copyWith(
                                        color: isDark
                                            ? PrismColors.textSecondaryDark
                                                  .withOpacity(0.7)
                                            : PrismColors.textSecondaryLight
                                                  .withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isDark,
                                onChanged: (_) => themeProvider.toggleTheme(),
                                activeColor: PrismColors.primaryBlue,
                                activeTrackColor: PrismColors.accentBlue
                                    .withOpacity(0.5),
                                inactiveThumbColor: PrismColors.deepBlue,
                                inactiveTrackColor: PrismColors.lightElevated,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Account Section
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      color: isDark
                          ? PrismColors.glassDark
                          : PrismColors.glassLight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Account', style: PrismTextStyles.h3),
                          const SizedBox(height: 16),
                          _buildSettingsTile(
                            context,
                            icon: Icons.person_outline_rounded,
                            title: 'Profile',
                            subtitle: 'Manage your profile information',
                            onTap: () {
                              Navigator.of(context).pushNamed('/profile');
                            },
                            isDark: isDark,
                          ),
                          const Divider(height: 32),
                          _buildSettingsTile(
                            context,
                            icon: Icons.block_rounded,
                            title: 'Blocked Users',
                            subtitle: 'Manage blocked accounts',
                            onTap: () {
                              Navigator.pushNamed(context, '/blocked_users');
                            },
                            isDark: isDark,
                          ),
                          const Divider(height: 32),
                          _buildSettingsTile(
                            context,
                            icon: Icons.visibility_off_rounded,
                            title: 'Keep Users',
                            subtitle: 'Manage kept users',
                            onTap: () {
                              Navigator.pushNamed(context, '/keep_users');
                            },
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // App Info Section
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      color: isDark
                          ? PrismColors.glassDark
                          : PrismColors.glassLight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('About', style: PrismTextStyles.h3),
                          const SizedBox(height: 16),
                          _buildSettingsTile(
                            context,
                            icon: Icons.info_outline_rounded,
                            title: 'App Version',
                            subtitle: '1.0.0',
                            onTap: () {},
                            isDark: isDark,
                            showChevron: false,
                          ),
                          const Divider(height: 32),
                          _buildSettingsTile(
                            context,
                            icon: Icons.help_outline_rounded,
                            title: 'Help & Support',
                            subtitle: 'Get help or contact support',
                            onTap: () {
                              Navigator.pushNamed(context, '/help_support');
                            },
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Logout Button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            PrismColors.errorRed.withOpacity(0.7),
                            PrismColors.errorRed,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            await authProvider.logout(context);
                            if (context.mounted) {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/onboarding',
                                (route) => false,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 50,
                            alignment: Alignment.center,
                            child: Text(
                              'Logout',
                              style: PrismTextStyles.button.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
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
    required bool isDark,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? PrismColors.primaryBlue.withOpacity(0.15)
                    : PrismColors.deepBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDark ? PrismColors.primaryBlue : PrismColors.deepBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: PrismTextStyles.bodyLarge),
                  Text(
                    subtitle,
                    style: PrismTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? PrismColors.textSecondaryDark.withOpacity(0.7)
                          : PrismColors.textSecondaryLight.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (showChevron)
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? PrismColors.textSecondaryDark.withOpacity(0.5)
                    : PrismColors.textSecondaryLight.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }
}
