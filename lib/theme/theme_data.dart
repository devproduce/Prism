import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prism/theme/colors.dart';

class AppTheme {
  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: PrismColors.darkBase,
    primaryColor: PrismColors.primaryBlue,
    colorScheme: const ColorScheme.dark(
      primary: PrismColors.primaryBlue,
      secondary: PrismColors.accentBlue,
      surface: PrismColors.darkCard,
      background: PrismColors.darkBase,
      error: PrismColors.errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: PrismColors.textPrimaryDark,
      onBackground: PrismColors.textPrimaryDark,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: PrismColors.darkCard,
      elevation: 0,
      iconTheme: const IconThemeData(color: PrismColors.primaryBlue),
      titleTextStyle: GoogleFonts.poppins(
        color: PrismColors.textPrimaryDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.poppins(color: PrismColors.textPrimaryDark, fontSize: 32, fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.poppins(color: PrismColors.textPrimaryDark, fontSize: 24, fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.poppins(color: PrismColors.textPrimaryDark, fontSize: 20, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(color: PrismColors.textPrimaryDark, fontSize: 16),
      bodyMedium: GoogleFonts.inter(color: PrismColors.textSecondaryDark, fontSize: 14),
      bodySmall: GoogleFonts.inter(color: PrismColors.textSecondaryDark, fontSize: 12),
    ),
    cardTheme: CardThemeData(
      color: PrismColors.darkCard,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerColor: PrismColors.dividerDark,
  );

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: PrismColors.lightBase,
    primaryColor: PrismColors.deepBlue,
    colorScheme: const ColorScheme.light(
      primary: PrismColors.deepBlue,
      secondary: PrismColors.accentBlue,
      surface: PrismColors.lightCard,
      background: PrismColors.lightBase,
      error: PrismColors.errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: PrismColors.textPrimaryLight,
      onBackground: PrismColors.textPrimaryLight,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: PrismColors.lightCard,
      elevation: 0,
      iconTheme: const IconThemeData(color: PrismColors.deepBlue),
      titleTextStyle: GoogleFonts.poppins(
        color: PrismColors.textPrimaryLight,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.poppins(color: PrismColors.textPrimaryLight, fontSize: 32, fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.poppins(color: PrismColors.textPrimaryLight, fontSize: 24, fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.poppins(color: PrismColors.textPrimaryLight, fontSize: 20, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(color: PrismColors.textPrimaryLight, fontSize: 16),
      bodyMedium: GoogleFonts.inter(color: PrismColors.textSecondaryLight, fontSize: 14),
      bodySmall: GoogleFonts.inter(color: PrismColors.textSecondaryLight, fontSize: 12),
    ),
    cardTheme: CardThemeData(
      color: PrismColors.lightCard,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerColor: PrismColors.dividerLight,
  );
}
