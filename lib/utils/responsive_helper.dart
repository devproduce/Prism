import 'package:flutter/material.dart';

/// A utility class for responsive design helpers.
/// Use these methods to create layouts that adapt to different screen sizes.
class ResponsiveHelper {
  // Screen size breakpoints
  static const double phoneSmall = 360; // Small phones
  static const double phone = 600; // Standard phones
  static const double phablet = 720; // Large phones/small tablets
  static const double tablet = 900; // Tablets
  
  // Legacy breakpoints (kept for backward compatibility)
  static const double smallScreen = 360;
  static const double mediumScreen = 400;
  static const double largeScreen = 600;
  static const double tabletScreen = 768;

  /// Get the screen width
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Get the screen height
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Get safe area padding
  static EdgeInsets safeArea(BuildContext context) =>
      MediaQuery.of(context).padding;

  /// Check if device is a small screen (< 360dp)
  static bool isSmallScreen(BuildContext context) =>
      screenWidth(context) < smallScreen;

  /// Check if device is a medium screen (360-600dp)
  static bool isMediumScreen(BuildContext context) =>
      screenWidth(context) >= smallScreen && screenWidth(context) < largeScreen;

  /// Check if device is a large screen (600-768dp)
  static bool isLargeScreen(BuildContext context) =>
      screenWidth(context) >= largeScreen &&
      screenWidth(context) < tabletScreen;

  /// Check if device is a tablet (>= 768dp)
  static bool isTablet(BuildContext context) =>
      screenWidth(context) >= tabletScreen;
  
  /// Check if device is in portrait orientation
  static bool isPortrait(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.portrait;
  
  /// Check if device is in landscape orientation
  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;
  
  /// Get device type as enum
  static DeviceType getDeviceType(BuildContext context) {
    final width = screenWidth(context);
    if (width < phoneSmall) return DeviceType.phoneSmall;
    if (width < phone) return DeviceType.phone;
    if (width < phablet) return DeviceType.phablet;
    return DeviceType.tablet;
  }
  
  /// Get adaptive spacing scale based on device type
  static double getSpacingScale(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.phoneSmall:
        return 0.8;
      case DeviceType.phone:
        return 1.0;
      case DeviceType.phablet:
        return 1.1;
      case DeviceType.tablet:
        return 1.3;
    }
  }
  
  /// Get adaptive font scale based on device type
  static double getFontScale(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.phoneSmall:
        return 0.9;
      case DeviceType.phone:
        return 1.0;
      case DeviceType.phablet:
        return 1.05;
      case DeviceType.tablet:
        return 1.15;
    }
  }

  // ============ RESPONSIVE PADDING ============

  /// Standard page horizontal padding (responsive)
  static double horizontalPadding(BuildContext context) {
    final width = screenWidth(context);
    if (width < smallScreen) return 16;
    if (width < mediumScreen) return 20;
    if (width < largeScreen) return 24;
    return 32;
  }

  /// Standard page padding (responsive)
  static EdgeInsets pagePadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: horizontalPadding(context),
      vertical: 16,
    );
  }

  /// Symmetric horizontal padding only
  static EdgeInsets horizontalPaddingOnly(BuildContext context) {
    return EdgeInsets.symmetric(horizontal: horizontalPadding(context));
  }

  // ============ RESPONSIVE SPACING ============

  /// Extra small vertical spacing
  static double spacingXS(BuildContext context) {
    return screenHeight(context) * 0.005; // ~4-5px
  }

  /// Small vertical spacing
  static double spacingS(BuildContext context) {
    return screenHeight(context) * 0.01; // ~8-10px
  }

  /// Medium vertical spacing
  static double spacingM(BuildContext context) {
    return screenHeight(context) * 0.02; // ~16-20px
  }

  /// Large vertical spacing
  static double spacingL(BuildContext context) {
    return screenHeight(context) * 0.03; // ~24-30px
  }

  /// Extra large vertical spacing
  static double spacingXL(BuildContext context) {
    return screenHeight(context) * 0.05; // ~40-50px
  }

  // ============ RESPONSIVE SIZING ============

  /// Icon size - small (responsive)
  static double iconSizeS(BuildContext context) {
    final width = screenWidth(context);
    if (width < smallScreen) return 16;
    if (width < mediumScreen) return 18;
    return 20;
  }

  /// Icon size - medium (responsive)
  static double iconSizeM(BuildContext context) {
    final width = screenWidth(context);
    if (width < smallScreen) return 20;
    if (width < mediumScreen) return 22;
    return 24;
  }

  /// Icon size - large (responsive)
  static double iconSizeL(BuildContext context) {
    final width = screenWidth(context);
    if (width < smallScreen) return 28;
    if (width < mediumScreen) return 32;
    return 36;
  }

  /// Icon size - extra large for headers/features
  static double iconSizeXL(BuildContext context) {
    final width = screenWidth(context);
    if (width < smallScreen) return 36;
    if (width < mediumScreen) return 40;
    return 48;
  }

  /// Avatar size - small
  static double avatarSizeS(BuildContext context) {
    final width = screenWidth(context);
    if (width < smallScreen) return 32;
    if (width < mediumScreen) return 36;
    return 40;
  }

  /// Avatar size - medium
  static double avatarSizeM(BuildContext context) {
    final width = screenWidth(context);
    if (width < smallScreen) return 40;
    if (width < mediumScreen) return 48;
    return 56;
  }

  /// Avatar size - large (profile headers)
  static double avatarSizeL(BuildContext context) {
    final width = screenWidth(context);
    if (width < smallScreen) return 80;
    if (width < mediumScreen) return 96;
    return 120;
  }

  /// Button height (responsive)
  static double buttonHeight(BuildContext context) {
    final height = screenHeight(context);
    if (height < 600) return 44;
    if (height < 800) return 48;
    return 52;
  }

  /// Input field height (responsive)
  static double inputHeight(BuildContext context) {
    final height = screenHeight(context);
    if (height < 600) return 44;
    if (height < 800) return 48;
    return 52;
  }

  // ============ GRID CALCULATIONS ============

  /// Calculate grid cross axis count based on screen width
  static int gridCrossAxisCount(
    BuildContext context, {
    int minCount = 2,
    int maxCount = 4,
    double itemMinWidth = 120,
  }) {
    final width = screenWidth(context);
    int count = (width / itemMinWidth).floor();
    return count.clamp(minCount, maxCount);
  }

  /// Standard gallery grid cross axis count
  static int galleryGridCount(BuildContext context) {
    final width = screenWidth(context);
    if (width < smallScreen) return 2;
    if (width < largeScreen) return 3;
    if (width < tabletScreen) return 4;
    return 5;
  }

  /// Grid child aspect ratio (responsive)
  static double gridAspectRatio(BuildContext context) {
    final width = screenWidth(context);
    if (width < smallScreen) return 1.0;
    return 0.9; // Slightly taller on larger screens
  }

  // ============ FONT SIZING ============

  /// Scales a font size based on screen width
  /// Use sparingly - prefer theme text styles
  static double scaledFontSize(BuildContext context, double baseSize) {
    final width = screenWidth(context);
    if (width < smallScreen) return baseSize * 0.9;
    if (width < mediumScreen) return baseSize;
    if (width < largeScreen) return baseSize * 1.05;
    return baseSize * 1.1;
  }

  // ============ RESPONSIVE WIDGETS ============

  /// Creates a responsive SizedBox for vertical spacing
  static Widget verticalSpace(BuildContext context, {double factor = 1.0}) {
    return SizedBox(height: spacingM(context) * factor);
  }

  /// Creates a responsive SizedBox for horizontal spacing
  static Widget horizontalSpace(BuildContext context, {double factor = 1.0}) {
    return SizedBox(width: spacingM(context) * factor);
  }

  // ============ DIALOG SIZING ============

  /// Maximum width for dialogs (responsive)
  static double dialogMaxWidth(BuildContext context) {
    final width = screenWidth(context);
    if (width < smallScreen) return width * 0.95;
    if (width < mediumScreen) return width * 0.9;
    if (width < largeScreen) return width * 0.85;
    return 500; // Max width on tablets
  }

  /// Sheet height for bottom sheets (responsive)
  static double bottomSheetMaxHeight(BuildContext context) {
    return screenHeight(context) * 0.85;
  }

  // ============ SAFE AREA HELPERS ============

  /// Get bottom safe area height (for navigation bars)
  static double bottomSafeArea(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }

  /// Get top safe area height (for status bar)
  static double topSafeArea(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  /// Get keyboard height when visible
  static double keyboardHeight(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }

  /// Check if keyboard is visible
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }
}

/// Extension methods for easier responsive access
extension ResponsiveContext on BuildContext {
  double get screenWidth => ResponsiveHelper.screenWidth(this);
  double get screenHeight => ResponsiveHelper.screenHeight(this);
  bool get isSmallScreen => ResponsiveHelper.isSmallScreen(this);
  bool get isMediumScreen => ResponsiveHelper.isMediumScreen(this);
  bool get isLargeScreen => ResponsiveHelper.isLargeScreen(this);
  bool get isTablet => ResponsiveHelper.isTablet(this);
  bool get isPortrait => ResponsiveHelper.isPortrait(this);
  bool get isLandscape => ResponsiveHelper.isLandscape(this);
  DeviceType get deviceType => ResponsiveHelper.getDeviceType(this);
  double get spacingScale => ResponsiveHelper.getSpacingScale(this);
  double get fontScale => ResponsiveHelper.getFontScale(this);
  EdgeInsets get pagePadding => ResponsiveHelper.pagePadding(this);
  double get horizontalPadding => ResponsiveHelper.horizontalPadding(this);
}

/// Device type enum for responsive design decisions
enum DeviceType {
  phoneSmall,
  phone,
  phablet,
  tablet,
}
