import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prism/theme/colors.dart';

class AppTheme {
  // STRICT DARK MODE
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: PrismColors.voidBlack,
    primaryColor: PrismColors.prismYellow,

    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: PrismColors.prismYellow,
      onPrimary: PrismColors.black, // Text on yellow is black
      secondary: PrismColors.inputGray, // Used for secondary actions
      onSecondary: PrismColors.white,
      surface: PrismColors.surfaceGray,
      onSurface: PrismColors.white,
      error: PrismColors.destructiveRed,
      onError: PrismColors.white,
    ),

    // Typography
    fontFamily: GoogleFonts.inter().fontFamily,
    textTheme: TextTheme(
      // Headings
      displayLarge: GoogleFonts.inter(
        color: PrismColors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: GoogleFonts.inter(
        color: PrismColors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: GoogleFonts.inter(
        color: PrismColors.white,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),

      // Headlines
      headlineLarge: GoogleFonts.inter(
        color: PrismColors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.inter(
        color: PrismColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),

      // Body
      bodyLarge: GoogleFonts.inter(
        color: PrismColors.white,
        fontSize: 16,
        fontWeight: FontWeight.normal,
      ),
      bodyMedium: GoogleFonts.inter(
        color: PrismColors.secondaryText,
        fontSize: 14,
        fontWeight: FontWeight.normal,
      ),
      bodySmall: GoogleFonts.inter(
        color: PrismColors.secondaryText,
        fontSize: 12,
        fontWeight: FontWeight.normal,
      ),

      // Button Text
      labelLarge: GoogleFonts.inter(
        color: PrismColors.black,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),

    // App Bar
    appBarTheme: AppBarTheme(
      backgroundColor:
          Colors.transparent, // Detailed screens might want transparent
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: PrismColors.white),
      titleTextStyle: GoogleFonts.inter(
        color: PrismColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      color: PrismColors.surfaceGray,
      elevation: 0, // Flat matte finish
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),

    // Input Decoration (Globally Applied)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PrismColors.inputGray,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.white24,
          width: 1,
        ), // Subtle ring
      ),
      hintStyle: GoogleFonts.inter(
        color: PrismColors.secondaryText,
        fontSize: 14,
      ),
    ),

    // Divider
    dividerColor: Colors.white10,
    dividerTheme: const DividerThemeData(
      color: Colors.white10,
      thickness: 1,
      space: 1,
    ),

    // Icon Theme
    iconTheme: const IconThemeData(color: PrismColors.white, size: 24),
  );

  // Alias light theme to dark theme to enforce strict mode even if system is light
  static ThemeData lightTheme = darkTheme;
}
