import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// Model to hold album data with pre-fetched count
class AlbumInfo {
  final AssetPathEntity album;
  final int assetCount;
  final Uint8List? thumbnail;

  AlbumInfo({required this.album, required this.assetCount, this.thumbnail});

  String get name => album.name;
  String get id => album.id;
  bool get isAll => album.isAll;
}

/// Provider for managing local device gallery albums and assets.
/// Uses photo_manager to access the device's media library.
class LocalGalleryProvider with ChangeNotifier {
  List<AlbumInfo> _albums = [];
  Map<String, List<AssetEntity>> _albumAssets = {};
  bool _isLoading = false;
  bool _hasPermission = false;
  String? _error;

  // Getters
  List<AlbumInfo> get albums => _albums;
  bool get isLoading => _isLoading;
  bool get hasPermission => _hasPermission;
  String? get error => _error;

  /// Request permission and fetch albums
  Future<bool> requestPermissionAndFetch() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final PermissionState permission =
          await PhotoManager.requestPermissionExtend();

      if (permission.isAuth || permission.hasAccess) {
        _hasPermission = true;
        await fetchAlbums();
        return true;
      } else {
        _hasPermission = false;
        _error = 'Photo library permission denied';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to request permission: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetch all albums from the device
  Future<void> fetchAlbums() async {
    if (!_hasPermission) {
      await requestPermissionAndFetch();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get all albums (images and videos)
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.common, // Both images and videos
        hasAll: true, // Include "Recent" album
      );

      // Build AlbumInfo list with async counts
      List<AlbumInfo> albumInfoList = [];
      for (final path in paths) {
        final count = await path.assetCountAsync;
        if (count > 0) {
          albumInfoList.add(AlbumInfo(album: path, assetCount: count));
        }
      }

      // Sort albums: "Recent" first, then by asset count
      albumInfoList.sort((a, b) {
        if (a.isAll) return -1;
        if (b.isAll) return 1;
        return b.assetCount.compareTo(a.assetCount);
      });

      _albums = albumInfoList;

      // Preload thumbnails for visible albums (first 10)
      await _loadAlbumThumbnails(_albums.take(10).toList());

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch albums: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load thumbnails for albums
  Future<void> _loadAlbumThumbnails(List<AlbumInfo> albumInfos) async {
    for (int i = 0; i < albumInfos.length; i++) {
      final albumInfo = albumInfos[i];
      if (albumInfo.thumbnail != null) continue;

      try {
        final assets = await albumInfo.album.getAssetListRange(
          start: 0,
          end: 1,
        );
        if (assets.isNotEmpty) {
          final thumb = await assets.first.thumbnailDataWithSize(
            const ThumbnailSize(200, 200),
            quality: 80,
          );
          // Update the album info with thumbnail
          _albums[i] = AlbumInfo(
            album: albumInfo.album,
            assetCount: albumInfo.assetCount,
            thumbnail: thumb,
          );
        }
      } catch (e) {
        debugPrint('Error loading thumbnail for ${albumInfo.name}: $e');
      }
    }
    notifyListeners();
  }

  /// Get assets for a specific album
  Future<List<AssetEntity>> getAlbumAssets(
    AssetPathEntity album, {
    int page = 0,
    int pageSize = 50,
  }) async {
    final cacheKey = '${album.id}_$page';

    if (_albumAssets.containsKey(cacheKey)) {
      return _albumAssets[cacheKey]!;
    }

    try {
      final assets = await album.getAssetListPaged(page: page, size: pageSize);
      _albumAssets[cacheKey] = assets;
      return assets;
    } catch (e) {
      debugPrint('Error fetching assets for ${album.name}: $e');
      return [];
    }
  }

  /// Get recent photos (from "All" album)
  Future<List<AssetEntity>> getRecentPhotos({int count = 20}) async {
    if (_albums.isEmpty) return [];

    final recentAlbum = _albums.firstWhere(
      (a) => a.isAll,
      orElse: () => _albums.first,
    );

    return getAlbumAssets(recentAlbum.album, pageSize: count);
  }

  /// Refresh albums
  Future<void> refresh() async {
    _albumAssets.clear();
    await fetchAlbums();
  }

  /// Clear cache
  void clearCache() {
    _albumAssets.clear();
    notifyListeners();
  }
}
