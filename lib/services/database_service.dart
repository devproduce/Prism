import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:prism/models/user_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('prism.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_session (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        username TEXT NOT NULL,
        email TEXT NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT,
        face_id TEXT,
        image_id TEXT,
        profile_pic_id TEXT,
        pronouns TEXT,
        bio TEXT,
        dob TEXT,
        country_code TEXT,
        phone_number TEXT,
        created_at TEXT,
        archive_pin TEXT,
        is_user_logged_in INTEGER NOT NULL DEFAULT 1,
        contacts_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE gallery_cache (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        image_data TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS gallery_saves (
        image_id TEXT PRIMARY KEY,
        saved_at TEXT NOT NULL,
        gallery_path TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE gallery_cache (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          image_data TEXT NOT NULL,
          cached_at INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        ALTER TABLE user_session ADD COLUMN contacts_synced INTEGER NOT NULL DEFAULT 0
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        ALTER TABLE user_session ADD COLUMN archive_pin TEXT
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS gallery_saves (
          image_id TEXT PRIMARY KEY,
          saved_at TEXT NOT NULL,
          gallery_path TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      // gallery_saves was previously only in _createDB (fresh installs) but
      // existing users at v5 never had it created. This ensures all devices get it.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS gallery_saves (
          image_id TEXT PRIMARY KEY,
          saved_at TEXT NOT NULL,
          gallery_path TEXT NOT NULL
        )
      ''');
    }
  }

  /// Called every time the DB is opened — safety net for gallery_saves.
  Future<void> _onOpen(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gallery_saves (
        image_id TEXT PRIMARY KEY,
        saved_at TEXT NOT NULL,
        gallery_path TEXT NOT NULL
      )
    ''');
  }

  /// Save user session to database
  Future<void> saveUserSession(UserModel user) async {
    final db = await database;

    // Clear existing session first
    await clearUserSession();

    // Insert new session
    await db.insert('user_session', {
      'user_id': user.userId,
      'username': user.username,
      'email': user.email,
      'first_name': user.firstName,
      'last_name': user.lastName,
      'face_id': user.faceId,
      'image_id': user.imageId,
      'profile_pic_id': user.profilePicId,
      'pronouns': user.pronouns,
      'bio': user.bio,
      'dob': user.dob?.toIso8601String(),
      'country_code': user.countryCode,
      'phone_number': user.phoneNumber,
      'created_at': user.createdAt?.toIso8601String(),
      'archive_pin': user.archivePin,
      'is_user_logged_in': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get current user session
  Future<UserModel?> getUserSession() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'user_session',
      where: 'is_user_logged_in = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return _userFromMap(maps.first);
  }

  /// Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'user_session',
      where: 'is_user_logged_in = ?',
      whereArgs: [1],
      limit: 1,
    );

    return maps.isNotEmpty;
  }

  /// Clear user session (logout)
  Future<void> clearUserSession() async {
    final db = await database;
    await db.delete('user_session');
  }

  /// Update user session
  Future<void> updateUserSession(UserModel user) async {
    final db = await database;

    await db.update(
      'user_session',
      {
        'user_id': user.userId,
        'username': user.username,
        'email': user.email,
        'first_name': user.firstName,
        'last_name': user.lastName,
        'face_id': user.faceId,
        'image_id': user.imageId,
        'profile_pic_id': user.profilePicId,
        'pronouns': user.pronouns,
        'bio': user.bio,
        'dob': user.dob?.toIso8601String(),
        'country_code': user.countryCode,
        'phone_number': user.phoneNumber,
        'created_at': user.createdAt?.toIso8601String(),
        'archive_pin': user.archivePin,
      },
      where: 'is_user_logged_in = ?',
      whereArgs: [1],
    );
  }

  /// Convert map to UserModel
  UserModel _userFromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['user_id'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String?,
      faceId: map['face_id'] as String?,
      imageId: map['image_id'] as String?,
      profilePicId: map['profile_pic_id'] as String?,
      pronouns: map['pronouns'] as String?,
      bio: map['bio'] as String?,
      dob: map['dob'] != null ? DateTime.tryParse(map['dob'] as String) : null,
      countryCode: map['country_code'] as String?,
      phoneNumber: map['phone_number'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      archivePin: map['archive_pin'] as String?,
    );
  }

  // ==================== GALLERY CACHE METHODS ====================

  /// Save gallery images to cache
  Future<void> saveGalleryCache(String userId, String imageData) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert('gallery_cache', {
      'id': userId,
      'user_id': userId,
      'image_data': imageData,
      'cached_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get cached gallery images
  Future<String?> getGalleryCache(String userId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'gallery_cache',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return maps.first['image_data'] as String?;
  }

  /// Check if cache is valid (less than 30 minutes old)
  Future<bool> isCacheValid(String userId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'gallery_cache',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (maps.isEmpty) {
      return false;
    }

    final cachedAt = maps.first['cached_at'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - cachedAt;
    final thirtyMinutes = 30 * 60 * 1000; // 30 minutes in milliseconds

    return diff < thirtyMinutes;
  }

  /// Clear gallery cache for user
  Future<void> clearGalleryCache(String userId) async {
    final db = await database;
    await db.delete('gallery_cache', where: 'user_id = ?', whereArgs: [userId]);
  }

  /// Check if contacts have been synced
  Future<bool> hasContactsSynced() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'user_session',
      where: 'is_user_logged_in = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (maps.isEmpty) {
      return false;
    }

    return (maps.first['contacts_synced'] as int) == 1;
  }

  /// Mark contacts as synced
  Future<void> markContactsSynced() async {
    final db = await database;

    await db.update(
      'user_session',
      {'contacts_synced': 1},
      where: 'is_user_logged_in = ?',
      whereArgs: [1],
    );
  }

  /// Clear all data (user session, gallery cache, etc.)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('user_session');
    await db.delete('gallery_cache');
    try {
      await db.delete('gallery_saves');
    } catch (_) {
      // Table may not exist on older app versions before migration
    }
  }

  // ==================== GALLERY SAVES TRACKING ====================

  /// Mark image as saved to gallery
  Future<void> markImageAsSavedToGallery(
    String imageId,
    String galleryPath,
  ) async {
    final db = await database;
    await db.insert('gallery_saves', {
      'image_id': imageId,
      'saved_at': DateTime.now().toIso8601String(),
      'gallery_path': galleryPath,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Check if image is saved to gallery
  Future<bool> isImageSavedToGallery(String imageId) async {
    final db = await database;
    final result = await db.query(
      'gallery_saves',
      where: 'image_id = ?',
      whereArgs: [imageId],
    );
    return result.isNotEmpty;
  }

  /// Get gallery path for saved image
  Future<String?> getGalleryPath(String imageId) async {
    final db = await database;
    final result = await db.query(
      'gallery_saves',
      where: 'image_id = ?',
      whereArgs: [imageId],
    );
    if (result.isEmpty) return null;
    return result.first['gallery_path'] as String?;
  }

  /// Remove gallery save record when image is deleted from phone
  Future<void> removeGallerySaveRecord(String imageId) async {
    final db = await database;
    await db.delete(
      'gallery_saves',
      where: 'image_id = ?',
      whereArgs: [imageId],
    );
  }

  /// Get all saved image IDs from the database
  /// Returns a Set for efficient O(1) lookup
  Future<Set<String>> getAllSavedImageIds() async {
    try {
      final db = await database;
      final result = await db.query('gallery_saves', columns: ['image_id']);
      return result.map((row) => row['image_id'] as String).toSet();
    } catch (e) {
      print('Error getting all saved image IDs: $e');
      return {};
    }
  }

  /// Batch mark multiple images as saved to gallery
  /// More efficient than calling markImageAsSavedToGallery multiple times
  Future<void> batchMarkImagesAsSaved(List<Map<String, String>> images) async {
    if (images.isEmpty) return;

    try {
      final db = await database;
      final batch = db.batch();
      final now = DateTime.now().toIso8601String();

      for (final image in images) {
        final imageId = image['imageId'];
        final galleryPath = image['galleryPath'] ?? 'Pictures/Prism';

        if (imageId != null && imageId.isNotEmpty) {
          batch.insert('gallery_saves', {
            'image_id': imageId,
            'saved_at': now,
            'gallery_path': galleryPath,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      await batch.commit(noResult: true);
      print('Batch marked ${images.length} images as saved');
    } catch (e) {
      print('Error batch marking images as saved: $e');
    }
  }

  /// Check if gallery_saves table is empty
  /// Used to detect if tracking needs to be rebuilt from local files
  Future<bool> isGallerySavesEmpty() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM gallery_saves',
      );
      final count = Sqflite.firstIntValue(result) ?? 0;
      return count == 0;
    } catch (e) {
      print('Error checking if gallery_saves is empty: $e');
      return true;
    }
  }

  /// Clear all gallery saves
  Future<void> clearGallerySaves() async {
    final db = await database;
    try {
      await db.delete('gallery_saves');
    } catch (_) {
      // Table may not exist on older app versions before migration
    }
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
