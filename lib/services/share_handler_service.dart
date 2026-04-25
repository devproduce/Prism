import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service to handle sharing functionality between Flutter and native Android code
/// Manages share intents from other apps and saving images to device gallery
class ShareHandlerService {
  static const MethodChannel _channel = MethodChannel(
    'in.prismapp.prism/share_handler',
  );

  // Callback for immediate deep link notifications from native
  void Function(String route, String batchId, bool isProcessing)?
  _onDeepLinkReceived;

  /// Setup listener for immediate deep link notifications from native.
  /// This is called when the user taps a notification and native wants
  /// to notify Flutter immediately (without waiting for lifecycle events).
  void setupDeepLinkListener(
    void Function(String route, String batchId, bool isProcessing) onDeepLink,
  ) {
    _onDeepLinkReceived = onDeepLink;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLinkReceived') {
        final args = call.arguments as Map<Object?, Object?>;
        final route = args['route'] as String?;
        final batchId = args['batchId'] as String?;
        final isProcessing = args['isProcessing'] as bool? ?? false;

        debugPrint(
          '📱 [ShareHandlerService] Deep link received: route=$route, batchId=$batchId, isProcessing=$isProcessing',
        );

        if (route != null && batchId != null && _onDeepLinkReceived != null) {
          _onDeepLinkReceived!(route, batchId, isProcessing);
        }
      }
    });
  }

  /// Get list of files shared from other apps
  /// Returns list of absolute file paths
  /// After reading, the shared files list is cleared on native side
  Future<List<String>> getSharedFiles() async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod(
        'getSharedFiles',
      );
      return result?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      print('Error getting shared files: ${e.message}');
      return [];
    }
  }

  /// Save an image to device gallery
  /// [imagePath] - Absolute path to the image file
  /// [albumName] - Name of the album to save to (default: "Prism")
  /// Returns true if saved successfully, false otherwise
  Future<bool> saveImageToGallery(
    String imagePath, {
    String albumName = 'Prism',
  }) async {
    try {
      final bool? result = await _channel.invokeMethod('saveImageToGallery', {
        'imagePath': imagePath,
        'albumName': albumName,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error saving image to gallery: ${e.message}');
      return false;
    }
  }

  /// Check if storage permission is granted
  /// On Android 10+, this always returns true (scoped storage)
  /// On Android 9 and below, checks WRITE_EXTERNAL_STORAGE permission
  Future<bool> checkStoragePermission() async {
    try {
      final bool? result = await _channel.invokeMethod(
        'checkStoragePermission',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error checking storage permission: ${e.message}');
      return false;
    }
  }

  /// Request storage permission from user
  /// Shows system permission dialog
  /// Returns true if granted, false if denied
  Future<bool> requestStoragePermission() async {
    try {
      final bool? result = await _channel.invokeMethod(
        'requestStoragePermission',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error requesting storage permission: ${e.message}');
      return false;
    }
  }

  /// Clear cached shared files from app storage
  /// Should be called after processing shared files
  Future<void> clearSharedFiles() async {
    try {
      await _channel.invokeMethod('clearSharedFiles');
    } on PlatformException catch (e) {
      print('Error clearing shared files: ${e.message}');
    }
  }

  /// Get all images from the local Prism album
  /// Returns list of local image data with paths, filenames, dates
  Future<List<Map<String, dynamic>>> getLocalAlbumImages({
    String albumName = 'Prism',
  }) async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod(
        'getAlbumImages',
        {'albumName': albumName},
      );
      if (result == null) return [];

      return result.map((item) {
        final Map<dynamic, dynamic> map = item as Map<dynamic, dynamic>;
        return map.cast<String, dynamic>();
      }).toList();
    } on PlatformException catch (e) {
      print('Error getting album images: ${e.message}');
      return [];
    }
  }

  /// Get all image IDs (filenames without extension) from the local Prism album
  /// Returns a Set for efficient O(1) lookup when checking if an image exists locally
  /// This is optimized for checking which images need to be downloaded
  Future<Set<String>> getLocalImageIds({String albumName = 'Prism'}) async {
    try {
      final List<dynamic>? result = await _channel
          .invokeMethod('getLocalImageIds', {'albumName': albumName})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('⚠️ [ShareHandlerService] getLocalImageIds timeout');
              return null;
            },
          );

      if (result == null) return {};

      return result.cast<String>().toSet();
    } on PlatformException catch (e) {
      debugPrint('Error getting local image IDs: ${e.message}');
      return {};
    } catch (e) {
      debugPrint('Unexpected error getting local image IDs: $e');
      return {};
    }
  }

  /// Delete an image from the device gallery by file path
  /// Returns true if deleted successfully
  Future<bool> deleteFromGallery(String filePath) async {
    try {
      final bool? result = await _channel.invokeMethod('deleteGalleryImage', {
        'filePath': filePath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error deleting from gallery: ${e.message}');
      return false;
    }
  }

  /// Delete an image from the device gallery by MediaStore ID
  /// Returns true if deleted successfully
  Future<bool> deleteFromGalleryById(int imageId) async {
    try {
      final bool? result = await _channel.invokeMethod(
        'deleteGalleryImageById',
        {'imageId': imageId},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error deleting from gallery by ID: ${e.message}');
      return false;
    }
  }

  /// Get pending deep link from notification tap
  /// Returns null if no pending deep link
  /// Returns Map with 'route', 'batchId', and 'isProcessing' keys if available
  /// Used when app is opened from "Ready to Review" notification
  Future<Map<String, String>?> getPendingDeepLink() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod(
        'getPendingDeepLink',
      );
      if (result == null) return null;
      return result.cast<String, String>();
    } on PlatformException catch (e) {
      print('Error getting pending deep link: ${e.message}');
      return null;
    }
  }

  /// Get current processing state from native.
  /// Returns null if not processing, or map with 'batchId' and 'isProcessing' if processing is ongoing.
  /// Used for cold start scenarios where we need to know if background processing is happening.
  Future<Map<String, dynamic>?> getProcessingState() async {
    try {
      final result = await _channel.invokeMethod('getProcessingState');
      if (result == null) return null;
      return (result as Map<Object?, Object?>).cast<String, dynamic>();
    } on PlatformException catch (e) {
      print('Error getting processing state: ${e.message}');
      return null;
    }
  }
}
