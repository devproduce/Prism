import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/screens/shared_media_screen.dart';
import 'package:prism/utils/theme.dart';

class ConfirmSharingScreen extends StatelessWidget {
  const ConfirmSharingScreen({super.key});

  Future<void> _confirmShare(BuildContext context) async {
    debugPrint('📤 [ConfirmSharingScreen] Confirming share...');
    final sharingProvider = context.read<SharingProvider>();

    final success = await sharingProvider.confirmShare();

    if (!context.mounted) return;

    if (success) {
      debugPrint(
        '✅ [ConfirmSharingScreen] Share confirmed, navigating to success screen',
      );
      // Navigate to shared media screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SharedMediaScreen()),
      );
    } else {
      debugPrint(
        '❌ [ConfirmSharingScreen] Share failed: ${sharingProvider.error}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sharingProvider.error ?? 'Failed to share images'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer<SharingProvider>(
          builder: (context, sharingProvider, _) {
            final batchStatus = sharingProvider.batchStatus;
            final recipients = batchStatus?.recipients ?? [];
            final selectedRecipients = sharingProvider.selectedRecipients;

            return Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(size.width * 0.05),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Icon(
                          Icons.arrow_back,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(width: size.width * 0.04),
                      Text(
                        'Confirm Sharing',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),

                // Success banner
                Container(
                  margin: EdgeInsets.symmetric(horizontal: size.width * 0.05),
                  padding: EdgeInsets.all(size.width * 0.04),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryAccent,
                        AppTheme.primaryAccent.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(size.width * 0.02),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: size.width * 0.08,
                        ),
                      ),
                      SizedBox(width: size.width * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personalized Sharing Applied!',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: size.height * 0.005),
                            Text(
                              'Everyone in your content will receive relevant photos and videos.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: size.height * 0.025),

                // Auto-Clean Toggle
                Container(
                  margin: EdgeInsets.symmetric(horizontal: size.width * 0.05),
                  padding: EdgeInsets.all(size.width * 0.04),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(size.width * 0.02),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: AppTheme.primaryAccent,
                          size: size.width * 0.06,
                        ),
                      ),
                      SizedBox(width: size.width * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-Clean Media',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: size.height * 0.003),
                            Text(
                              'Automatically move media to the recipient if you or your faces aren\'t detected. You can change this anytime.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: sharingProvider.autoClean,
                        onChanged: (_) => sharingProvider.toggleAutoClean(),
                        activeColor: AppTheme.primaryAccent,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: size.height * 0.025),

                // Recipients section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recipients',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.03,
                          vertical: size.height * 0.005,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${selectedRecipients.length} selected',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: size.height * 0.015),

                // Recipients list
                Expanded(
                  child: recipients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: size.width * 0.15,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.3,
                                ),
                              ),
                              SizedBox(height: size.height * 0.02),
                              Text(
                                'No recipients detected',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: size.width * 0.05,
                          ),
                          itemCount: recipients.length,
                          itemBuilder: (context, index) {
                            final recipient = recipients[index];
                            return _buildRecipientTile(
                              context,
                              recipient,
                              size,
                              theme,
                              isDark,
                              sharingProvider,
                            );
                          },
                        ),
                ),

                // Footer info
                Container(
                  padding: EdgeInsets.all(size.width * 0.05),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Recipients',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${selectedRecipients.length} People',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppTheme.primaryAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: size.height * 0.01),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Content',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${batchStatus?.images.length ?? 0} photos, 3 videos',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: size.height * 0.02),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: sharingProvider.isProcessing
                              ? null
                              : () => _confirmShare(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: size.height * 0.02,
                            ),
                          ),
                          child: sharingProvider.isProcessing
                              ? SizedBox(
                                  height: size.width * 0.05,
                                  width: size.width * 0.05,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Prism Share',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: size.width * 0.04,
                                      ),
                                    ),
                                    SizedBox(width: size.width * 0.02),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                      size: size.width * 0.05,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecipientTile(
    BuildContext context,
    dynamic recipient,
    Size size,
    ThemeData theme,
    bool isDark,
    SharingProvider sharingProvider,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: size.height * 0.015),
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: recipient.isSelected
              ? AppTheme.primaryAccent
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // Profile picture
          CircleAvatar(
            radius: size.width * 0.06,
            backgroundColor: AppTheme.primaryAccent.withOpacity(0.2),
            backgroundImage: recipient.profilePictureUrl.isNotEmpty
                ? CachedNetworkImageProvider(recipient.profilePictureUrl)
                : null,
            child: recipient.profilePictureUrl.isEmpty
                ? Text(
                    recipient.username[0].toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.primaryAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: size.width * 0.05,
                    ),
                  )
                : null,
          ),

          SizedBox(width: size.width * 0.03),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient.username,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: size.height * 0.003),
                Text(
                  '${recipient.count} ${recipient.count == 1 ? 'video' : 'videos'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          // Checkmark
          GestureDetector(
            onTap: () => sharingProvider.toggleRecipient(recipient.userId),
            child: Container(
              padding: EdgeInsets.all(size.width * 0.015),
              decoration: BoxDecoration(
                color: recipient.isSelected
                    ? AppTheme.primaryAccent
                    : Colors.transparent,
                border: Border.all(
                  color: recipient.isSelected
                      ? AppTheme.primaryAccent
                      : theme.colorScheme.onSurface.withOpacity(0.3),
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: recipient.isSelected ? Colors.white : Colors.transparent,
                size: size.width * 0.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
