import 'package:flutter/material.dart';

class PrismColors {
  // 🌑 CORE PALETTE (Tech-Noir)
  static const Color voidBlack = Color(0xFF0E0E0E); // Main Background
  static const Color surfaceGray = Color(0xFF1C1C1E); // Cards / Modals
  static const Color inputGray = Color(
    0xFF2C2C2E,
  ); // Inputs / Secondary Buttons

  // ✨ ACCENTS
  static const Color prismYellow = Color(0xFFF3E68F); // Primary Action
  static const Color neonPink = Color(0xFFEFA9B6); // Face ID / Scanning
  static const Color electricCyan = Color(0xFF4AF2EA); // AI / Loading
  static const Color deepCyan = Color(0xFF2E86DE); // Gradient end for Cyan

  // 🚦 FUNCTIONAL
  static const Color successGreen = Color(0xFF4ADE80); // Text/Icon green
  static const Color successGreenBg = Color(0xFF2E5C38); // Background green
  static const Color destructiveRed = Color(0xFFFF0000); // Errors / Delete

  // 📝 TEXT
  static const Color white = Color(0xFFFFFFFF); // Primary Text
  static const Color secondaryText = Color(
    0xFFA1A1AA,
  ); // Subtitles / Placeholders
  static const Color black = Color(0xFF000000); // Text on Yellow buttons

  // 🌫️ GLASS & OVERLAYS (Adapted for Dark Mode)
  static const Color glassDark = Color.fromRGBO(
    28,
    28,
    30,
    0.70,
  ); // Surface Gray with opacity
  static const Color overlayBlack = Color.fromRGBO(
    0,
    0,
    0,
    0.5,
  ); // Modal backdrop

  // 🌈 GRADIENTS
  static const LinearGradient prismSignature = LinearGradient(
    colors: [prismYellow, neonPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [electricCyan, deepCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Helper for "Void" background with no gradients generally, but keeping for legacy compatibility if needed
  static const LinearGradient voidGradient = LinearGradient(
    colors: [voidBlack, voidBlack],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Backward compatibility (Mapping old names to new palette where sensible to avoid immediate breakages)
  static const Color primaryBlue = prismYellow; // Replaced by Yellow
  static const Color accentBlue = electricCyan; // Replaced by Cyan
  static const Color deepBlue = deepCyan;
  static const Color darkBase = voidBlack;
  static const Color darkCard = surfaceGray;
  static const Color errorRed = destructiveRed;
  static const Color textPrimaryDark = white;
  static const Color textSecondaryDark = secondaryText;

  // Missing aliases to fix lints
  static const Color purple = prismYellow;
  static const Color electricBlue = electricCyan;
  static const Color neoPink = neonPink;
  static const LinearGradient prismSignatureDark = prismSignature;
  static const LinearGradient sunsetGlow = cyanGradient;
  static const LinearGradient royalNightFade = voidGradient;
  static const Color textSecondary = secondaryText;
  static const Color warningYellow = prismYellow;

  // Glass aliases
  static const Color glassFrostedWhite = glassDark;
  static const Color glassBlueGlow = electricCyan;
  static const Color glassSnowMist = glassDark;
  static const Color glassLight = glassDark;
  static const Color glassFrostShadow = overlayBlack;
  static const Color glassFrostBorder = inputGray;
  static const Color lightElevated = surfaceGray;
  static const Color textSecondaryLight = secondaryText;
}

class ColorUtils {
  static const Color white70 = Color(0xB3FFFFFF);
}
