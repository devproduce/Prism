import 'package:flutter/material.dart';

class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Dark Theme Color Palette
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkPrimaryText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFF9E9E9E);
  static const Color darkTertiaryText = Color(0xFF757575);
  static const Color darkSkipText = Color(0xFFBDBDBD);
  static const Color darkDotInactive = Color(0xFF424242);
  static const Color darkDotActive = Color(0xFFFFFFFF);

  // Light Theme Color Palette
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightPrimaryText = Color(0xFF000000);
  static const Color lightSecondaryText = Color(0xFF616161);
  static const Color lightTertiaryText = Color(0xFF9E9E9E);
  static const Color lightSkipText = Color(0xFF757575);
  static const Color lightDotInactive = Color(0xFFE0E0E0);
  static const Color lightDotActive = Color(0xFF000000);

  // Common Colors (same for both themes)
  static const Color primaryAccent = Color(
    0xFFE8F156,
  ); // Yellow/Lime button color
  static const Color secondaryAccent = Color(
    0xFFD4E54E,
  ); // Slightly darker yellow
  static const Color buttonText = Color(
    0xFF000000,
  ); // Black text on yellow buttons

  // Dynamic color getters based on current brightness
  static Color primaryBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }

  static Color primaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimaryText
        : lightPrimaryText;
  }

  static Color secondaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSecondaryText
        : lightSecondaryText;
  }

  static Color tertiaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTertiaryText
        : lightTertiaryText;
  }

  static Color skipText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSkipText
        : lightSkipText;
  }

  static Color dotInactive(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkDotInactive
        : lightDotInactive;
  }

  static Color dotActive(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkDotActive
        : lightDotActive;
  }

  // Text Styles
  static TextStyle headlineStyle(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final isMediumScreen = size.width >= 360 && size.width < 600;

    return TextStyle(
      color: primaryText(context),
      fontSize: isSmallScreen
          ? size.width * 0.065
          : isMediumScreen
          ? size.width * 0.060
          : size.width * 0.055,
      fontWeight: FontWeight.bold,
      height: 1.3,
      letterSpacing: 0.5,
    );
  }

  static TextStyle subHeadlineStyle(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final isMediumScreen = size.width >= 360 && size.width < 600;

    return TextStyle(
      color: secondaryText(context),
      fontSize: isSmallScreen
          ? size.width * 0.038
          : isMediumScreen
          ? size.width * 0.036
          : size.width * 0.034,
      fontWeight: FontWeight.w400,
      height: 1.5,
      letterSpacing: 0.3,
    );
  }

  static TextStyle buttonTextStyle(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final isMediumScreen = size.width >= 360 && size.width < 600;

    return TextStyle(
      color: buttonText,
      fontSize: isSmallScreen
          ? size.width * 0.045
          : isMediumScreen
          ? size.width * 0.042
          : size.width * 0.040,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
  }

  static TextStyle skipButtonStyle(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final isMediumScreen = size.width >= 360 && size.width < 600;

    return TextStyle(
      color: skipText(context),
      fontSize: isSmallScreen
          ? size.width * 0.040
          : isMediumScreen
          ? size.width * 0.038
          : size.width * 0.036,
      fontWeight: FontWeight.w500,
    );
  }

  // Button Decorations
  static BoxDecoration primaryButtonDecoration({double borderRadius = 25.0}) {
    return BoxDecoration(
      color: primaryAccent,
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  static BoxDecoration secondaryButtonDecoration({double borderRadius = 25.0}) {
    return BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: primaryAccent, width: 2.0),
    );
  }

  // Get responsive button height
  static double buttonHeight(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final isMediumScreen = size.width >= 360 && size.width < 600;

    return isSmallScreen
        ? size.height * 0.065
        : isMediumScreen
        ? size.height * 0.060
        : size.height * 0.055;
  }

  // Get responsive horizontal padding
  static double horizontalPadding(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width * 0.08;
  }

  // Get responsive vertical spacing
  static double verticalSpacing(BuildContext context, double factor) {
    final size = MediaQuery.of(context).size;
    return size.height * factor;
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primaryAccent,
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        secondary: secondaryAccent,
        surface: darkBackground,
        background: darkBackground,
        onPrimary: buttonText,
        onSecondary: buttonText,
        onSurface: darkPrimaryText,
        onBackground: darkPrimaryText,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: darkPrimaryText),
        displayMedium: TextStyle(color: darkPrimaryText),
        displaySmall: TextStyle(color: darkPrimaryText),
        headlineLarge: TextStyle(color: darkPrimaryText),
        headlineMedium: TextStyle(color: darkPrimaryText),
        headlineSmall: TextStyle(color: darkPrimaryText),
        titleLarge: TextStyle(color: darkPrimaryText),
        titleMedium: TextStyle(color: darkPrimaryText),
        titleSmall: TextStyle(color: darkPrimaryText),
        bodyLarge: TextStyle(color: darkSecondaryText),
        bodyMedium: TextStyle(color: darkSecondaryText),
        bodySmall: TextStyle(color: darkSecondaryText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: buttonText,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAccent,
          side: const BorderSide(color: primaryAccent, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
    );
  }

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: primaryAccent,
      colorScheme: const ColorScheme.light(
        primary: primaryAccent,
        secondary: secondaryAccent,
        surface: lightBackground,
        background: lightBackground,
        onPrimary: buttonText,
        onSecondary: buttonText,
        onSurface: lightPrimaryText,
        onBackground: lightPrimaryText,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: lightPrimaryText),
        displayMedium: TextStyle(color: lightPrimaryText),
        displaySmall: TextStyle(color: lightPrimaryText),
        headlineLarge: TextStyle(color: lightPrimaryText),
        headlineMedium: TextStyle(color: lightPrimaryText),
        headlineSmall: TextStyle(color: lightPrimaryText),
        titleLarge: TextStyle(color: lightPrimaryText),
        titleMedium: TextStyle(color: lightPrimaryText),
        titleSmall: TextStyle(color: lightPrimaryText),
        bodyLarge: TextStyle(color: lightSecondaryText),
        bodyMedium: TextStyle(color: lightSecondaryText),
        bodySmall: TextStyle(color: lightSecondaryText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: buttonText,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAccent,
          side: const BorderSide(color: primaryAccent, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
    );
  }
}
