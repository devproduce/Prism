import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppCacheManager {
  static final AppCacheManager _instance = AppCacheManager._internal();
  factory AppCacheManager() => _instance;
  AppCacheManager._internal();

  /// Clear all image cache
  Future<void> clearImageCache() async {
    try {
      await DefaultCacheManager().emptyCache();
      print('Image cache cleared successfully');
    } catch (e) {
      print('Error clearing image cache: $e');
    }
  }

  /// Get cache size info (simplified)
  Future<String> getCacheSize() async {
    try {
      // Simplified approach - just return status
      return 'Cache available';
    } catch (e) {
      print('Error getting cache size: $e');
      return 'Unknown';
    }
  }

  /// Remove old cache files
  Future<void> cleanOldCache() async {
    try {
      // Clear all cache to free up memory
      await DefaultCacheManager().emptyCache();
      print('Cache cleaned successfully');
    } catch (e) {
      print('Error cleaning cache: $e');
    }
  }
}
