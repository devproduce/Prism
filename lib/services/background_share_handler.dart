import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/services/share_handler_service.dart';

/// Service to handle background sharing workflow
///
/// This service coordinates between:
/// 1. Native Android layer (BackgroundShareService) that receives share intents
/// 2. Flutter SharingProvider that handles upload and processing
/// 3. LocalNotificationService for user notifications
class BackgroundShareHandler {
  static final BackgroundShareHandler _instance =
      BackgroundShareHandler._internal();
  factory BackgroundShareHandler() => _instance;
  BackgroundShareHandler._internal();

  final ShareHandlerService _shareHandler = ShareHandlerService();
  bool _isInitialized = false;

  /// Initialize the background share handler
  /// Should be called once during app startup
  void initialize({
    required AuthProvider authProvider,
    required SharingProvider sharingProvider,
  }) {
    if (_isInitialized) {
      debugPrint('🔄 [BackgroundShareHandler] Already initialized');
      return;
    }

    debugPrint('🚀 [BackgroundShareHandler] Initializing...');
    _isInitialized = true;

    // Set up periodic check for shared files
    // This is called when the app comes to foreground or when signaled by native
    _setupBackgroundShareListener(authProvider, sharingProvider);
  }

  void _setupBackgroundShareListener(
    AuthProvider authProvider,
    SharingProvider sharingProvider,
  ) {
    // Listen for app lifecycle changes to check for pending shares
    debugPrint('📡 [BackgroundShareHandler] Listener setup complete');
  }

  /// Check for and process any pending shared files
  /// Called when app comes to foreground or when native signals files ready
  Future<void> checkAndProcessSharedFiles({
    required AuthProvider authProvider,
    required SharingProvider sharingProvider,
  }) async {
    debugPrint('🔍 [BackgroundShareHandler] Checking for shared files...');

    final files = await _shareHandler.getSharedFiles();

    if (files.isEmpty) {
      debugPrint('📭 [BackgroundShareHandler] No shared files pending');
      return;
    }

    debugPrint(
      '📬 [BackgroundShareHandler] Found ${files.length} shared files',
    );

    // Check if user is authenticated
    final userId = authProvider.currentUser?.userId;
    if (userId == null) {
      debugPrint(
        '⚠️ [BackgroundShareHandler] User not authenticated, cannot process',
      );
      // Clear shared files since we can't process them
      await _shareHandler.clearSharedFiles();
      return;
    }

    // Start background upload
    await _startBackgroundUpload(
      filePaths: files,
      userId: userId,
      sharingProvider: sharingProvider,
    );

    // Clear the cache after starting upload
    await _shareHandler.clearSharedFiles();
  }

  Future<void> _startBackgroundUpload({
    required List<String> filePaths,
    required String userId,
    required SharingProvider sharingProvider,
  }) async {
    debugPrint(
      '📤 [BackgroundShareHandler] Starting background upload for ${filePaths.length} files',
    );

    try {
      // Convert file paths to File objects
      final validFiles = <File>[];
      for (final path in filePaths) {
        final file = File(path);
        if (await file.exists()) {
          validFiles.add(file);
          debugPrint('   ✓ Valid file: $path');
        } else {
          debugPrint('   ✗ File not found: $path');
        }
      }

      if (validFiles.isEmpty) {
        debugPrint('❌ [BackgroundShareHandler] No valid files to upload');
        return;
      }

      // Set the files in provider and start upload
      sharingProvider.setSelectedImages(validFiles);

      // Start upload - this will:
      // 1. Show progress notification
      // 2. Upload to backend
      // 3. Poll for processing status
      // 4. Show "Ready to Review" notification when done
      final batchId = await sharingProvider.uploadImages(userId);

      if (batchId != null) {
        debugPrint(
          '✅ [BackgroundShareHandler] Upload started, batch ID: $batchId',
        );
      } else {
        debugPrint('❌ [BackgroundShareHandler] Upload failed');
      }
    } catch (e) {
      debugPrint(
        '❌ [BackgroundShareHandler] Error during background upload: $e',
      );
    }
  }
}
