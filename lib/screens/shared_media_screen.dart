import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/utils/theme.dart';

class SharedMediaScreen extends StatelessWidget {
  const SharedMediaScreen({super.key});

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
            final recipients = sharingProvider.selectedRecipients;

            return Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(size.width * 0.05),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Reset sharing state and pop all sharing screens
                          sharingProvider.reset();
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        child: Icon(
                          Icons.arrow_back,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(width: size.width * 0.04),
                      Expanded(
                        child: Text(
                          'Shared Media',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // Show who gets what info
                          _showInfoDialog(context, theme, size);
                        },
                        icon: Icon(
                          Icons.people,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),

                // Success banner
                Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: size.width * 0.05,
                    vertical: size.height * 0.01,
                  ),
                  padding: EdgeInsets.all(size.width * 0.04),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green, Colors.green.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: size.width * 0.08,
                      ),
                      SizedBox(width: size.width * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shared Successfully!',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: size.height * 0.003),
                            Text(
                              '${sharingProvider.sharedPhotoCount} photos shared with ${sharingProvider.sharedRecipientCount} people',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Who Gets What label
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.05,
                    vertical: size.height * 0.02,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'WHO GETS WHAT',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Recipients list
                Expanded(
                  child: recipients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: size.width * 0.2,
                                color: Colors.green,
                              ),
                              SizedBox(height: size.height * 0.02),
                              Text(
                                'Media Shared!',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: size.height * 0.01),
                              Text(
                                'Your content has been shared',
                                style: theme.textTheme.bodyMedium?.copyWith(
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
                            return _buildRecipientCard(
                              context,
                              recipient,
                              size,
                              theme,
                              isDark,
                            );
                          },
                        ),
                ),

                // Done button
                Padding(
                  padding: EdgeInsets.all(size.width * 0.05),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        sharingProvider.reset();
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: size.height * 0.02,
                        ),
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: size.width * 0.04,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecipientCard(
    BuildContext context,
    dynamic recipient,
    Size size,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: size.height * 0.015),
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Profile picture
          CircleAvatar(
            radius: size.width * 0.08,
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
                      fontSize: size.width * 0.06,
                    ),
                  )
                : null,
          ),

          SizedBox(width: size.width * 0.04),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient.username,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: size.height * 0.005),
                Text(
                  '${recipient.count} ${recipient.count == 1 ? 'photo' : 'photos'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                SizedBox(height: size.height * 0.003),
                Text(
                  'Matched movements',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.primaryAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Status icon
          Container(
            padding: EdgeInsets.all(size.width * 0.02),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              color: Colors.green,
              size: size.width * 0.06,
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, ThemeData theme, Size size) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Who Gets What',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Prism has automatically distributed your photos to each person based on face detection. Each recipient will only see photos where they appear.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: TextStyle(
                color: AppTheme.primaryAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
