import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:prism/services/database_service.dart';
import 'package:prism/services/share_handler_service.dart';

/// Service to handle automatic saving of received media to device gallery
/// Saves images/videos to a "Prism" album with comprehensive error handling
/// Now with LOCAL-FIRST checking to avoid re-downloading existing images
class GallerySaveService {
  static final GallerySaveService _instance = GallerySaveService._internal();
  factory GallerySaveService() => _instance;
  GallerySaveService._internal();

  final DatabaseService _db = DatabaseService.instance;
  final ShareHandlerService _shareHandler = ShareHandlerService();

  bool _isProcessing = false;
  final List<String> _processingQueue = [];

  /// Auto-save preference (can be persisted to shared preferences)
  bool autoSaveEnabled = true;

  /// Cached set of local image IDs for fast lookup
  /// This is populated on first check and refreshed when needed
  Set<String>? _localImageIdsCache;

  /// Flag to track if we've initialized (rebuilt tracking from local files)
  bool _hasInitialized = false;

  /// Save a received image to the device gallery
  /// Returns true if saved successfully, false otherwise
  Future<bool> saveImageToGallery({
    required String imageId,
    required String imageUrl,
    String albumName = 'Prism',
  }) async {
    try {
      // Check if already saved
      if (await _db.isImageSavedToGallery(imageId)) {
        debugPrint(
          '📱 [GallerySaveService] Image $imageId already saved to gallery',
        );
        return true;
      }

      // Check if URL is valid
      if (imageUrl.isEmpty) {
        debugPrint('⚠️ [GallerySaveService] Empty URL for image $imageId');
        return false;
      }

      debugPrint('📱 [GallerySaveService] Downloading image: $imageId');
      debugPrint(
        '   URL: ${imageUrl.substring(0, imageUrl.length > 100 ? 100 : imageUrl.length)}...',
      );

      // Download the image to temp storage
      final tempPath = await _downloadFile(imageUrl, imageId);
      if (tempPath == null) {
        debugPrint('❌ [GallerySaveService] Failed to download image $imageId');
        return false;
      }

      debugPrint('📱 [GallerySaveService] Downloaded to: $tempPath');

      // Save to gallery
      final saved = await _shareHandler.saveImageToGallery(
        tempPath,
        albumName: albumName,
      );

      if (saved) {
        // Mark as saved in database
        await _db.markImageAsSavedToGallery(imageId, 'Pictures/$albumName');
        debugPrint('✅ [GallerySaveService] Image $imageId saved to gallery');

        // Clean up temp file
        try {
          final tempFile = File(tempPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          // Ignore cleanup errors
        }

        return true;
      } else {
        debugPrint(
          '❌ [GallerySaveService] Failed to save image $imageId to gallery',
        );
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [GallerySaveService] Error saving image $imageId: $e');
      debugPrint('   Stack trace: $stackTrace');
      return false;
    }
  }

  /// Download file from URL to temporary storage
  Future<String?> _downloadFile(String url, String imageId) async {
    try {
      // Get temp directory
      final tempDir = await getTemporaryDirectory();
      final downloadDir = Directory('${tempDir.path}/prism_downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // Determine file extension from URL
      String extension = '.jpg';
      final urlPath = url.split('?').first; // Remove query params
      if (urlPath.contains('.')) {
        final ext = urlPath.split('.').last.toLowerCase();
        if ([
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'mp4',
          'mov',
          'avi',
        ].contains(ext)) {
          extension = '.$ext';
        }
      }

      final filePath = '${downloadDir.path}/${imageId}$extension';
      final file = File(filePath);

      // Download with timeout
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception('Download timeout');
            },
          );

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      } else {
        debugPrint(
          '❌ [GallerySaveService] HTTP ${response.statusCode} for $imageId',
        );
        return null;
      }
    } catch (e) {
      debugPrint('❌ [GallerySaveService] Download error: $e');
      return null;
    }
  }

  /// Process a batch of images for auto-save
  /// NOW uses LOCAL-FIRST checking to avoid re-downloading existing images
  /// Handles images one at a time to avoid overwhelming the device
  Future<void> processImagesForAutoSave(
    List<Map<String, String>> images,
  ) async {
    if (!autoSaveEnabled) {
      debugPrint('📱 [GallerySaveService] Auto-save disabled, skipping');
      return;
    }

    if (_isProcessing) {
      debugPrint('📱 [GallerySaveService] Already processing, adding to queue');
      for (final img in images) {
        if (img['id'] != null && !_processingQueue.contains(img['id'])) {
          _processingQueue.add(img['id']!);
        }
      }
      return;
    }

    _isProcessing = true;

    try {
      // Initialize if needed (rebuilds tracking from local files on reinstall)
      await initializeIfNeeded();

      // LOCAL-FIRST: Filter out images that already exist locally
      final imagesToDownload = await filterImagesToDownload(images);

      int savedCount = 0;
      int skippedLocal = images.length - imagesToDownload.length;
      int skippedDb = 0;
      int failedCount = 0;

      debugPrint(
        '📱 [GallerySaveService] Starting batch: ${imagesToDownload.length} to download, $skippedLocal already local',
      );

      for (final image in imagesToDownload) {
        final id = image['id'];
        final url = image['url'];

        if (id == null || url == null || url.isEmpty) {
          skippedDb++;
          continue;
        }

        // Double-check DB (belt and suspenders)
        if (await _db.isImageSavedToGallery(id)) {
          skippedDb++;
          continue;
        }

        final success = await saveImageToGallery(imageId: id, imageUrl: url);

        if (success) {
          savedCount++;
          // Update cache with new image
          _localImageIdsCache?.add(id);
        } else {
          failedCount++;
        }

        // Small delay between downloads to be nice to the server
        await Future.delayed(const Duration(milliseconds: 200));
      }

      debugPrint(
        '📱 [GallerySaveService] Batch complete: $savedCount saved, $skippedLocal skipped (local), $skippedDb skipped (db), $failedCount failed',
      );

      // Process any queued items
      if (_processingQueue.isNotEmpty) {
        final queuedIds = List<String>.from(_processingQueue);
        _processingQueue.clear();
        _isProcessing = false;

        // Re-process queued items (need to fetch URLs separately)
        debugPrint(
          '📱 [GallerySaveService] Processing ${queuedIds.length} queued items',
        );
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Check if storage permission is available
  Future<bool> checkStoragePermission() async {
    return await _shareHandler.checkStoragePermission();
  }

  /// Request storage permission
  Future<bool> requestStoragePermission() async {
    return await _shareHandler.requestStoragePermission();
  }

  /// Clear all gallery save records (for debugging/reset)
  Future<void> clearSaveRecords() async {
    await _db.clearGallerySaves();
    _localImageIdsCache = null;
    _hasInitialized = false;
    debugPrint('📱 [GallerySaveService] Cleared all save records');
  }

  // ==================== LOCAL-FIRST CHECKING METHODS ====================

  /// Initialize the service - rebuilds tracking from local files if needed
  /// Should be called on app start, especially after reinstall
  Future<void> initializeIfNeeded() async {
    if (_hasInitialized) {
      debugPrint('📱 [GallerySaveService] Already initialized');
      return;
    }

    try {
      debugPrint('📱 [GallerySaveService] Initializing...');

      // Check if we have any tracking records
      final isDbEmpty = await _db.isGallerySavesEmpty();

      // Get local image IDs
      final localImageIds = await _shareHandler.getLocalImageIds();
      _localImageIdsCache = localImageIds;

      // If DB is empty but we have local images, rebuild tracking
      if (isDbEmpty && localImageIds.isNotEmpty) {
        debugPrint(
          '📱 [GallerySaveService] DB empty but found ${localImageIds.length} local images - rebuilding tracking',
        );
        await rebuildSaveRecordsFromLocal();
      } else if (!isDbEmpty) {
        debugPrint(
          '📱 [GallerySaveService] Found existing DB records, checking for orphaned local files',
        );
        // Sync any local files that aren't in DB (could happen if save failed to record)
        final dbImageIds = await _db.getAllSavedImageIds();
        final missingFromDb = localImageIds.difference(dbImageIds);

        if (missingFromDb.isNotEmpty) {
          debugPrint(
            '📱 [GallerySaveService] Found ${missingFromDb.length} local files not in DB - adding',
          );
          final toAdd = missingFromDb
              .map((id) => {'imageId': id, 'galleryPath': 'Pictures/Prism'})
              .toList();
          await _db.batchMarkImagesAsSaved(toAdd);
        }
      }

      _hasInitialized = true;
      debugPrint('📱 [GallerySaveService] Initialization complete');
    } catch (e, stackTrace) {
      debugPrint('❌ [GallerySaveService] Error during initialization: $e');
      debugPrint('   Stack trace: $stackTrace');
      // Even on error, mark as initialized to prevent repeated failures
      _hasInitialized = true;
    }
  }

  /// Check if an image exists in the local Prism folder
  /// Checks actual files, not just database records
  Future<bool> isImagePresentLocally(String imageId) async {
    try {
      // Use cache if available
      if (_localImageIdsCache != null) {
        return _localImageIdsCache!.contains(imageId);
      }

      // Otherwise fetch fresh
      final localImageIds = await _shareHandler.getLocalImageIds();
      _localImageIdsCache = localImageIds;
      return localImageIds.contains(imageId);
    } catch (e) {
      debugPrint('⚠️ [GallerySaveService] Error checking local presence: $e');
      // Fall back to DB check on error
      return await _db.isImageSavedToGallery(imageId);
    }
  }

  /// Rebuild save records from local Prism folder
  /// Called on first launch after reinstall when DB is empty but local files exist
  Future<void> rebuildSaveRecordsFromLocal() async {
    try {
      debugPrint(
        '📱 [GallerySaveService] Rebuilding save records from local files...',
      );

      final localImageIds = await _shareHandler.getLocalImageIds();

      if (localImageIds.isEmpty) {
        debugPrint('📱 [GallerySaveService] No local images found');
        return;
      }

      // Batch insert all local images into tracking DB
      final imagesToAdd = localImageIds
          .map((id) => {'imageId': id, 'galleryPath': 'Pictures/Prism'})
          .toList();

      await _db.batchMarkImagesAsSaved(imagesToAdd);
      _localImageIdsCache = localImageIds;

      debugPrint(
        '✅ [GallerySaveService] Rebuilt tracking for ${localImageIds.length} local images',
      );
    } catch (e) {
      debugPrint('❌ [GallerySaveService] Error rebuilding save records: $e');
    }
  }

  /// Refresh the local image ID cache
  /// Call this after saving new images to update the cache
  Future<void> refreshLocalImageCache() async {
    try {
      _localImageIdsCache = await _shareHandler.getLocalImageIds();
      debugPrint(
        '📱 [GallerySaveService] Refreshed local cache: ${_localImageIdsCache?.length ?? 0} images',
      );
    } catch (e) {
      debugPrint('⚠️ [GallerySaveService] Error refreshing local cache: $e');
    }
  }

  /// Get images that need to be downloaded (not present locally)
  /// Filters a list of backend images to only those missing locally
  Future<List<Map<String, String>>> filterImagesToDownload(
    List<Map<String, String>> images,
  ) async {
    // Ensure we have fresh local image IDs
    if (_localImageIdsCache == null) {
      await refreshLocalImageCache();
    }

    final localIds = _localImageIdsCache ?? {};
    final toDownload = <Map<String, String>>[];

    for (final image in images) {
      final id = image['id'];
      if (id != null && !localIds.contains(id)) {
        toDownload.add(image);
      }
    }

    debugPrint(
      '📱 [GallerySaveService] Filter result: ${toDownload.length} to download out of ${images.length} total',
    );

    return toDownload;
  }
}
