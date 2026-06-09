import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:prism/models/contact_sync_result.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/cropped_face.dart';

class UnknownFaceRecommendationCard extends StatelessWidget {
  final UnknownFaceRecommendation recommendation;

  const UnknownFaceRecommendationCard({
    super.key,
    required this.recommendation,
  });

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isTablet = media.size.width > 600;
    final avatarSize = isTablet ? 48.0 : 44.0;

    return Container(
      padding: EdgeInsets.all(isTablet ? 14 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          CroppedFace(
            imageId: recommendation.representativeImageId,
            bbox: recommendation.bbox,
            size: avatarSize,
          ),
          SizedBox(width: isTablet ? 14 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unknown Match',
                  style: PrismTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Found in ${recommendation.appearanceCount} photo${recommendation.appearanceCount == 1 ? '' : 's'}',
                  style: PrismTextStyles.bodySmall.copyWith(
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          if (recommendation.whatsappLink.isNotEmpty)
            _InviteIconButton(
              icon: Icons.message_rounded,
              color: const Color(0xFF25D366),
              tooltip: 'Invite via WhatsApp',
              onPressed: () {
                HapticFeedback.selectionClick();
                _launchUrl(recommendation.whatsappLink);
              },
            ),
          if (recommendation.whatsappLink.isNotEmpty &&
              recommendation.smsLink.isNotEmpty)
            const SizedBox(width: 4),
          if (recommendation.smsLink.isNotEmpty)
            _InviteIconButton(
              icon: Icons.sms_rounded,
              color: Colors.blue,
              tooltip: 'Invite via SMS',
              onPressed: () {
                HapticFeedback.selectionClick();
                _launchUrl(recommendation.smsLink);
              },
            ),
        ],
      ),
    );
  }
}

class _InviteIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _InviteIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: color),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
      ),
    );
  }
}
