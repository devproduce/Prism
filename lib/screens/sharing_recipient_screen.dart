import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:prism/models/sharing_models.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/screens/home_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/media_url_utils.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:provider/provider.dart';

class SharingRecipientScreen extends StatefulWidget {
  final List<DetectedRecipient> recipients;
  final int photoCount;

  const SharingRecipientScreen({
    super.key,
    required this.recipients,
    required this.photoCount,
  });

  @override
  State<SharingRecipientScreen> createState() => _SharingRecipientScreenState();
}

class _SharingRecipientScreenState extends State<SharingRecipientScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _flipAnimation = Tween<double>(begin: math.pi, end: 0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeOutBack),
    );
    _flipController.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => HomeScreen(key: HomeScreen.homeScreenKey),
      ),
      (route) => false,
    );
  }

  Map<String, String>? _authHeaders(String? url) {
    return MediaUrlUtils.authHeaders(
      url,
      context.read<AuthProvider>().token,
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoLabel = widget.photoCount == 1 ? 'image' : 'images';

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: 0,
            right: 0,
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    PrismColors.prismYellow.withValues(alpha: 0.18),
                    PrismColors.neonPink.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  radius: 0.9,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    children: [
                      Center(child: _buildFlipSmiley()),
                      const SizedBox(height: 28),
                      Text(
                        'Images shared with',
                        style: PrismTextStyles.h2.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      )
                          .animate()
                          .fadeIn(duration: 500.ms, delay: 400.ms)
                          .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.photoCount} $photoLabel delivered',
                        style: PrismTextStyles.bodyMedium.copyWith(
                          color: PrismColors.secondaryText,
                        ),
                        textAlign: TextAlign.center,
                      )
                          .animate()
                          .fadeIn(duration: 500.ms, delay: 550.ms),
                      const SizedBox(height: 36),
                      ...widget.recipients.asMap().entries.map((entry) {
                        final index = entry.key;
                        final recipient = entry.value;
                        return _RecipientTile(
                          recipient: recipient,
                          headers: _authHeaders(recipient.profilePictureUrl),
                        )
                            .animate()
                            .fadeIn(
                              duration: 450.ms,
                              delay: (650 + index * 80).ms,
                            )
                            .slideX(
                              begin: 0.08,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            );
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: PrismButton(
                    text: 'Back to Gallery',
                    onPressed: _goHome,
                  )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 800.ms)
                      .slideY(begin: 0.3, end: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlipSmiley() {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value;
        final isBack = angle > math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(angle),
          child: isBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: child,
                )
              : child,
        );
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: PrismColors.prismSignature,
          boxShadow: [
            BoxShadow(
              color: PrismColors.prismYellow.withValues(alpha: 0.35),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: PrismColors.surfaceGray,
          ),
          child: const Center(
            child: Text(
              '\u{1F60A}',
              style: TextStyle(fontSize: 56),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipientTile extends StatelessWidget {
  final DetectedRecipient recipient;
  final Map<String, String>? headers;

  const _RecipientTile({
    required this.recipient,
    required this.headers,
  });

  @override
  Widget build(BuildContext context) {
    final photoLabel =
        recipient.count == 1 ? '1 photo' : '${recipient.count} photos';
    final profileUrl = recipient.profilePictureUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: PrismColors.glassDark,
        borderColor: PrismColors.white.withValues(alpha: 0.06),
        child: Row(
          children: [
            _buildAvatar(profileUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipient.username,
                    style: PrismTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    photoLabel,
                    style: PrismTextStyles.bodySmall.copyWith(
                      color: PrismColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PrismColors.successGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: PrismColors.successGreen,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String profileUrl) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: PrismColors.prismYellow.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: profileUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: profileUrl,
                httpHeaders: headers,
                fit: BoxFit.cover,
                placeholder: (_, __) => _avatarFallback(),
                errorWidget: (_, __, ___) => _avatarFallback(),
              )
            : _avatarFallback(),
      ),
    );
  }

  Widget _avatarFallback() {
    final initial = recipient.username.isNotEmpty
        ? recipient.username[0].toUpperCase()
        : '?';

    return ColoredBox(
      color: PrismColors.inputGray,
      child: Center(
        child: Text(
          initial,
          style: PrismTextStyles.h3.copyWith(fontSize: 18),
        ),
      ),
    );
  }
}
