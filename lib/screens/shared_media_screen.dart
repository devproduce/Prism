import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/widgets/prism_button.dart';

class SharedMediaScreen extends StatelessWidget {
  const SharedMediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sharingProvider = Provider.of<SharingProvider>(context);
    final recipients = sharingProvider.selectedRecipients;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text(
          'Shared Media',
          style: PrismTextStyles.h2.copyWith(fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PrismColors.white),
          onPressed: () {
            sharingProvider.reset();
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
        actions: [
          IconButton(
            onPressed: () => _showInfoDialog(context),
            icon: const Icon(Icons.info_outline, color: PrismColors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Success banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PrismColors.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: PrismColors.successGreen.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: PrismColors.successGreen,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shared Successfully!',
                              style: PrismTextStyles.h3.copyWith(
                                color: PrismColors.successGreen,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${sharingProvider.sharedPhotoCount} photos shared with ${sharingProvider.sharedRecipientCount} people',
                              style: PrismTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Who Gets What label
                Text(
                  'WHO GETS WHAT',
                  style: PrismTextStyles.bodySmall.copyWith(
                    color: PrismColors.prismYellow,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 16),

                // Recipients list
                if (recipients.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: PrismColors.prismYellow,
                          ),
                          const SizedBox(height: 16),
                          Text('Media Shared!', style: PrismTextStyles.h3),
                          const SizedBox(height: 8),
                          Text(
                            'Your content has been shared',
                            style: PrismTextStyles.bodyMedium.copyWith(
                              color: PrismColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...recipients.map((recipient) {
                    return PrismCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: PrismColors.surfaceGray,
                          backgroundImage:
                              recipient.profilePictureUrl.isNotEmpty
                              ? CachedNetworkImageProvider(
                                  recipient.profilePictureUrl,
                                )
                              : null,
                          child: recipient.profilePictureUrl.isEmpty
                              ? Text(
                                  recipient.username[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: PrismColors.white,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          recipient.username,
                          style: PrismTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${recipient.count} ${recipient.count == 1 ? 'photo' : 'photos'}',
                              style: PrismTextStyles.bodyMedium.copyWith(
                                color: PrismColors.secondaryText,
                              ),
                            ),
                            Text(
                              'Matched movements',
                              style: PrismTextStyles.bodySmall.copyWith(
                                color: PrismColors.prismYellow,
                              ),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: PrismColors.successGreen.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: PrismColors.successGreen,
                            size: 20,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),

          // Done button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: PrismButton(
                text: 'Done',
                onPressed: () {
                  sharingProvider.reset();
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PrismColors.surfaceGray,
        title: Text('Who Gets What', style: PrismTextStyles.h3),
        content: Text(
          'Prism has automatically distributed your photos to each person based on face detection. Each recipient will only see photos where they appear.',
          style: PrismTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: PrismTextStyles.button.copyWith(
                color: PrismColors.prismYellow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
