import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/models/sharing_models.dart'; // Added for BatchImage

class RecipientSelectorSheet extends StatelessWidget {
  final String imageId;

  const RecipientSelectorSheet({super.key, required this.imageId});

  @override
  Widget build(BuildContext context) {
    final sharingProvider = Provider.of<SharingProvider>(context);
    final recipients = sharingProvider.allPotentialRecipients;

    // Find the specific image to get its detected faces
    final batchImage = sharingProvider.batchStatus?.images.firstWhere(
      (img) => img.id == imageId,
      orElse: () => BatchImage(
        id: imageId,
      ), // Assuming BatchImage has a default constructor or can be created with just an ID
    );

    // Identify detected user IDs for this specific image
    final detectedUserIds = batchImage?.recognizedUserIds ?? {};

    // Split recipients into detected and others
    final detectedRecipients = recipients
        .where((r) => detectedUserIds.contains(r.userId))
        .toList();
    final otherRecipients = recipients
        .where((r) => !detectedUserIds.contains(r.userId))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Increased height
      decoration: const BoxDecoration(
        color: PrismColors.surfaceGray,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Select Recipients', style: PrismTextStyles.h3),
                Text(
                  '${sharingProvider.imageRecipientMap[imageId]?.where((id) => id != 'archive').length ?? 0} selected',
                  style: PrismTextStyles.bodySmall.copyWith(
                    color: PrismColors.electricCyan,
                  ),
                ),
              ],
            ),
          ),

          // Recipients List
          Expanded(
            child: recipients.isEmpty
                ? Center(
                    child: Text(
                      'No friends found',
                      style: PrismTextStyles.bodyMedium.copyWith(
                        color: PrismColors.secondaryText,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      // Detected Section
                      if (detectedRecipients.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                          child: Text(
                            'PERSON DETECTED IN PICTURE',
                            style: PrismTextStyles.bodySmall.copyWith(
                              color: PrismColors.prismYellow,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        ...detectedRecipients.map(
                          (recipient) => _buildRecipientTile(
                            context,
                            sharingProvider,
                            recipient,
                            isDetected: true,
                          ),
                        ),
                        const Divider(height: 32, color: Colors.white10),
                      ],

                      // Other Friends Section
                      if (otherRecipients.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                          child: Text(
                            'ALL FRIENDS',
                            style: PrismTextStyles.bodySmall.copyWith(
                              color: PrismColors.secondaryText,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        ...otherRecipients.map(
                          (recipient) => _buildRecipientTile(
                            context,
                            sharingProvider,
                            recipient,
                            isDetected: false,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),

          // Done Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              child: PrismButton(
                text: 'Done',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientTile(
    BuildContext context,
    SharingProvider sharingProvider,
    dynamic recipient, { // DetectedRecipient or similar
    required bool isDetected,
  }) {
    // Check if this specific user is selected for this specific image
    final isSelected = sharingProvider.isRecipientSelectedForImage(
      imageId,
      recipient.userId,
    );

    // Debug logging
    debugPrint('👤 Recipient: ${recipient.username} (${recipient.userId})');
    debugPrint('   Is Selected: $isSelected');
    debugPrint(
      '   Image recipient map: ${sharingProvider.imageRecipientMap[imageId]}',
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: isDetected
            ? PrismColors.prismYellow.withOpacity(0.2)
            : PrismColors.secondaryText.withOpacity(0.2),
        backgroundImage: recipient.profilePicId != null
            ? null // TODO: Add NetworkImage if URL available
            : null,
        child: recipient.profilePicId == null
            ? Text(
                recipient.username.isNotEmpty
                    ? recipient.username[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: isDetected
                      ? PrismColors.prismYellow
                      : PrismColors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Text(
            recipient.username,
            style: PrismTextStyles.bodyLarge.copyWith(
              color: isSelected ? PrismColors.white : PrismColors.secondaryText,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isDetected) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: PrismColors.prismYellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: PrismColors.prismYellow.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
              child: const Text(
                'Detected',
                style: TextStyle(
                  color: PrismColors.prismYellow,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? PrismColors.prismYellow : Colors.transparent,
          border: Border.all(
            color: isSelected ? PrismColors.prismYellow : Colors.white54,
            width: 2,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, size: 16, color: Colors.black)
            : null,
      ),
      onTap: () {
        sharingProvider.toggleImageRecipient(imageId, recipient.userId);
      },
    );
  }
}
