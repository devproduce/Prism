import 'package:flutter/material.dart';
import 'package:prism/utils/animations.dart';

/// Navigation helper with consistent page transitions
class NavigationHelper {
  /// Navigate with fade transition
  static Future<T?> navigateWithFade<T>(
    BuildContext context,
    Widget page, {
    bool replace = false,
  }) {
    final route = AppAnimations.fadeTransition<T>(page: page);
    return replace
        ? Navigator.of(context).pushReplacement(route)
        : Navigator.of(context).push(route);
  }

  /// Navigate with slide from right (standard forward navigation)
  static Future<T?> navigateWithSlide<T>(
    BuildContext context,
    Widget page, {
    bool replace = false,
  }) {
    final route = AppAnimations.slideFromRight<T>(page: page);
    return replace
        ? Navigator.of(context).pushReplacement(route)
        : Navigator.of(context).push(route);
  }

  /// Navigate with slide from bottom (modals)
  static Future<T?> navigateWithBottomSlide<T>(
    BuildContext context,
    Widget page, {
    bool replace = false,
  }) {
    final route = AppAnimations.slideFromBottom<T>(page: page);
    return replace
        ? Navigator.of(context).pushReplacement(route)
        : Navigator.of(context).push(route);
  }

  /// Navigate with scale and fade (detail views)
  static Future<T?> navigateWithScale<T>(
    BuildContext context,
    Widget page, {
    bool replace = false,
  }) {
    final route = AppAnimations.scaleAndFade<T>(page: page);
    return replace
        ? Navigator.of(context).pushReplacement(route)
        : Navigator.of(context).push(route);
  }

  /// Navigate with slide and fade (smooth entry)
  static Future<T?> navigateWithSlideAndFade<T>(
    BuildContext context,
    Widget page, {
    bool replace = false,
    Offset? beginOffset,
  }) {
    final route = AppAnimations.slideAndFade<T>(
      page: page,
      beginOffset: beginOffset,
    );
    return replace
        ? Navigator.of(context).pushReplacement(route)
        : Navigator.of(context).push(route);
  }

  /// Navigate and clear stack (for login/logout)
  static Future<T?> navigateAndClearStack<T>(
    BuildContext context,
    Widget page,
  ) {
    return Navigator.of(context).pushAndRemoveUntil(
      AppAnimations.fadeTransition<T>(page: page),
      (route) => false,
    );
  }

  /// Pop with custom animation
  static void popWithAnimation(BuildContext context, [dynamic result]) {
    Navigator.of(context).pop(result);
  }

  /// Show bottom sheet with slide animation
  static Future<T?> showAnimatedBottomSheet<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    double? elevation,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: elevation,
      isScrollControlled: true,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: AppAnimations.mediumSlow,
      ),
      builder: (context) => child,
    );
  }

  /// Show dialog with fade animation
  static Future<T?> showAnimatedDialog<T>(
    BuildContext context, {
    required Widget child,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrierColor ?? Colors.black54,
      transitionDuration: AppAnimations.medium,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
