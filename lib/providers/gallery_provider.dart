import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/gallery_image_model.dart';
import 'package:prism/services/database_service.dart';

class GalleryProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final DatabaseService _databaseService = DatabaseService.instance;

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
  List<GalleryImage> get allImages =>
      _images.where((img) => !img.galleryMeta.bin).toList();
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

  /// Fetch gallery images with caching
  Future<void> fetchGallery({
    required String userId,
    bool forceRefresh = false,
  }) async {
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

      final data = await _apiClient.getGallery(userId: userId);

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
    try {
      final newValue = await _apiClient.toggleImageStatus(
        imageId: imageId,
        userId: userId,
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
    try {
      await _apiClient.updateImageDescription(
        imageId: imageId,
        userId: userId,
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
    try {
      await _apiClient.batchUpdateStatus(
        userId: userId,
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
        userId: userId,
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
}
