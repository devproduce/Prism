import 'package:flutter/material.dart';

class PrismColors {
  // 🌊 PRIMARY BRAND COLORS (Blue-Tinted)
  static const Color primaryBlue = Color(0xFF00D4FF); // Bright Cyan
  static const Color accentBlue = Color(0xFF4FC3F7); // Light Blue
  static const Color deepBlue = Color(0xFF1976D2); // Deep Blue
  
  // 🌚 DARK MODE (Blue-Tinted Navy)
  static const Color darkBase = Color(0xFF0A1929); // Deep Navy
  static const Color darkCard = Color(0xFF1A2332); // Navy Card
  static const Color darkElevated = Color(0xFF2C3E50); // Elevated Navy
  
  // 🌝 LIGHT MODE (Sky Blue Tints)
  static const Color lightBase = Color(0xFFE3F2FD); // Light Sky Blue
  static const Color lightCard = Color(0xFFFAFAFF); // Almost White
  static const Color lightElevated = Color(0xFFBBDEFB); // Soft Blue
  
  // 🌫️ NEUTRALS (Theme-Adaptive)
  static const Color textPrimaryDark = Color(0xFFE1F5FE); // Light Blue Text (Dark Mode)
  static const Color textPrimaryLight = Color(0xFF0D47A1); // Dark Blue Text (Light Mode)
  static const Color textSecondaryDark = Color(0xFF90CAF9); // Medium Blue (Dark)
  static const Color textSecondaryLight = Color(0xFF1976D2); // Medium Blue (Light)
  static const Color white = Colors.white;
  static const Color dividerDark = Color(0xFF2C3E50);
  static const Color dividerLight = Color(0xFFB3E5FC);
  static const Color iconGray = Color(0xFF81D4FA);
  static const Color white70 = ColorUtils.white70;

  // ❄️ GLASSMORPHISM COLORS (Blue-Tinted Frost)
  static const Color glassFrostedWhite = Color.fromRGBO(255, 255, 255, 0.18);
  static const Color glassFrostedBlueDark = Color.fromRGBO(0, 212, 255, 0.15); // Cyan tint
  static const Color glassFrostedBlueLight = Color.fromRGBO(25, 118, 210, 0.08); // Blue tint
  static const Color glassSnowMist = Color.fromRGBO(255, 255, 255, 0.08);
  static const Color glassFrostBorder = Color.fromRGBO(79, 195, 247, 0.25);
  static const Color glassFrostShadow = Color.fromRGBO(0, 0, 0, 0.12);
  static const Color glassDark = Color.fromRGBO(26, 35, 50, 0.65);
  static const Color glassLight = Color.fromRGBO(227, 242, 253, 0.45);
  static const Color glassBlueGlow = Color.fromRGBO(0, 212, 255, 0.35);

  // 🍃 SUCCESS / WARNING / ERROR (Consistent across themes)
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningYellow = Color(0xFFFFB300);
  static const Color errorRed = Color(0xFFF44336);
  
  // Friends Status Colors
  static const Color friendAccepted = Color(0xFF4CAF50);
  static const Color friendPending = Color(0xFFFFB300);
  static const Color friendBlocked = Color(0xFFF44336);

  // 🌤️ GRADIENTS (Blue-Tinted)
  static const LinearGradient prismSignatureDark = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF0288D1)], // Cyan to Deep Blue
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient prismSignatureLight = LinearGradient(
    colors: [Color(0xFF4FC3F7), Color(0xFF1976D2)], // Light Blue to Deep Blue
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient oceanBreezeDark = LinearGradient(
    colors: [Color(0xFF006064), Color(0xFF00ACC1)], // Dark Teal to Cyan
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient oceanBreezeLight = LinearGradient(
    colors: [Color(0xFF00838F), Color(0xFF4DD0E1)], // Teal to Light Cyan
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient royalNightFade = LinearGradient(
    colors: [Color(0xFF0A1929), Color(0xFF1A2332)], // Deep Navy gradient
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient skyDayFade = LinearGradient(
    colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)], // Sky Blue gradient
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Backward compatibility (map to blue equivalents)
  static const Color purple = primaryBlue;
  static const Color electricBlue = accentBlue;
  static const Color neoPink = deepBlue;
  static const LinearGradient prismSignature = prismSignatureDark;
  static const LinearGradient sunsetGlow = oceanBreezeDark;
  static const LinearGradient auroraTeal = oceanBreezeLight;
  static const Color textPrimary = textPrimaryDark;
  static const Color textSecondary = textSecondaryDark;
  static const Color divider = dividerDark;
  static const Color glassLavenderGlow = glassBlueGlow;
}

class ColorUtils {
  static const Color white70 = Color(0xB3FFFFFF);
}
