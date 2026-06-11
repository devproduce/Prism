import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:prism/models/sharing_models.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/cropped_face.dart';
import 'package:url_launcher/url_launcher.dart';

/// Vertical unknown-faces block — matches web Review & Share (page.tsx Group C).
class ReviewUnknownFacesSection extends StatelessWidget {
  final List<UnknownFace> unknowns;

  const ReviewUnknownFacesSection({
    super.key,
    required this.unknowns,
  });

  @override
  Widget build(BuildContext context) {
    if (unknowns.isEmpty) return const SizedBox.shrink();

    final label = unknowns.length == 1
        ? '1 Person Found, Invite them to Prism!'
        : '${unknowns.length} People Found, Invite them to Prism!';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: PrismTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: PrismColors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...unknowns.asMap().entries.map((entry) {
            final index = entry.key;
            final face = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _UnknownFaceRow(face: face, personIndex: index + 1),
            );
          }),
        ],
      ),
    );
  }
}

class _UnknownFaceRow extends StatelessWidget {
  final UnknownFace face;
  final int personIndex;

  const _UnknownFaceRow({
    required this.face,
    required this.personIndex,
  });

  Future<void> _openLink(String link) async {
    if (link.isEmpty) return;
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageId = face.representativeImageId ?? '';
    final photoLabel =
        '${face.count} ${face.count == 1 ? 'photo' : 'photos'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PrismColors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PrismColors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          if (imageId.isNotEmpty)
            CroppedFace(
              imageId: imageId,
              bbox: face.bbox,
              size: 40,
            )
          else
            CircleAvatar(
              radius: 20,
              backgroundColor: PrismColors.inputGray,
              child: Icon(
                Icons.person_outline,
                color: PrismColors.secondaryText,
                size: 22,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Person $personIndex',
                  style: PrismTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  photoLabel,
                  style: PrismTextStyles.bodySmall.copyWith(
                    color: PrismColors.secondaryText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (face.whatsappLink.isNotEmpty)
            _InviteButton(
              label: 'WhatsApp',
              icon: const FaIcon(
                FontAwesomeIcons.whatsapp,
                size: 12,
                color: Color(0xFF25D366),
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                _openLink(face.whatsappLink);
              },
            ),
        ],
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  const _InviteButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PrismColors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PrismColors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 4),
              Text(
                label,
                style: PrismTextStyles.bodySmall.copyWith(
                  color: PrismColors.white,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
