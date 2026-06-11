import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:prism/models/contact_sync_result.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/cropped_face.dart';
import 'package:url_launcher/url_launcher.dart';

/// Horizontal strip of unknown face recommendations for the Friends screen.
class UnknownFacesStrip extends StatelessWidget {
  final List<UnknownFaceRecommendation> faces;

  const UnknownFacesStrip({
    super.key,
    required this.faces,
  });

  static const double _itemWidth = 96;

  @override
  Widget build(BuildContext context) {
    if (faces.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            faces.length == 1
                ? '1 person found in your images — invite them to Prism!'
                : '${faces.length} people found in your images — invite them to Prism!',
            style: PrismTextStyles.bodySmall.copyWith(
              color: PrismColors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: faces.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return _UnknownFaceStripItem(face: faces[index]);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _UnknownFaceStripItem extends StatelessWidget {
  final UnknownFaceRecommendation face;

  const _UnknownFaceStripItem({required this.face});

  Future<void> _openWhatsApp() async {
    if (face.whatsappLink.isEmpty) return;
    final uri = Uri.parse(face.whatsappLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: UnknownFacesStrip._itemWidth,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: PrismColors.surfaceGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PrismColors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CroppedFace(
            imageId: face.representativeImageId,
            bbox: face.bbox,
            size: 52,
          ),
          const SizedBox(height: 8),
          Text(
            '${face.appearanceCount} photo${face.appearanceCount == 1 ? '' : 's'}',
            style: PrismTextStyles.bodySmall.copyWith(
              color: PrismColors.secondaryText,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (face.whatsappLink.isNotEmpty)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _openWhatsApp();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF25D366).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.whatsapp,
                        color: Color(0xFF25D366),
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'WhatsApp',
                        style: TextStyle(
                          color: Color(0xFF25D366),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
