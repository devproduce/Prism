import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// Model to hold album data with pre-fetched count
class AlbumInfo {
  final AssetPathEntity album;
  final int assetCount;
  final AssetEntity? coverAsset;

  AlbumInfo({required this.album, required this.assetCount, this.coverAsset});

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
  bool _isPermissionChecked = false;

  // Getters
  List<AlbumInfo> get albums => _albums;
  bool get isLoading => _isLoading;
  bool get hasPermission => _hasPermission;
  bool get isPermissionChecked => _isPermissionChecked;
  String? get error => _error;

  /// Request permission and fetch albums
  Future<bool> requestPermissionAndFetch({bool force = false}) async {
    if (!force && _hasPermission && _albums.isNotEmpty) {
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final PermissionState permission =
          await PhotoManager.requestPermissionExtend();

      _isPermissionChecked = true; // Mark as checked

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
      _isPermissionChecked = true; // Mark as checked even on error
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
      _isLoading = false;
      notifyListeners();

      // Load covers for all albums in background
      _loadAllAlbumCovers();
    } catch (e) {
      _error = 'Failed to fetch albums: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load covers for all albums
  Future<void> _loadAllAlbumCovers() async {
    for (int i = 0; i < _albums.length; i++) {
      // Optimization: Notify in batches or if needed
      if (i % 5 == 0 && i > 0) notifyListeners();

      try {
        final assets = await _albums[i].album.getAssetListRange(
          start: 0,
          end: 1,
        );
        if (assets.isNotEmpty) {
          _albums[i] = AlbumInfo(
            album: _albums[i].album,
            assetCount: _albums[i].assetCount,
            coverAsset: assets.first,
          );
        }
      } catch (e) {
        debugPrint('Error loading cover for ${_albums[i].name}: $e');
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
