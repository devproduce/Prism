import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 16.0 : 20.0;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text(
          'About Prism',
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
              'About Prism',
              style: PrismTextStyles.h1.copyWith(
                color: PrismColors.prismYellow,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Prism is an AI-powered social sharing platform built to make group photo and video sharing effortless, private, and clutter-free.',
              style: PrismTextStyles.bodyLarge.copyWith(height: 1.6),
            ),
            const SizedBox(height: 16),
            Text(
              'After every trip, party, or event, photos usually end up scattered across different groups, drives, albums, and personal chats-forcing people to manually sort, send, and delete content. Prism fixes this.',
              style: PrismTextStyles.bodyMedium.copyWith(height: 1.6),
            ),
            const SizedBox(height: 16),
            Text(
              'With Prism, you share once-and everyone receives only the photos and videos they\'re actually in.',
              style: PrismTextStyles.bodyMedium.copyWith(
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: PrismColors.prismYellow,
              ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'How Prism Works',
              'Prism uses AI-based facial recognition combined with a verified friend network to automatically identify people in photos and videos.\n\nWhen you select/upload content:\n• Prism detects registered faces\n• Verifies friendships between people in the media\n• Privately delivers relevant content to each person\'s personal gallery\n\nNo links. No group dumps. No manual sorting.',
            ),
            _buildSection(
              'Built for Privacy & Trust',
              'Prism is designed with privacy at its core:\n\n• Media is shared only between verified friends\n• No public albums or open links\n• You always stay in control of what gets shared\n\nIf someone in a photo isn\'t connected yet, Prism pauses sharing until verification-ensuring safe and intentional distribution.',
            ),
            _buildSection(
              'Why Prism Exists',
              'We believe memories should be:\n• Easy to share\n• Relevant to receive\n• Secure by default\n\nPrism removes the friction, noise, and clutter from modern media sharing-so you can focus on the moments, not managing them.',
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
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: PrismTextStyles.bodyMedium.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
