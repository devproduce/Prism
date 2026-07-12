import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/gallery_image_model.dart';
import 'package:prism/services/database_service.dart';
import 'package:prism/services/gallery_save_service.dart';
import 'package:prism/services/share_handler_service.dart';

class GalleryProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final DatabaseService _databaseService = DatabaseService.instance;
  final GallerySaveService _gallerySaveService = GallerySaveService();
  final ShareHandlerService _shareHandler = ShareHandlerService();

  List<GalleryImage> _images = [];
  Map<String, List<GalleryImage>> _groupedImages = {};
  bool _isLoading = false;
  String? _error;
  bool _isLoadingFromCache = false;

  // Getters
  List<GalleryImage> get images => _images;
  Map<String, List<GalleryImage>> get groupedImages => _groupedImages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoadingFromCache => _isLoadingFromCache;

  // Filtered getters - exclude bin images from all sections except Bin
  List<GalleryImage> get allImages => _images
      .where((img) => !img.galleryMeta.bin && !img.galleryMeta.archive)
      .toList();
  List<GalleryImage> get favouriteImages => _images
      .where((img) => img.galleryMeta.favourite && !img.galleryMeta.bin)
      .toList();
  List<GalleryImage> get archivedImages => _images
      .where((img) => img.galleryMeta.archive && !img.galleryMeta.bin)
      .toList();
  List<GalleryImage> get binImages =>
      _images.where((img) => img.galleryMeta.bin).toList();

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Future<bool> _ensureAuthenticated() async {
    if (!await _apiClient.ensureAuthenticated()) {
      _setError('Your session has expired. Please log in again.');
      return false;
    }
    return true;
  }

  /// Fetch gallery images with caching
  Future<void> fetchGallery({
    required String userId,
    bool forceRefresh = false,
  }) async {
    if (!await _ensureAuthenticated()) return;

    try {
      // Always use cache first unless forcing refresh
      if (!forceRefresh) {
        debugPrint('Checking cache for user: $userId');
        final cachedData = await _databaseService.getGalleryCache(userId);
        if (cachedData != null && cachedData.isNotEmpty) {
          debugPrint('Loading from cache...');
          _isLoadingFromCache = true;
          notifyListeners();

          try {
            final List<dynamic> jsonList = json.decode(cachedData);
            _images = [];
            bool hasExpiredUrls = false;

            for (var i = 0; i < jsonList.length; i++) {
              try {
                final galleryImage = GalleryImage.fromJson(
                  jsonList[i] as Map<String, dynamic>,
                );
                _images.add(galleryImage);

                // Check if any URL is expired
                if (!hasExpiredUrls && galleryImage.image.isUrlExpired) {
                  hasExpiredUrls = true;
                }
              } catch (e) {
                debugPrint('Error parsing cached image at index $i: $e');
              }
            }

            // If we found expired URLs, clear cache and fetch fresh
            if (hasExpiredUrls) {
              debugPrint(
                'Detected expired URLs in cache, fetching fresh data...',
              );
              await _databaseService.clearGalleryCache(userId);
              _isLoadingFromCache = false;
              // Fall through to fetch from API
            } else {
              _groupImagesByMonth();
              _isLoadingFromCache = false;
              _setError(null);
              notifyListeners();
              debugPrint('Loaded ${_images.length} images from cache');
              return;
            }
          } catch (e) {
            debugPrint('Error parsing cached data: $e');
            // Clear invalid cache and fetch fresh
            await _databaseService.clearGalleryCache(userId);
          }
        } else {
          debugPrint('No cache found, fetching from API');
        }
      } else {
        debugPrint('Force refresh requested');
      }

      // Fetch from API
      _setLoading(true);
      _setError(null);

      final data = await _apiClient.getGallery();

      debugPrint('Gallery API Response: ${data.length} items received');
      if (data.isNotEmpty) {
        debugPrint('First item: ${data[0]}');
      }

      _images = [];
      for (var i = 0; i < data.length; i++) {
        try {
          final galleryImage = GalleryImage.fromJson(
            data[i] as Map<String, dynamic>,
          );
          _images.add(galleryImage);
        } catch (e) {
          debugPrint('Error parsing image at index $i: $e');
          debugPrint('Item data: ${data[i]}');
          // Continue with other images
        }
      }

      debugPrint(
        'Successfully parsed ${_images.length} out of ${data.length} images',
      );

      // Cache the response
      await _databaseService.saveGalleryCache(userId, json.encode(data));

      _groupImagesByMonth();
      _setLoading(false);

      // Trigger auto-save to gallery in background
      _triggerAutoSave();
    } on ApiException catch (e) {
      debugPrint('API Exception: ${e.message}');
      // Try to load from cache on error
      final cachedData = await _databaseService.getGalleryCache(userId);
      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        _images = jsonList.map((json) => GalleryImage.fromJson(json)).toList();
        _groupImagesByMonth();
        _setError('Showing cached data. ${e.message}');
      } else {
        _setError(e.message);
      }
      _setLoading(false);
    } catch (e, stackTrace) {
      debugPrint('Error fetching gallery: $e');
      debugPrint('Stack trace: $stackTrace');
      _setError('Failed to load gallery: ${e.toString()}');
      _setLoading(false);
    }
  }

  /// Group images by month
  void _groupImagesByMonth() {
    _groupedImages.clear();

    for (var image in _images) {
      // Skip images in the bin
      if (image.galleryMeta.bin) continue;

      if (image.image.takenAt != null) {
        final monthYear = _getMonthYearKey(image.image.takenAt!);
        if (!_groupedImages.containsKey(monthYear)) {
          _groupedImages[monthYear] = [];
        }
        _groupedImages[monthYear]!.add(image);
      } else {
        // Images without date go to "Unknown" group
        if (!_groupedImages.containsKey('Unknown')) {
          _groupedImages['Unknown'] = [];
        }
        _groupedImages['Unknown']!.add(image);
      }
    }

    // Sort groups by date (most recent first)
    final sortedKeys = _groupedImages.keys.toList()
      ..sort((a, b) {
        if (a == 'Unknown') return 1;
        if (b == 'Unknown') return -1;
        return b.compareTo(a);
      });

    final sorted = <String, List<GalleryImage>>{};
    for (var key in sortedKeys) {
      sorted[key] = _groupedImages[key]!;
    }
    _groupedImages = sorted;
  }

  /// Get month and year key for grouping
  String _getMonthYearKey(DateTime date) {
    final months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return months[date.month - 1];
  }

  /// Toggle image status (favourite, archive, bin)
  Future<void> toggleImageStatus({
    required String imageId,
    required String userId,
    required String field,
  }) async {
    if (!await _ensureAuthenticated()) return;

    try {
      final newValue = await _apiClient.toggleImageStatus(
        imageId: imageId,
        field: field,
      );

      // Update local state
      final index = _images.indexWhere((img) => img.image.id == imageId);
      if (index != -1) {
        final currentMeta = _images[index].galleryMeta;
        debugPrint(
          '📝 Before update - $field: ${field == 'favourite'
              ? currentMeta.favourite
              : field == 'archive'
              ? currentMeta.archive
              : currentMeta.bin}',
        );

        _images[index] = GalleryImage(
          image: _images[index].image,
          faces: _images[index].faces,
          galleryMeta: GalleryMeta(
            favourite: field == 'favourite' ? newValue : currentMeta.favourite,
            archive: field == 'archive' ? newValue : currentMeta.archive,
            bin: field == 'bin' ? newValue : currentMeta.bin,
          ),
        );

        debugPrint('✅ After update - $field: $newValue');
        debugPrint(
          '📊 Total images: ${_images.length}, Bin images: ${_images.where((img) => img.galleryMeta.bin).length}, Gallery images: ${_images.where((img) => !img.galleryMeta.bin).length}',
        );

        _groupImagesByMonth();

        // Notify listeners immediately with updated local state
        debugPrint('🔔 Notifying listeners...');
        notifyListeners();

        // Clear cache and refetch from backend to ensure long-term consistency
        debugPrint('🔄 Clearing cache after $field toggle for image $imageId');
        await _databaseService.clearGalleryCache(userId);

        // Fetch fresh data from backend (await to ensure it completes)
        await fetchGallery(userId: userId, forceRefresh: true);
      }
    } on ApiException catch (e) {
      _setError(e.message);
      rethrow;
    } catch (e) {
      _setError('Failed to update $field: ${e.toString()}');
      rethrow;
    }
  }

  /// Update image description
  Future<void> updateDescription({
    required String imageId,
    required String userId,
    required String description,
  }) async {
    if (!await _ensureAuthenticated()) return;

    try {
      await _apiClient.updateImageDescription(
        imageId: imageId,
        description: description,
      );

      // Update local state
      final index = _images.indexWhere((img) => img.image.id == imageId);
      if (index != -1) {
        final currentMetadata = _images[index].image.metadata ?? {};
        final updatedMetadata = Map<String, dynamic>.from(currentMetadata);
        updatedMetadata['description'] = description;

        _images[index] = GalleryImage(
          image: ImageData(
            id: _images[index].image.id,
            storagePath: _images[index].image.storagePath,
            imageUrl: _images[index].image.imageUrl,
            takenAt: _images[index].image.takenAt,
            width: _images[index].image.width,
            height: _images[index].image.height,
            metadata: updatedMetadata,
          ),
          faces: _images[index].faces,
          galleryMeta: _images[index].galleryMeta,
        );

        // Notify listeners immediately with updated local state
        notifyListeners();

        // Clear cache and refetch to ensure consistency
        debugPrint(
          '🔄 Clearing cache after description update for image $imageId',
        );
        await _databaseService.clearGalleryCache(userId);

        // Fetch fresh data from backend (await to ensure it completes)
        await fetchGallery(userId: userId, forceRefresh: true);
      }
    } on ApiException catch (e) {
      _setError(e.message);
      rethrow;
    } catch (e) {
      _setError('Failed to update description: ${e.toString()}');
      rethrow;
    }
  }

  /// Clear cache and force refresh from backend
  Future<void> clearCacheAndRefresh(String userId) async {
    try {
      debugPrint('🗑️ Clearing cache and refreshing from backend...');
      await _databaseService.clearGalleryCache(userId);
      await fetchGallery(userId: userId, forceRefresh: true);
      debugPrint('✅ Cache cleared and data refreshed');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
      rethrow;
    }
  }

  /// Batch update status for multiple images
  Future<void> batchUpdateStatus({
    required String userId,
    required List<String> imageIds,
    required String field,
    required bool value,
  }) async {
    if (!await _ensureAuthenticated()) return;

    try {
      await _apiClient.batchUpdateStatus(
        imageIds: imageIds,
        field: field,
        value: value,
      );

      // Update local state for all affected images
      for (var imageId in imageIds) {
        final index = _images.indexWhere((img) => img.image.id == imageId);
        if (index != -1) {
          final currentMeta = _images[index].galleryMeta;
          _images[index] = GalleryImage(
            image: _images[index].image,
            faces: _images[index].faces,
            galleryMeta: GalleryMeta(
              favourite: field == 'favourite' ? value : currentMeta.favourite,
              archive: field == 'archive' ? value : currentMeta.archive,
              bin: field == 'bin' ? value : currentMeta.bin,
            ),
          );
        }
      }

      _groupImagesByMonth();

      // Notify listeners immediately with updated local state
      notifyListeners();

      // Clear cache and refetch from backend to ensure consistency
      debugPrint('🔄 Clearing cache after batch $field update');
      await _databaseService.clearGalleryCache(userId);

      // Fetch fresh data from backend (await to ensure it completes)
      await fetchGallery(userId: userId, forceRefresh: true);
    } on ApiException catch (e) {
      _setError(e.message);
      rethrow;
    } catch (e) {
      _setError('Failed to batch update: ${e.toString()}');
      rethrow;
    }
  }

  /// Restore image from bin
  Future<void> restoreFromBin({
    required String imageId,
    required String userId,
  }) async {
    try {
      // Toggle bin to false (restore)
      await _apiClient.toggleImageStatus(
        imageId: imageId,
        field: 'bin',
      );

      // Update local state
      final index = _images.indexWhere((img) => img.image.id == imageId);
      if (index != -1) {
        final currentMeta = _images[index].galleryMeta;
        _images[index] = GalleryImage(
          image: _images[index].image,
          faces: _images[index].faces,
          galleryMeta: GalleryMeta(
            favourite: currentMeta.favourite,
            archive: currentMeta.archive,
            bin: false, // Restore from bin
          ),
        );
        _groupImagesByMonth();

        // Notify listeners immediately with updated local state
        notifyListeners();

        // Clear cache and refetch to ensure consistency
        debugPrint('🔄 Clearing cache after restoring image $imageId from bin');
        await _databaseService.clearGalleryCache(userId);

        // Fetch fresh data from backend (await to ensure it completes)
        await fetchGallery(userId: userId, forceRefresh: true);
      }
    } on ApiException catch (e) {
      _setError(e.message);
      rethrow;
    } catch (e) {
      _setError('Failed to restore image: ${e.toString()}');
      rethrow;
    }
  }

  /// Refresh gallery (force refresh from API)
  Future<void> refresh(String userId) async {
    await fetchGallery(userId: userId, forceRefresh: true);
  }

  /// Get images filtered by status for tabs
  Map<String, List<GalleryImage>> getGroupedImagesByTab(String tab) {
    List<GalleryImage> filteredImages;

    switch (tab) {
      case 'Favourites':
        filteredImages = favouriteImages;
        break;
      case 'Archived':
        filteredImages = archivedImages;
        break;
      case 'Bin':
        filteredImages = binImages;
        break;
      case 'All':
      default:
        filteredImages = allImages;
        break;
    }

    // Group filtered images by month
    final Map<String, List<GalleryImage>> grouped = {};
    for (var image in filteredImages) {
      if (image.image.takenAt != null) {
        final monthYear = _getMonthYearKey(image.image.takenAt!);
        if (!grouped.containsKey(monthYear)) {
          grouped[monthYear] = [];
        }
        grouped[monthYear]!.add(image);
      } else {
        if (!grouped.containsKey('Unknown')) {
          grouped['Unknown'] = [];
        }
        grouped['Unknown']!.add(image);
      }
    }

    // Sort by date
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'Unknown') return 1;
        if (b == 'Unknown') return -1;
        return b.compareTo(a);
      });

    final sorted = <String, List<GalleryImage>>{};
    for (var key in sortedKeys) {
      sorted[key] = grouped[key]!;
    }
    return sorted;
  }

  /// Clear cache manually
  Future<void> clearCache(String userId) async {
    await _databaseService.clearGalleryCache(userId);
  }

  /// Trigger auto-save of received images to device gallery
  /// Runs in background, doesn't block UI
  void _triggerAutoSave() {
    // Collect images that need to be saved
    final imagesToSave = <Map<String, String>>[];

    for (final image in _images) {
      // Only save images that are not in bin and have valid URLs
      if (!image.galleryMeta.bin &&
          image.image.imageUrl.isNotEmpty) {
        imagesToSave.add({'id': image.image.id, 'url': image.image.imageUrl});
      }
    }

    if (imagesToSave.isNotEmpty) {
      debugPrint(
        '📱 [GalleryProvider] Triggering auto-save for ${imagesToSave.length} images',
      );
      // Process in background - don't await
      _gallerySaveService.processImagesForAutoSave(imagesToSave);
    }
  }

  /// Enable or disable auto-save feature
  void setAutoSaveEnabled(bool enabled) {
    _gallerySaveService.autoSaveEnabled = enabled;
    debugPrint(
      '📱 [GalleryProvider] Auto-save ${enabled ? 'enabled' : 'disabled'}',
    );
    notifyListeners();
  }

  /// Check if auto-save is enabled
  bool get isAutoSaveEnabled => _gallerySaveService.autoSaveEnabled;

  // ==================== LOCAL-FIRST LOADING ====================

  /// Local album images cache
  List<Map<String, dynamic>> _localAlbumImages = [];

  /// Get images from local Prism album
  List<Map<String, dynamic>> get localAlbumImages => _localAlbumImages;

  /// Load images from local Prism album first, then sync with backend metadata
  /// This provides instant loading from local storage
  Future<void> fetchGalleryLocalFirst({
    required String userId,
    bool forceRefresh = false,
  }) async {
    try {
      debugPrint(
        '📱 [GalleryProvider] Loading from local Prism album first...',
      );

      // Step 1: Load from local album for instant display
      _localAlbumImages = await _shareHandler.getLocalAlbumImages();
      debugPrint(
        '📱 [GalleryProvider] Found ${_localAlbumImages.length} images in local album',
      );

      // Step 2: Load cached metadata (for favorites, archive status, etc.)
      if (!forceRefresh) {
        final cachedData = await _databaseService.getGalleryCache(userId);
        if (cachedData != null && cachedData.isNotEmpty) {
          _isLoadingFromCache = true;
          notifyListeners();

          try {
            final List<dynamic> jsonList = json.decode(cachedData);
            _images = [];
            bool hasExpiredUrls = false;

            for (var i = 0; i < jsonList.length; i++) {
              try {
                final galleryImage = GalleryImage.fromJson(
                  jsonList[i] as Map<String, dynamic>,
                );
                _images.add(galleryImage);

                // Check if any URL is expired
                if (!hasExpiredUrls && galleryImage.image.isUrlExpired) {
                  hasExpiredUrls = true;
                }
              } catch (e) {
                debugPrint('Error parsing cached image at index $i: $e');
              }
            }

            // If we found expired URLs or force refresh, continue to fetch from backend
            if (!hasExpiredUrls) {
              _groupImagesByMonth();
              _isLoadingFromCache = false;
              _setError(null);
              notifyListeners();
              debugPrint(
                '📱 [GalleryProvider] Using ${_images.length} images from cache with local files',
              );
              return;
            }
          } catch (e) {
            debugPrint('Error parsing cached data: $e');
            await _databaseService.clearGalleryCache(userId);
          }
        }
      }

      // Step 3: Fetch fresh data from backend and sync
      await _syncWithBackend(userId);
    } catch (e, stackTrace) {
      debugPrint('❌ [GalleryProvider] Error in local-first loading: $e');
      debugPrint('Stack trace: $stackTrace');
      _setError('Failed to load gallery: ${e.toString()}');
    }
  }

  /// Sync local album with backend data
  /// Downloads any new images and updates metadata
  Future<void> _syncWithBackend(String userId) async {
    if (!await _ensureAuthenticated()) return;

    debugPrint('🔄 [GalleryProvider] Syncing with backend...');
    _setLoading(true);
    _setError(null);

    try {
      final data = await _apiClient.getGallery();

      debugPrint(
        '📥 [GalleryProvider] Received ${data.length} images from backend',
      );

      _images = [];
      final Set<String> backendImageIds = {};

      for (var i = 0; i < data.length; i++) {
        try {
          final galleryImage = GalleryImage.fromJson(
            data[i] as Map<String, dynamic>,
          );
          _images.add(galleryImage);
          backendImageIds.add(galleryImage.image.id);
        } catch (e) {
          debugPrint('Error parsing image at index $i: $e');
        }
      }

      debugPrint(
        '✅ [GalleryProvider] Synced ${_images.length} images from backend',
      );

      // Cache the response
      await _databaseService.saveGalleryCache(userId, json.encode(data));

      _groupImagesByMonth();
      _setLoading(false);

      // Trigger auto-save to download new images to Prism album
      _triggerAutoSave();
    } on ApiException catch (e) {
      debugPrint('API Exception during sync: ${e.message}');
      _setError('Sync failed: ${e.message}');
      _setLoading(false);
    } catch (e) {
      debugPrint('Error syncing with backend: $e');
      _setError('Sync failed: ${e.toString()}');
      _setLoading(false);
    }
  }

  /// Delete image permanently (from backend bin AND from phone gallery)
  /// Returns true if both operations succeed
  Future<bool> deleteImagePermanently({
    required String imageId,
    required String userId,
  }) async {
    try {
      debugPrint('🗑️ [GalleryProvider] Permanently deleting image: $imageId');

      // Step 1: Find the image in local album FIRST (before moving to bin)
      // We need to do this first because we need to find the local file
      final localImages = await _shareHandler.getLocalAlbumImages();
      debugPrint(
        '📱 [GalleryProvider] Found ${localImages.length} images in local album',
      );

      int? mediaStoreId;
      String? localFilePath;

      for (final localImg in localImages) {
        final fileName = localImg['fileName'] as String?;
        final path = localImg['path'] as String?;
        final id = localImg['id'];

        // Match by imageId in filename (the file is saved as imageId.extension)
        if (fileName != null) {
          // Remove extension and check if it matches or contains the imageId
          final fileNameWithoutExt = fileName.contains('.')
              ? fileName.substring(0, fileName.lastIndexOf('.'))
              : fileName;

          debugPrint('   Comparing: "$fileNameWithoutExt" with "$imageId"');

          if (fileNameWithoutExt == imageId || fileName.contains(imageId)) {
            // Get the MediaStore ID (prefer this for deletion on Android 10+)
            if (id != null) {
              mediaStoreId = id is int ? id : int.tryParse(id.toString());
            }
            localFilePath = path;
            debugPrint(
              '✅ [GalleryProvider] Found matching file: $fileName (ID: $mediaStoreId, Path: $path)',
            );
            break;
          }
        }
      }

      // Step 2: Move to bin on backend
      await toggleImageStatus(imageId: imageId, userId: userId, field: 'bin');
      debugPrint('✅ [GalleryProvider] Moved to bin on backend');

      // Step 3: Delete from phone gallery using MediaStore ID (preferred) or path
      bool deleted = false;

      if (mediaStoreId != null) {
        debugPrint(
          '📱 [GalleryProvider] Deleting from gallery by MediaStore ID: $mediaStoreId',
        );
        deleted = await _shareHandler.deleteFromGalleryById(mediaStoreId);
        if (deleted) {
          debugPrint('✅ [GalleryProvider] Deleted from phone gallery by ID');
        } else {
          debugPrint('⚠️ [GalleryProvider] Delete by ID failed');
        }
      }

      // Fallback to path-based deletion if ID deletion failed
      if (!deleted && localFilePath != null && localFilePath.isNotEmpty) {
        debugPrint(
          '📱 [GalleryProvider] Trying path-based deletion: $localFilePath',
        );
        deleted = await _shareHandler.deleteFromGallery(localFilePath);
        if (deleted) {
          debugPrint('✅ [GalleryProvider] Deleted from phone gallery by path');
        } else {
          debugPrint('⚠️ [GalleryProvider] Delete by path also failed');
        }
      }

      if (deleted) {
        // Remove tracking record
        await _databaseService.removeGallerySaveRecord(imageId);
      } else if (mediaStoreId == null &&
          (localFilePath == null || localFilePath.isEmpty)) {
        debugPrint(
          '⚠️ [GalleryProvider] Could not find local file for image: $imageId',
        );
        debugPrint('   Available files in album:');
        for (final img in localImages) {
          debugPrint('   - ${img['fileName']}');
        }
      }

      return true;
    } catch (e) {
      debugPrint('❌ [GalleryProvider] Error deleting permanently: $e');
      return false;
    }
  }

  /// Refresh gallery after share operation
  /// Re-syncs local album with backend to pick up newly shared images
  Future<void> refreshAfterShare(String userId) async {
    debugPrint('🔄 [GalleryProvider] Refreshing gallery after share...');
    // Force refresh to get the newly shared image
    await fetchGallery(userId: userId, forceRefresh: true);
    debugPrint('✅ [GalleryProvider] Gallery refreshed after share');
  }

  // ==================== LOCAL-FIRST GALLERY METHODS ====================

  /// Initialize gallery on app start
  /// This should be called early in the app lifecycle to:
  /// 1. Rebuild tracking database from local files (if needed after reinstall)
  /// 2. Load images from local storage for instant display
  /// 3. Sync with backend in background
  Future<void> initializeGallery({required String userId}) async {
    try {
      debugPrint('📱 [GalleryProvider] Initializing gallery for user: $userId');

      // Step 1: Initialize the GallerySaveService (rebuilds tracking if needed)
      await _gallerySaveService.initializeIfNeeded();

      // Step 2: Load from local Prism album for instant display
      _localAlbumImages = await _shareHandler.getLocalAlbumImages();
      debugPrint(
        '📱 [GalleryProvider] Found ${_localAlbumImages.length} local images',
      );

      // Step 3: Try to load cached metadata (for favorites, archive status, etc.)
      final cachedData = await _databaseService.getGalleryCache(userId);
      if (cachedData != null && cachedData.isNotEmpty) {
        try {
          final List<dynamic> jsonList = json.decode(cachedData);
          _images = [];
          bool hasExpiredUrls = false;

          for (var i = 0; i < jsonList.length; i++) {
            try {
              final galleryImage = GalleryImage.fromJson(
                jsonList[i] as Map<String, dynamic>,
              );
              _images.add(galleryImage);

              // Check if any URL is expired
              if (!hasExpiredUrls && galleryImage.image.isUrlExpired) {
                hasExpiredUrls = true;
              }
            } catch (e) {
              debugPrint('Error parsing cached image at index $i: $e');
            }
          }

          _groupImagesByMonth();
          _setError(null);
          notifyListeners();

          debugPrint(
            '📱 [GalleryProvider] Loaded ${_images.length} images from cache',
          );

          // If URLs are expired, sync with backend in background
          if (hasExpiredUrls) {
            debugPrint(
              '📱 [GalleryProvider] URLs expired, syncing with backend...',
            );
            _syncWithBackend(userId); // Don't await, let it run in background
          }

          return;
        } catch (e) {
          debugPrint('Error parsing cached data: $e');
          await _databaseService.clearGalleryCache(userId);
        }
      }

      // Step 4: No valid cache, fetch from backend
      debugPrint('📱 [GalleryProvider] No cache, fetching from backend...');
      await _syncWithBackend(userId);
    } catch (e, stackTrace) {
      debugPrint('❌ [GalleryProvider] Error initializing gallery: $e');
      debugPrint('Stack trace: $stackTrace');
      _setError('Failed to initialize gallery: ${e.toString()}');
    }
  }

  /// Refresh and sync with backend
  /// Call this when user pulls to refresh or wants to check for new images
  /// Only downloads images not already present locally
  Future<void> refreshAndSync({required String userId}) async {
    if (!await _ensureAuthenticated()) return;

    try {
      debugPrint('🔄 [GalleryProvider] Refresh and sync requested...');
      _setLoading(true);
      _setError(null);

      // Refresh local image cache first
      await _gallerySaveService.refreshLocalImageCache();

      // Fetch fresh data from backend
      final data = await _apiClient.getGallery();

      debugPrint(
        '📥 [GalleryProvider] Received ${data.length} images from backend',
      );

      _images = [];
      final imagesToSave = <Map<String, String>>[];

      for (var i = 0; i < data.length; i++) {
        try {
          final galleryImage = GalleryImage.fromJson(
            data[i] as Map<String, dynamic>,
          );
          _images.add(galleryImage);

          // Collect images for auto-save
          if (!galleryImage.galleryMeta.bin &&
              galleryImage.image.imageUrl.isNotEmpty) {
            imagesToSave.add({
              'id': galleryImage.image.id,
              'url': galleryImage.image.imageUrl,
            });
          }
        } catch (e) {
          debugPrint('Error parsing image at index $i: $e');
        }
      }

      // Cache the response
      await _databaseService.saveGalleryCache(userId, json.encode(data));

      _groupImagesByMonth();
      _setLoading(false);

      // Auto-save only NEW images (local-first checking happens in GallerySaveService)
      if (imagesToSave.isNotEmpty) {
        debugPrint(
          '📱 [GalleryProvider] Triggering auto-save for ${imagesToSave.length} images',
        );
        _gallerySaveService.processImagesForAutoSave(imagesToSave);
      }

      debugPrint('✅ [GalleryProvider] Refresh and sync complete');
    } on ApiException catch (e) {
      debugPrint('API Exception during refresh: ${e.message}');
      _setError('Refresh failed: ${e.message}');
      _setLoading(false);
    } catch (e) {
      debugPrint('Error during refresh: $e');
      _setError('Refresh failed: ${e.toString()}');
      _setLoading(false);
    }
  }

  /// Get count of images in local Prism album
  /// Useful for showing user how many images are stored locally
  int get localImageCount => _localAlbumImages.length;

  /// Check if local images are available (for UI feedback)
  bool get hasLocalImages => _localAlbumImages.isNotEmpty;
}
