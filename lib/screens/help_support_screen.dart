import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/widgets/gradient_background.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchDialer(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        debugPrint("Could not launch dialer");
      }
    } catch (e) {
      debugPrint("Error launching dialer: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double width = size.width;
    final double height = size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.04, // ~16px
                  vertical: height * 0.01, // ~8px
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: width * 0.02), // ~8px
                    Text('Help & Support', style: PrismTextStyles.h3),
                  ],
                ),
              ),

              SizedBox(height: height * 0.03), // ~24px
              // Content
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.05,
                ), // ~20px
                child: GlassCard(
                  padding: EdgeInsets.all(width * 0.06), // ~24px
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(width * 0.04), // ~16px
                        decoration: BoxDecoration(
                          color: PrismColors.primaryBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.support_agent_rounded,
                          size: width * 0.12, // ~48px
                          color: PrismColors.electricBlue,
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
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: height * 0.04), // ~32px
                      // Contact Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _launchDialer('+919930425910'),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: height * 0.02, // ~16px
                              horizontal: width * 0.05, // ~20px
                            ),
                            decoration: BoxDecoration(
                              gradient: PrismColors.prismSignature,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: PrismColors.primaryBlue.withOpacity(
                                    0.3,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.phone_in_talk_rounded,
                                  color: Colors.white,
                                ),
                                SizedBox(width: width * 0.03), // ~12px
                                Flexible(
                                  child: Text(
                                    'Contact Us: +91 99304 25910',
                                    style: PrismTextStyles.button.copyWith(
                                      color: Colors.white,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
