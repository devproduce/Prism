import 'package:flutter/material.dart';

/// Animation constants and utilities for consistent animations across the app
class AppAnimations {
  // ============ DURATION CONSTANTS ============
  
  /// Fast animations - 200ms - Micro-interactions (button press, toggle)
  static const Duration fast = Duration(milliseconds: 200);
  
  /// Medium animations - 300ms - Default for most transitions
  static const Duration medium = Duration(milliseconds: 300);
  
  /// Medium-slow animations - 400ms - Screen transitions, card animations
  static const Duration mediumSlow = Duration(milliseconds: 400);
  
  /// Slow animations - 500-600ms - Complex transitions, hero animations
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration slower = Duration(milliseconds: 600);
  
  /// Very slow animations - 800-1000ms - Celebratory animations, success states
  static const Duration verySlow = Duration(milliseconds: 800);
  static const Duration celebration = Duration(milliseconds: 1000);
  
  // ============ CURVE CONSTANTS ============
  
  /// Standard curve for most transitions
  static const Curve standard = Curves.easeInOut;
  
  /// Emphasis curve for entering screens
  static const Curve emphasis = Curves.easeOutCubic;
  
  /// Deceleration curve for exiting screens
  static const Curve deceleration = Curves.decelerate;
  
  /// Spring curve for playful interactions
  static const Curve spring = Curves.elasticOut;
  
  /// Smooth curve for subtle animations
  static const Curve smooth = Curves.easeOut;
  
  /// Fast out, slow in curve
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
  
  // ============ STAGGER TIMING ============
  
  /// Delay between list items (50ms)
  static const Duration listStagger = Duration(milliseconds: 50);
  
  /// Delay between grid items (80ms)
  static const Duration gridStagger = Duration(milliseconds: 80);
  
  /// Delay between form fields (100ms)
  static const Duration formStagger = Duration(milliseconds: 100);
  
  // ============ PAGE TRANSITION BUILDERS ============
  
  /// Fade transition
  static PageRouteBuilder<T> fadeTransition<T>({
    required Widget page,
    Duration? duration,
    Curve? curve,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? medium,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: curve ?? standard,
          ),
          child: child,
        );
      },
    );
  }
  
  /// Slide from right transition (standard forward navigation)
  static PageRouteBuilder<T> slideFromRight<T>({
    required Widget page,
    Duration? duration,
    Curve? curve,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? mediumSlow,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end);
        final offsetAnimation = animation.drive(
          tween.chain(CurveTween(curve: curve ?? emphasis)),
        );
        
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
  
  /// Slide from bottom transition (modals, sheets)
  static PageRouteBuilder<T> slideFromBottom<T>({
    required Widget page,
    Duration? duration,
    Curve? curve,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? mediumSlow,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end);
        final offsetAnimation = animation.drive(
          tween.chain(CurveTween(curve: curve ?? emphasis)),
        );
        
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
  
  /// Scale + Fade transition (image viewer, detail views)
  static PageRouteBuilder<T> scaleAndFade<T>({
    required Widget page,
    Duration? duration,
    Curve? curve,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? mediumSlow,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve ?? emphasis,
        );
        
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }
  
  /// Slide + Fade transition (smooth entry)
  static PageRouteBuilder<T> slideAndFade<T>({
    required Widget page,
    Duration? duration,
    Curve? curve,
    Offset? beginOffset,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? mediumSlow,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final begin = beginOffset ?? const Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve ?? emphasis,
        );
        final offsetAnimation = tween.animate(curvedAnimation);
        
        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }
  
  // ============ MICRO-INTERACTION BUILDERS ============
  
  /// Button press scale animation
  static Widget buttonPressAnimation({
    required Widget child,
    required VoidCallback? onTap,
    double scale = 0.95,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: 1.0),
      duration: fast,
      curve: standard,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) {},
        onTapUp: (_) {},
        onTapCancel: () {},
        onTap: onTap,
        child: child,
      ),
    );
  }
  
  // ============ STAGGER ANIMATION HELPER ============
  
  /// Calculate stagger delay for an item in a list/grid
  static Duration staggerDelay(int index, {Duration? baseDelay}) {
    return (baseDelay ?? listStagger) * index;
  }
  
  /// Calculate diagonal stagger delay for grid items
  static Duration gridDiagonalStagger(int row, int col, {Duration? baseDelay}) {
    return (baseDelay ?? gridStagger) * (row + col);
  }
}

/// Extension on BuildContext for easy animation access
extension AnimationExtensions on BuildContext {
  /// Navigate with fade transition
  Future<T?> navigateWithFade<T>(Widget page) {
    return Navigator.of(this).push<T>(
      AppAnimations.fadeTransition<T>(page: page),
    );
  }
  
  /// Navigate with slide from right transition
  Future<T?> navigateWithSlide<T>(Widget page) {
    return Navigator.of(this).push<T>(
      AppAnimations.slideFromRight<T>(page: page),
    );
  }
  
  /// Navigate with scale and fade transition
  Future<T?> navigateWithScale<T>(Widget page) {
    return Navigator.of(this).push<T>(
      AppAnimations.scaleAndFade<T>(page: page),
    );
  }
  
  /// Navigate with slide from bottom transition
  Future<T?> navigateWithBottomSlide<T>(Widget page) {
    return Navigator.of(this).push<T>(
      AppAnimations.slideFromBottom<T>(page: page),
    );
  }
}
