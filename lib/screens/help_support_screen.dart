import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchDialer(BuildContext context, String phoneNumber) async {
    HapticFeedback.selectionClick();
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (context.mounted) {
          ErrorHandler.showErrorSnackbar(
            context,
            message: 'Could not launch dialer',
          );
        }
      }
    } catch (e) {
      debugPrint("Error launching dialer: $e");
      if (context.mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: 'Error launching dialer: ${ErrorHandler.getErrorMessage(e)}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double width = size.width;
    final double height = size.height;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text('Help & Support', style: PrismTextStyles.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: BackButton(
          color: PrismColors.white,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.05,
            vertical: height * 0.03,
          ),
          child: Column(
            children: [
              PrismCard(
                padding: EdgeInsets.all(width * 0.06),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(width * 0.04), // ~16px
                      decoration: BoxDecoration(
                        color: PrismColors.prismYellow.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.support_agent_rounded,
                        size: width * 0.12, // ~48px
                        color: PrismColors.prismYellow,
                      ),
                    ),
                    SizedBox(height: height * 0.03), // ~24px
                    Text(
                      'Need Assistance?',
                      style: PrismTextStyles.h2,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: height * 0.015), // ~12px
                    Text(
                      'Our support team is here to help you. Feel free to contact us directly.',
                      style: PrismTextStyles.bodyMedium.copyWith(
                        color: PrismColors.secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: height * 0.04), // ~32px
                    // Contact Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _launchDialer(context, '+919930425910'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: height * 0.02, // ~16px
                            horizontal: width * 0.05, // ~20px
                          ),
                          decoration: BoxDecoration(
                            color: PrismColors.prismYellow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.phone_in_talk_rounded,
                                color: PrismColors.black,
                              ),
                              SizedBox(width: width * 0.03), // ~12px
                              Flexible(
                                child: Text(
                                  'Contact Us: +91 99304 25910',
                                  style: PrismTextStyles.button.copyWith(
                                    color: PrismColors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
