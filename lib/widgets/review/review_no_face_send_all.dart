import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

/// Compact "Send to all" toggle shown inside the no-face accordion body.
class ReviewNoFaceSendAllTile extends StatelessWidget {
  const ReviewNoFaceSendAllTile({super.key});

  @override
  Widget build(BuildContext context) {
    final sharingProvider = Provider.of<SharingProvider>(context);
    final recipientCount = sharingProvider.batchRecipientUserIds.length;
    final canBulkSend = sharingProvider.canSendNoFaceToAll;

    final subtitle = recipientCount == 0
        ? 'Share with everyone detected in this batch'
        : recipientCount == 1
            ? 'Share with 1 friend detected in this batch'
            : 'Share with all $recipientCount friends in this batch';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canBulkSend
            ? () {
                HapticFeedback.selectionClick();
                sharingProvider.setSendNoFaceToAll(
                  !sharingProvider.sendNoFaceToAll,
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: sharingProvider.sendNoFaceToAll
                ? PrismColors.prismYellow.withValues(alpha: 0.08)
                : PrismColors.inputGray.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sharingProvider.sendNoFaceToAll
                  ? PrismColors.prismYellow.withValues(alpha: 0.35)
                  : PrismColors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send to all',
                      style: PrismTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: canBulkSend
                            ? PrismColors.white
                            : PrismColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: PrismTextStyles.bodySmall.copyWith(
                        color: PrismColors.secondaryText,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: sharingProvider.sendNoFaceToAll,
                onChanged: canBulkSend
                    ? sharingProvider.setSendNoFaceToAll
                    : null,
                activeThumbColor: PrismColors.prismYellow,
                activeTrackColor:
                    PrismColors.prismYellow.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
