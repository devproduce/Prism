import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

/// Centralized error handling utility for the Prism app.
/// Provides consistent error messaging and UI feedback across all screens.
class ErrorHandler {
  /// Handles API and network errors with appropriate messaging
  static String getErrorMessage(dynamic error) {
    if (error == null) {
      return 'An unexpected error occurred';
    }

    final errorString = error.toString().toLowerCase();

    // Network errors
    if (error is SocketException || errorString.contains('socketexception')) {
      return 'No internet connection. Please check your network.';
    }

    if (error is TimeoutException || errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (errorString.contains('handshakeexception') ||
        errorString.contains('certificate')) {
      return 'Secure connection failed. Please try again.';
    }

    // HTTP status codes
    if (errorString.contains('400') || errorString.contains('bad request')) {
      return 'Invalid request. Please check your input.';
    }

    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return 'Session expired. Please log in again.';
    }

    if (errorString.contains('403') || errorString.contains('forbidden')) {
      return 'Access denied. You don\'t have permission.';
    }

    if (errorString.contains('404') || errorString.contains('not found')) {
      return 'Resource not found.';
    }

    if (errorString.contains('409') || errorString.contains('conflict')) {
      return 'This action conflicts with existing data.';
    }

    if (errorString.contains('429') ||
        errorString.contains('too many requests')) {
      return 'Too many requests. Please wait a moment.';
    }

    if (errorString.contains('500') ||
        errorString.contains('internal server error')) {
      return 'Server error. Please try again later.';
    }

    if (errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504')) {
      return 'Server is temporarily unavailable. Please try again.';
    }

    // Format errors
    if (error is FormatException || errorString.contains('formatexception')) {
      return 'Invalid data received from server.';
    }

    // Platform/Permission errors
    if (error is PlatformException) {
      return _handlePlatformException(error);
    }

    if (errorString.contains('permission')) {
      return 'Permission required for this action.';
    }

    // File errors
    if (error is FileSystemException ||
        errorString.contains('filesystemexception')) {
      return 'File operation failed. Please try again.';
    }

    // Generic fallback - try to extract meaningful message
    if (errorString.length < 100) {
      // If error message is reasonably short, show it
      return error.toString();
    }

    return 'An error occurred. Please try again.';
  }

  /// Handles platform-specific exceptions
  static String _handlePlatformException(PlatformException e) {
    switch (e.code) {
      case 'photo_access_denied':
      case 'PERMISSION_DENIED':
        return 'Photo access denied. Please enable in Settings.';
      case 'camera_access_denied':
        return 'Camera access denied. Please enable in Settings.';
      case 'microphone_access_denied':
        return 'Microphone access denied. Please enable in Settings.';
      case 'storage_access_denied':
        return 'Storage access denied. Please enable in Settings.';
      case 'user_canceled':
      case 'cancelled':
        return ''; // Empty for user cancellation (not an error)
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  /// Shows an error snackbar with optional retry action
  static void showErrorSnackbar(
    BuildContext context, {
    required String message,
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (message.isEmpty) return; // Don't show for empty messages (user cancel)

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: PrismColors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: PrismTextStyles.bodyMedium.copyWith(
                  color: PrismColors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: PrismColors.destructiveRed.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
        action: onRetry != null
            ? SnackBarAction(
                label: 'RETRY',
                textColor: PrismColors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Shows an error dialog with optional retry action
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
    String retryText = 'Retry',
    String dismissText = 'OK',
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: PrismColors.surfaceGray,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PrismColors.destructiveRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: PrismColors.destructiveRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: PrismTextStyles.h2.copyWith(color: PrismColors.white),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: PrismTextStyles.bodyMedium.copyWith(
            color: PrismColors.secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              dismissText,
              style: PrismTextStyles.button.copyWith(
                color: PrismColors.secondaryText,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onRetry();
              },
              child: Text(
                retryText,
                style: PrismTextStyles.button.copyWith(
                  color: PrismColors.prismYellow,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog for destructive actions
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: PrismColors.surfaceGray,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    (isDestructive
                            ? PrismColors.destructiveRed
                            : PrismColors.prismYellow)
                        .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isDestructive
                    ? Icons.warning_amber_rounded
                    : Icons.help_outline_rounded,
                color: isDestructive
                    ? PrismColors.destructiveRed
                    : PrismColors.prismYellow,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: PrismTextStyles.h2.copyWith(color: PrismColors.white),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: PrismTextStyles.bodyMedium.copyWith(
            color: PrismColors.secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              cancelText,
              style: PrismTextStyles.button.copyWith(
                color: PrismColors.secondaryText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmText,
              style: PrismTextStyles.button.copyWith(
                color: isDestructive
                    ? PrismColors.destructiveRed
                    : PrismColors.prismYellow,
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Shows success snackbar
  static void showSuccessSnackbar(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: PrismColors.successGreen,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: PrismTextStyles.bodyMedium.copyWith(
                  color: PrismColors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: PrismColors.surfaceGray,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  /// Shows info snackbar
  static void showInfoSnackbar(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: PrismColors.electricCyan,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: PrismTextStyles.bodyMedium.copyWith(
                  color: PrismColors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: PrismColors.surfaceGray,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  /// Shows a loading dialog that can be dismissed programmatically
  static void showLoadingDialog(
    BuildContext context, {
    String message = 'Loading...',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: PrismColors.surfaceGray,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    PrismColors.prismYellow,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  message,
                  style: PrismTextStyles.bodyMedium.copyWith(
                    color: PrismColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hides the loading dialog
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Wraps an async operation with error handling
  static Future<T?> runSafe<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? errorTitle,
    VoidCallback? onRetry,
    bool showErrorSnackbar = true,
  }) async {
    try {
      return await operation();
    } catch (e) {
      if (context.mounted) {
        final message = getErrorMessage(e);
        if (message.isNotEmpty) {
          if (showErrorSnackbar) {
            ErrorHandler.showErrorSnackbar(
              context,
              message: message,
              onRetry: onRetry,
            );
          } else {
            await ErrorHandler.showErrorDialog(
              context,
              title: errorTitle ?? 'Error',
              message: message,
              onRetry: onRetry,
            );
          }
        }
      }
      return null;
    }
  }
}

/// A wrapper widget that handles errors in its child
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;

  const ErrorBoundary({super.key, required this.child, this.errorBuilder});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
  }

  void _resetError() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(_error!, _stackTrace) ??
          _buildDefaultErrorWidget();
    }

    return widget.child;
  }

  Widget _buildDefaultErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PrismColors.destructiveRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: PrismColors.destructiveRed,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: PrismTextStyles.h2.copyWith(color: PrismColors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'An unexpected error occurred. Please try again.',
              textAlign: TextAlign.center,
              style: PrismTextStyles.bodyMedium.copyWith(
                color: PrismColors.secondaryText,
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _resetError,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: TextButton.styleFrom(
                foregroundColor: PrismColors.prismYellow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
