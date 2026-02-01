import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 16.0 : 20.0;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
          style: PrismTextStyles.h2.copyWith(fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PrismColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last updated: 29 December 2025',
              style: PrismTextStyles.bodySmall.copyWith(
                color: PrismColors.secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Prism respects your privacy and is committed to protecting the personal information of its users ("you"). This Privacy Policy explains how we collect, use, store, and protect your information when you use the Prism mobile application ("App"), in compliance with Google Play policies and applicable data protection laws.',
              style: PrismTextStyles.bodyMedium,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Information We Collect',
              'We collect the following types of information to provide and improve our services:\n\na) Personal Information\n- Name and username\n- Email address or phone number (for account creation and authentication)\n- Profile photo\n\nb) Biometric Information\n- Facial data used solely for facial recognition and identity verification within the app.\n- Facial data is processed securely and is never shared with third parties for advertising purposes.\n\nc) Media Content\n- Photos and videos you upload to Prism\n- Metadata associated with media (date, time)\n\nd) Social Information\n- Friend connections within the app\n- Interaction data related to sharing media\n\ne) Device & Usage Information\n- Device type, OS version\n- App usage logs and crash data (for performance and security)',
            ),
            _buildSection(
              '2. How We Use Your Information',
              'We use your information to:\n- Provide AI-powered facial recognition and personalized media sharing\n- Verify user identity and friendships\n- Store, organize, and deliver photos and videos securely\n- Improve app performance and user experience\n- Ensure security, prevent misuse, and comply with legal obligations',
            ),
            _buildSection(
              '3. Facial Recognition & Biometric Data Usage',
              '- Facial data is collected only with your explicit consent.\n- It is used strictly to identify registered users in photos/videos for accurate sharing.\n- Facial data is encrypted and stored securely.\n- You may delete your biometric data at any time by deleting your account.',
            ),
            _buildSection(
              '4. Data Sharing & Disclosure',
              'We do NOT sell or rent your personal data. We may share data only:\n- With other Prism users, strictly as part of intended media sharing\n- With service providers for cloud storage and security (under strict confidentiality)\n- If required by law or legal process',
            ),
            _buildSection(
              '5. Data Storage & Security',
              '- All data is stored using industry-standard security measures.\n- Media and biometric data are encrypted in transit and at rest.\n- We regularly review and improve our security practices.',
            ),
            _buildSection(
              '6. Data Retention & Deletion',
              '- Data is retained only as long as your account is active.\n- You may delete media, friends, or your entire account at any time.\n- Upon account deletion, all personal and biometric data is permanently removed.',
            ),
            _buildSection(
              '7. User Controls & Rights',
              'You have the right to:\n- Access and update your personal information\n- Control media sharing and privacy settings\n- Withdraw consent for biometric processing\n- Request data deletion',
            ),
            _buildSection(
              '8. Children\'s Privacy',
              'Prism is not intended for users under the age of 9. We do not knowingly collect data from children.',
            ),
            _buildSection(
              '9. Ads & Monetization',
              'Currently, Prism does not display ads. If ads are introduced in the future, this Privacy Policy will be updated and users will be informed.',
            ),
            _buildSection(
              '10. Changes to This Privacy Policy',
              'We may update this Privacy Policy from time to time. Changes will be reflected within the app and on the Play Store listing.',
            ),
            _buildSection(
              '11. Contact Us',
              'If you have any questions about this Privacy Policy or your data, contact us at:\nEmail: prismapp.in@gmail.com',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PrismTextStyles.h3.copyWith(
              color: PrismColors.prismYellow,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: PrismTextStyles.bodyMedium.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
