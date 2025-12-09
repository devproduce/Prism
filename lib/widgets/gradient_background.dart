import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';

/// Reusable gradient background with decorative orbs
/// Used consistently across all screens in the app
class GradientBackground extends StatelessWidget {
  final Widget child;
  
  const GradientBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: PrismColors.royalNightFade,
          ),
        ),
        // Decorative orbs
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PrismColors.primaryBlue.withOpacity(0.15),
              boxShadow: [
                BoxShadow(
                  color: PrismColors.glassBlueGlow,
                  blurRadius: 100,
                  spreadRadius: 50,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          right: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PrismColors.accentBlue.withOpacity(0.12),
              boxShadow: [
                BoxShadow(
                  color: PrismColors.accentBlue.withOpacity(0.15),
                  blurRadius: 80,
                  spreadRadius: 40,
                ),
              ],
            ),
          ),
        ),
        // Content
        child,
      ],
    );
  }
}
