import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/review_layout.dart';
import 'package:prism/models/review_models.dart';
import 'package:prism/models/contact_sync_result.dart';
import 'package:prism/models/sharing_models.dart';
import 'package:prism/services/batch_status_stream.dart';
import 'package:prism/services/batch_unknown_faces_store.dart';
import 'package:prism/services/contact_service.dart';
import 'package:prism/services/local_notification_service.dart';
import 'package:prism/utils/globals.dart';

class SharingProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final ContactService _contactService = ContactService();
  final LocalNotificationService _notificationService =
      LocalNotificationService();

  // State
  List<File> _selectedImages = [];
  // Store mapping of image IDs to local file paths for fallback
  final Map<String, String> _imageIdToLocalPath = {};
  String _description = '';
  bool _autoClean = false;
  bool _isUploading = false;
  bool _isProcessing = false;
  final Map<String, List<String>> _imageRecipientMap =
      {}; // Custom recipients map
  List<DetectedRecipient> _allFriends =
      []; // All friends list treated as potential recipients

  double _uploadProgress = 0.0;
  String? _error;
  String? _currentBatchId;
  String? _userId; // Added for batch authorization
  BatchStatusResponse? _batchStatus;
  Map<String, dynamic>? _lastBatchRawJson;
  Timer? _pollingTimer;
  BatchStatusStream? _batchStatusStream;
  String? _sseStatusMessage;
  bool _batchWatchFinalized = false;
  int _fallbackPollAttempts = 0;
  static const int _maxFallbackPollAttempts = 120; // 10 min at 5s
  bool _handlingSseTerminal = false;
  bool _sendNoFaceToAll = false;
  final Set<String> _bulkAssignedNoFaceImageIds = {};
  static const Set<String> _specialFlags = {'archive', 'favourite', 'bin'};
  List<OnPlatformUser> _cachedOnPlatformUsers = const [];

  // Getters
  List<File> get selectedImages => _selectedImages;
  Map<String, String> get imageIdToLocalPath => _imageIdToLocalPath;
  String get description => _description;
  bool get autoClean => _autoClean;
  bool get isUploading => _isUploading;
  bool get isProcessing => _isProcessing;
  double get uploadProgress => _uploadProgress;
  String? get error => _error;
  String? get currentBatchId => _currentBatchId;
  BatchStatusResponse? get batchStatus => _batchStatus;
  /// Live line from SSE `status` events while the batch is processing.
  String? get batchProcessingSubtitle => _sseStatusMessage;
  bool get hasImages => _selectedImages.isNotEmpty;
  int get selectedCount => _selectedImages.length;
  List<DetectedRecipient> get selectedRecipients =>
      _batchStatus?.recipients.where((r) => r.isSelected).toList() ?? [];

  // comprehensive list of recipients (detected + all friends)
  List<DetectedRecipient> get allPotentialRecipients {
    final detected = _batchStatus?.recipients ?? [];
    final friends = _allFriends;

    // Start with detected users
    final Map<String, DetectedRecipient> merged = {
      for (var r in detected) r.userId: r,
    };

    // Add friends who aren't already detected
    for (var f in friends) {
      if (!merged.containsKey(f.userId)) {
        merged[f.userId] = f;
      }
    }

    return merged.values.toList();
  }

  Map<String, List<String>> get imageRecipientMap => _imageRecipientMap;

  bool get sendNoFaceToAll => _sendNoFaceToAll;

  /// Photos with no detected faces — mutually exclusive with [faceDetectedImages].
  List<BatchImage> get noFaceImages =>
      _batchStatus?.reviewIndex.noFaceImages ?? [];

  /// Photos with at least one detected face — mutually exclusive with [noFaceImages].
  List<BatchImage> get faceDetectedImages {
    final batch = _batchStatus;
    if (batch == null) return [];
    final noFaceIds = batch.reviewIndex.noFaceImageIds;
    return batch.images.where((img) => !noFaceIds.contains(img.id)).toList();
  }

  bool get hasNoFaceImages => noFaceImages.isNotEmpty;

  /// Batch recipients excluding the uploader — used for "Send to all".
  List<String> get batchRecipientUserIds {
    if (_batchStatus == null || _userId == null) return [];
    return _batchStatus!.recipients
        .map((r) => r.userId)
        .where((id) => id != _userId)
        .toList();
  }

  bool get canSendNoFaceToAll =>
      hasNoFaceImages && batchRecipientUserIds.isNotEmpty;

  /// User recipient count for a single image (excludes album flags and self).
  int recipientCountForImage(String imageId) {
    final recipients = _imageRecipientMap[imageId];
    if (recipients == null) return 0;
    return recipients
        .where((r) => !_specialFlags.contains(r) && r != _userId)
        .length;
  }

  /// True when at least one image is assigned to a friend recipient.
  bool get hasValidShareRecipients {
    if (_userId == null) return false;
    var valid = false;
    for (final recipients in _imageRecipientMap.values) {
      for (final recipient in recipients) {
        if (!_specialFlags.contains(recipient) && recipient != _userId) {
          valid = true;
        }
      }
    }
    return valid;
  }

  /// Contacts detected in this batch who are on Prism but not yet friends.
  List<ReviewSuggestion> get batchContactSuggestions {
    final batch = _batchStatus;
    if (batch == null) return [];

    final suggestions = batch.contacts
        .where((contact) => contact.userId != _userId)
        .map(
          (contact) => ReviewSuggestion(
            userId: contact.userId,
            username: contact.username,
            profilePicId: contact.profilePicId,
            photoCount: photoCountForUserId(contact.userId),
          ),
        )
        .toList();

    suggestions.sort((a, b) => b.photoCount.compareTo(a.photoCount));
    return suggestions;
  }

  /// Full review layout — every uploaded image is placed in exactly one section.
  ReviewLayout? get reviewLayout {
    final batch = _batchStatus;
    if (batch == null || _userId == null) return null;

    final friendUserIds = _allFriends.map((f) => f.userId).toSet();

    return ReviewLayout.fromBatch(
      batch,
      _userId!,
      friendUserIds: friendUserIds,
    );
  }


  List<BatchImage> imagesForUserId(String userId) {
    final batch = _batchStatus;
    if (batch == null || _userId == null) return [];

    return batch.images
        .where((image) {
          if (batch.reviewIndex.unknownFaceImageIds.contains(image.id)) {
            return false;
          }
          return image.recognizedUserIds.contains(userId);
        })
        .toList();
  }

  int photoCountForUserId(String userId) => imagesForUserId(userId).length;

  /// Snapshot of friends who received photos — call before [clearBatch].
  List<DetectedRecipient> collectConfirmedRecipients() {
    if (_batchStatus == null || _userId == null) return [];

    final recipientIds = <String>{};
    for (final recipients in _imageRecipientMap.values) {
      for (final id in recipients) {
        if (!_specialFlags.contains(id) && id != _userId) {
          recipientIds.add(id);
        }
      }
    }

    final lookup = {
      for (final recipient in allPotentialRecipients) recipient.userId: recipient,
    };

    final result = recipientIds.map((id) {
      final existing = lookup[id];
      final count = _photoCountInRecipientMap(id);
      return DetectedRecipient(
        userId: id,
        username: existing?.username ?? 'Friend',
        profilePicId: existing?.profilePicId,
        count: count,
        isSelected: true,
      );
    }).toList();

    result.sort((a, b) => b.count.compareTo(a.count));
    return result;
  }

  int _photoCountInRecipientMap(String userId) {
    var count = 0;
    for (final recipients in _imageRecipientMap.values) {
      if (recipients.contains(userId)) count++;
    }
    return count;
  }

  // Check if all images are marked for archive
  bool get areAllArchived {
    if (_batchStatus?.images.isEmpty ?? true) return false;
    // Check if every image has the 'archive' flag
    return _batchStatus!.images.every((img) {
      final flags = _imageRecipientMap[img.id];
      return flags?.contains('archive') ?? false; // Default is false
    });
  }

  // Set selected images
  void setSelectedImages(List<File> images) {
    _selectedImages = images;
    _error = null;
    notifyListeners();
  }

  // Add images to selection
  void addImages(List<File> images) {
    _selectedImages.addAll(images);
    _error = null;
    notifyListeners();
  }

  // Remove image from selection
  void removeImage(int index) {
    if (index >= 0 && index < _selectedImages.length) {
      _selectedImages.removeAt(index);
      notifyListeners();
    }
  }

  // Clear all selected images
  void clearImages() {
    _selectedImages.clear();
    _description = '';
    _error = null;
    notifyListeners();
  }

  // Clear loaded batch
  void clearBatch() {
    _batchStatus = null;
    _imageRecipientMap.clear();
    _sendNoFaceToAll = false;
    _bulkAssignedNoFaceImageIds.clear();
    _error = null;
    _sseStatusMessage = null;
    notifyListeners();
  }

  // Set description
  void setDescription(String desc) {
    _description = desc;
    notifyListeners();
  }

  // Toggle auto-clean
  void toggleAutoClean() {
    _autoClean = !_autoClean;
    notifyListeners();
  }

  // Set auto-clean value
  void setAutoClean(bool value) {
    _autoClean = value;
    notifyListeners();
  }

  // Toggle recipient selection
  void toggleRecipient(String userId) {
    if (_batchStatus != null) {
      final recipient = _batchStatus!.recipients.firstWhere(
        (r) => r.userId == userId,
      );
      recipient.isSelected = !recipient.isSelected;
      notifyListeners();
    }
  }

  // Toggle recipient for specific image
  void toggleImageRecipient(String imageId, String userId) {
    if (!_imageRecipientMap.containsKey(imageId)) {
      _imageRecipientMap[imageId] = [];
    }

    final recipients = _imageRecipientMap[imageId]!;
    if (recipients.contains(userId)) {
      recipients.remove(userId);
    } else {
      recipients.add(userId);
    }

    // Clean up empty entries
    if (recipients.isEmpty) {
      _imageRecipientMap.remove(imageId);
    }

    if (noFaceImages.any((img) => img.id == imageId)) {
      _bulkAssignedNoFaceImageIds.remove(imageId);
      _reconcileSendNoFaceToAllCheckbox();
    }

    notifyListeners();
  }

  /// Assign all no-face images to every friend detected in this batch.
  void setSendNoFaceToAll(bool value) {
    if (_sendNoFaceToAll == value) return;

    _sendNoFaceToAll = value;
    if (value) {
      _applySendNoFaceToAll();
    } else {
      _clearBulkNoFaceRecipients();
    }
    notifyListeners();
  }

  void _applySendNoFaceToAll() {
    final recipientIds = batchRecipientUserIds;
    if (recipientIds.isEmpty) {
      _sendNoFaceToAll = false;
      return;
    }

    for (final img in noFaceImages) {
      _bulkAssignedNoFaceImageIds.add(img.id);
      _imageRecipientMap[img.id] = List<String>.from(recipientIds);
    }
  }

  void _clearBulkNoFaceRecipients() {
    for (final imageId in _bulkAssignedNoFaceImageIds) {
      _imageRecipientMap.remove(imageId);
    }
    _bulkAssignedNoFaceImageIds.clear();
  }

  void _reconcileSendNoFaceToAllCheckbox() {
    final expected = batchRecipientUserIds;
    if (expected.isEmpty || noFaceImages.isEmpty) {
      _sendNoFaceToAll = false;
      return;
    }

    final expectedSet = expected.toSet();
    _sendNoFaceToAll = noFaceImages.every((img) {
      final assigned = _imageRecipientMap[img.id];
      if (assigned == null) return false;
      final userRecipients = assigned
          .where((r) => !_specialFlags.contains(r) && r != _userId)
          .toSet();
      return userRecipients.length == expectedSet.length &&
          expectedSet.every(userRecipients.contains);
    });
  }

  // Check if specific recipient is selected for image
  bool isRecipientSelectedForImage(String imageId, String userId) {
    return _imageRecipientMap[imageId]?.contains(userId) ?? false;
  }

  // Toggle archive status for specific image
  void toggleImageArchive(String imageId) {
    if (!_imageRecipientMap.containsKey(imageId)) {
      _imageRecipientMap[imageId] = [];
    }

    final flags = _imageRecipientMap[imageId]!;
    if (flags.contains('archive')) {
      flags.remove('archive');
    } else {
      flags.add('archive');
    }

    // Clean up empty entries
    if (flags.isEmpty) {
      _imageRecipientMap.remove(imageId);
    }

    notifyListeners();
  }

  // Set archive status for ALL images
  void setAllArchive(bool archive) {
    if (_batchStatus?.images.isEmpty ?? true) return;

    for (var img in _batchStatus!.images) {
      if (!_imageRecipientMap.containsKey(img.id)) {
        _imageRecipientMap[img.id] = [];
      }

      final flags = _imageRecipientMap[img.id]!;
      if (archive) {
        if (!flags.contains('archive')) flags.add('archive');
      } else {
        flags.remove('archive');
      }

      if (flags.isEmpty) {
        _imageRecipientMap.remove(img.id);
      }
    }
    notifyListeners();
  }

  // Check if image is archived
  bool isImageArchived(String imageId) {
    return _imageRecipientMap[imageId]?.contains('archive') ?? false;
  }

  /// Load batch status from server (used when reopening from notification)
  Future<bool> loadBatchStatus(String batchId, String userId) async {
    try {
      debugPrint('🔄 [SharingProvider] Loading batch status: $batchId');
      _userId = userId;
      _currentBatchId = batchId;
      _sseStatusMessage = null;

      final response = await _apiClient.getBatchStatus(
        batchId: batchId,
      );

      _applyBatchStatusResponse(response);

      if (_batchStatus!.isCompleted) {
        await _persistBatchUnknownFaces();
        _autoSelectDetectedRecipients();
        await _fetchAllFriends();
      }

      debugPrint('✅ [SharingProvider] Batch status loaded successfully');
      debugPrint('   Images: ${_batchStatus!.images.length}');
      debugPrint('   Recipients: ${_batchStatus!.recipients.length}');
      debugPrint('   Contacts: ${_batchStatus!.contacts.length}');
      debugPrint('   Unknowns: ${_batchStatus!.unknowns.length}');

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to load batch status: ${e.toString()}';
      debugPrint('❌ [SharingProvider] Load batch status failed: $e');
      notifyListeners();
      return false;
    }
  }

  // Upload images batch
  Future<String?> uploadImages(String userId) async {
    if (_selectedImages.isEmpty) {
      _error = 'No images selected';
      debugPrint('❌ [SharingProvider] Upload failed: No images selected');
      notifyListeners();
      return null;
    }

    debugPrint(
      '📤 [SharingProvider] Starting upload for ${_selectedImages.length} images',
    );
    debugPrint('   User ID: $userId');
    _userId = userId; // Save userId for polling
    debugPrint(
      '   Description: ${_description.isNotEmpty ? _description : "(none)"}',
    );

    // Drop any previous batch so ProcessingScreen cannot reopen stale review data.
    clearBatch();
    _currentBatchId = null;
    _batchWatchFinalized = false;
    _pollingTimer?.cancel();
    _disconnectBatchStream();

    _isUploading = true;
    _uploadProgress = 0.0;
    _error = null;
    notifyListeners();

    // Start notification
    _notificationService.showProgressNotification(
      id: 101,
      title: 'Uploading Media',
      body: 'Upload in progress...',
      progress: 0,
      maxProgress: 100,
    );

    try {
      // Simulate upload progress
      _uploadProgress = 0.3;
      notifyListeners();

      debugPrint('🔄 [SharingProvider] Calling uploadImagesBatch API...');
      final response = await _apiClient
          .uploadImagesBatch(
            images: _selectedImages,
            description: _description.isNotEmpty ? _description : null,
          )
          .timeout(
            const Duration(minutes: 5),
            onTimeout: () {
              throw Exception('Upload timeout after 5 minutes');
            },
          );

      debugPrint('✅ [SharingProvider] Upload API response received');
      debugPrint('   Response: $response');

      debugPrint('   Response: $response');

      _uploadProgress = 1.0;
      notifyListeners();

      // Notify upload complete / processing starting
      _notificationService.showProgressNotification(
        id: 101, // Arbitrary ID for upload
        title: 'Uploading Media',
        body: 'Upload complete.Analyzing content...',
        progress: 100,
        maxProgress: 100,
      );

      final batchUpload = BatchUploadResponse.fromJson(response);
      _currentBatchId = batchUpload.batchId;
      debugPrint('✅ [SharingProvider] Batch created with ID: $_currentBatchId');

      _isUploading = false;
      notifyListeners();

      // Watch batch status (SSE + REST; 5s polling fallback)
      debugPrint('🔌 [SharingProvider] Starting batch status watch (SSE)...');
      await _startBatchStatusWatch();

      return _currentBatchId;
    } catch (e) {
      _error = e.toString();
      _isUploading = false;
      _uploadProgress = 0.0;
      debugPrint('❌ [SharingProvider] Upload failed: $e');
      notifyListeners();
      return null;
    }
  }

  void _disconnectBatchStream() {
    _batchStatusStream?.disconnect();
    _batchStatusStream = null;
  }

  Future<void> _startBatchStatusWatch() async {
    if (_currentBatchId == null) {
      debugPrint('⚠️ [SharingProvider] Cannot watch batch: No batch ID');
      return;
    }

    _isProcessing = true;
    _error = null;
    _batchWatchFinalized = false;
    _sseStatusMessage = null;
    _fallbackPollAttempts = 0;
    _pollingTimer?.cancel();
    _disconnectBatchStream();
    notifyListeners();

    await _fetchBatchStatus();
    if (_batchWatchFinalized) return;

    if (_batchStatus?.isCompleted == true || _batchStatus?.isFailed == true) {
      await _finalizeBatchWatchFromRest();
      return;
    }

    debugPrint('🔌 [SharingProvider] Opening SSE batch stream...');
    _batchStatusStream = BatchStatusStream();
    await _batchStatusStream!.connect(
      batchId: _currentBatchId!,
      onStatus: (status, message, error) {
        if (_batchWatchFinalized) return;
        _sseStatusMessage = message ?? error;
        notifyListeners();

        if (BatchStatusStream.isTerminalStatus(status)) {
          unawaited(_handleSseTerminalEvent());
        }
      },
      onConnectionError: (Object e) {
        if (_batchWatchFinalized || !_isProcessing) return;
        debugPrint('⚠️ [SharingProvider] SSE connection issue: $e');
        _disconnectBatchStream();
        _startPollingFallback();
      },
    );
  }

  Future<void> _handleSseTerminalEvent() async {
    if (_batchWatchFinalized) return;
    if (_handlingSseTerminal) return;
    _handlingSseTerminal = true;
    try {
      _disconnectBatchStream();
      try {
        await _fetchBatchStatus(stopWatchOnFetchError: false);
      } catch (e) {
        debugPrint('❌ [SharingProvider] REST after SSE terminal: $e');
      }
      if (_batchWatchFinalized) return;

      if (_batchStatus?.isCompleted == true || _batchStatus?.isFailed == true) {
        await _finalizeBatchWatchFromRest();
      } else {
        _startPollingFallback();
      }
    } finally {
      _handlingSseTerminal = false;
    }
  }

  Future<void> _finalizeBatchWatchFromRest() async {
    if (_batchWatchFinalized) return;
    if (_batchStatus?.isCompleted != true && _batchStatus?.isFailed != true) {
      return;
    }

    _batchWatchFinalized = true;
    _pollingTimer?.cancel();
    _disconnectBatchStream();

    _isProcessing = false;
    debugPrint(
      '⏹️ [SharingProvider] Batch watch finished: ${_batchStatus?.status}',
    );
    notifyListeners();

    if (_batchStatus?.isCompleted == true) {
      _notificationService.cancel(101);
      _notificationService.showCompletionNotification(
        id: 102,
        title: 'Ready to Review!',
        body:
            'We found ${_batchStatus?.recipients.length ?? 0} friends in your photos.',
        payload: 'REVIEW_READY:$_currentBatchId',
      );

      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushReplacementNamed(
          '/confirm_share',
          arguments: {'batchId': _currentBatchId},
        );
      }
    }
  }

  void _startPollingFallback() {
    if (_currentBatchId == null || _userId == null) return;
    if (_batchWatchFinalized) return;

    debugPrint(
      '🔄 [SharingProvider] Using 5s REST polling fallback (SSE unavailable)',
    );
    _pollingTimer?.cancel();
    _fallbackPollAttempts = 0;

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_batchWatchFinalized) {
        timer.cancel();
        return;
      }
      if (_currentBatchId == null || _userId == null) {
        timer.cancel();
        return;
      }

      _fallbackPollAttempts++;
      debugPrint(
        '🔄 [SharingProvider] Fallback poll $_fallbackPollAttempts/$_maxFallbackPollAttempts',
      );

      await _fetchBatchStatus(stopWatchOnFetchError: false);

      if (_batchWatchFinalized) {
        timer.cancel();
        return;
      }

      if (_batchStatus?.isCompleted == true || _batchStatus?.isFailed == true) {
        timer.cancel();
        await _finalizeBatchWatchFromRest();
      } else if (_fallbackPollAttempts >= _maxFallbackPollAttempts) {
        timer.cancel();
        _isProcessing = false;
        _error = 'Processing timeout: took longer than expected';
        _disconnectBatchStream();
        notifyListeners();
      }
    });
  }

  // Fetch batch status
  Future<void> _fetchBatchStatus({bool stopWatchOnFetchError = true}) async {
    if (_currentBatchId == null) {
      debugPrint('⚠️ [SharingProvider] Cannot fetch batch status: No batch ID');
      return;
    }

    // Get userId from context - we'll need to pass this from the calling method
    // For now, we'll need to add a userId field to the provider
    if (_userId == null) {
      debugPrint('⚠️ [SharingProvider] Cannot fetch batch status: No user ID');
      return;
    }

    try {
      debugPrint(
        '🔄 [SharingProvider] Fetching batch status for: $_currentBatchId',
      );
      final response = await _apiClient
          .getBatchStatus(
            batchId: _currentBatchId!,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Batch status check timeout');
            },
          );

      debugPrint('📦 [SharingProvider] Batch status response received');

      _applyBatchStatusResponse(response);

      debugPrint('   Status: ${_batchStatus!.status}');
      debugPrint('   Images: ${_batchStatus!.images.length}');
      debugPrint('   Recipients: ${_batchStatus!.recipients.length}');
      debugPrint('   Contacts: ${_batchStatus!.contacts.length}');
      debugPrint('   Unknowns: ${_batchStatus!.unknowns.length}');

      // Log recipient details
      if (_batchStatus!.recipients.isNotEmpty) {
        debugPrint('   📋 Recipients:');
        for (var recipient in _batchStatus!.recipients) {
          debugPrint(
            '     - ${recipient.username} (${recipient.count} photos)',
          );
        }
      }

      if (_batchStatus!.isFailed) {
        _error = (_batchStatus!.errorMessage != null &&
                _batchStatus!.errorMessage!.isNotEmpty)
            ? _batchStatus!.errorMessage!
            : 'Processing failed';
        debugPrint('❌ [SharingProvider] Batch processing failed');
      } else if (_batchStatus!.isCompleted) {
        debugPrint(
          '✅ [SharingProvider] Batch processing completed successfully',
        );
        await _fetchAllFriends();
        await _autoEnrichDiscoveryAfterBatch();
        await _persistBatchUnknownFaces();
        _autoSelectDetectedRecipients();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      if (stopWatchOnFetchError) {
        _isProcessing = false;
        _pollingTimer?.cancel();
        _disconnectBatchStream();
      }
      debugPrint('❌ [SharingProvider] Fetch batch status error: $e');
      notifyListeners();
    }
  }

  void _applyBatchStatusResponse(Map<String, dynamic> response) {
    _lastBatchRawJson = response;
    _imageRecipientMap.clear();
    _batchStatus = BatchStatusResponse.fromJson(response);
  }

  /// Cross-reference detected faces with synced contacts (page.tsx Group B/C).
  void applyDiscoveryEnrichment({
    required Set<String> friendUserIds,
    required List<OnPlatformUser> onPlatformUsers,
  }) {
    if (_batchStatus == null || _userId == null || _lastBatchRawJson == null) {
      return;
    }

    if (onPlatformUsers.isNotEmpty) {
      _cachedOnPlatformUsers = onPlatformUsers;
    }
    final effectiveOnPlatform = onPlatformUsers.isNotEmpty
        ? onPlatformUsers
        : _cachedOnPlatformUsers;

    final enriched = _batchStatus!.enrichDiscovery(
      currentUserId: _userId!,
      friendUserIds: friendUserIds,
      onPlatformUsers: effectiveOnPlatform,
      rawJson: _lastBatchRawJson,
    );

    if (identical(enriched, _batchStatus)) return;

    final beforeContacts = _batchStatus!.contacts.length;
    final beforeUnknowns = _batchStatus!.unknowns.length;
    _batchStatus = enriched;

    if (_batchStatus!.contacts.length != beforeContacts ||
        _batchStatus!.unknowns.length != beforeUnknowns) {
      debugPrint(
        '✨ [SharingProvider] Discovery enriched — '
        'contacts: ${_batchStatus!.contacts.length}, '
        'unknowns: ${_batchStatus!.unknowns.length}',
      );
    }

    if (_batchStatus!.isCompleted) {
      _autoSelectDetectedRecipients();
      unawaited(_persistBatchUnknownFaces());
    }
    notifyListeners();
  }

  Future<void> _autoEnrichDiscoveryAfterBatch() async {
    if (_userId == null || _batchStatus == null || !_batchStatus!.isCompleted) {
      return;
    }

    final friendUserIds = _allFriends.map((f) => f.userId).toSet();

    try {
      final recs = await _contactService.getRecommendations(_userId!);
      applyDiscoveryEnrichment(
        friendUserIds: friendUserIds,
        onPlatformUsers: recs?.onPlatform ?? _cachedOnPlatformUsers,
      );
    } catch (e) {
      debugPrint('⚠️ [SharingProvider] Auto discovery enrich failed: $e');
      applyDiscoveryEnrichment(
        friendUserIds: friendUserIds,
        onPlatformUsers: _cachedOnPlatformUsers,
      );
    }
  }

  Future<void> _persistBatchUnknownFaces() async {
    final batch = _batchStatus;
    if (batch == null || _userId == null || batch.unknowns.isEmpty) return;

    await BatchUnknownFacesStore.appendFromBatch(
      userId: _userId!,
      batchId: batch.batchId,
      unknowns: batch.unknowns,
    );
  }

  // Auto-select detected recipients
  void _autoSelectDetectedRecipients() {
    if (_batchStatus == null || _userId == null) return;

    void assignRecipient(String imageId, String userId) {
      if (userId == _userId) return;

      if (!_imageRecipientMap.containsKey(imageId)) {
        _imageRecipientMap[imageId] = [];
      }
      if (!_imageRecipientMap[imageId]!.contains(userId)) {
        _imageRecipientMap[imageId]!.add(userId);
        debugPrint('Auto-selected recipient $userId for image $imageId');
      }
    }

    for (final image in _batchStatus!.images) {
      if (_batchStatus!.reviewIndex.isNoFace(image.id)) continue;
      if (_batchStatus!.reviewIndex.unknownFaceImageIds.contains(image.id)) {
        continue;
      }

      for (final userId in image.recognizedUserIds) {
        assignRecipient(image.id, userId);
      }
    }
  }

  // Fetch all friends
  Future<void> _fetchAllFriends() async {
    if (_userId == null) return;
    try {
      final friendsJson = await _apiClient.getFriends();
      // Convert to DetectedRecipient format
      _allFriends = friendsJson.map((f) {
        // extract friend details from the friend object
        // Logic depends on API response structure, assuming standard friend object
        final friendId = f['friend_id'] == _userId
            ? f['user_id']
            : f['friend_id'];
        // We need username etc, assuming the API returns expanded friend object or we might need to map it
        // If getFriends returns list of friendship objects:
        final friendUser = f['friend_details'] ?? f;

        return DetectedRecipient(
          userId: friendUser['id'] ?? friendId,
          username: friendUser['username'] ?? 'Friend',
          profilePicId: friendUser['profile_pic_id'],
          count: 0, // Not detected in this batch
          isSelected: false, // Default false for non-detected
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ [SharingProvider] Failed to fetch friends: $e');
    }
  }

  int _sharedPhotoCount = 0;
  int get sharedPhotoCount => _sharedPhotoCount;

  int _sharedRecipientCount = 0;
  int get sharedRecipientCount => _sharedRecipientCount;

  // Confirm share
  Future<bool> confirmShare() async {
    if (_currentBatchId == null) {
      _error = 'No batch ID available';
      debugPrint('❌ [SharingProvider] Confirm share failed: No batch ID');
      notifyListeners();
      return false;
    }

    if (_userId == null) {
      _error = 'No user ID available';
      debugPrint('❌ [SharingProvider] Confirm share failed: No user ID');
      notifyListeners();
      return false;
    }

    // Build recipients list from both globally selected recipients AND custom per-image selections
    final Set<String> recipientIds = {};

    // Add globally selected recipients (from detected recipients with isSelected=true)
    recipientIds.addAll(selectedRecipients.map((r) => r.userId));

    // Add custom per-image recipients from imageRecipientMap
    // Filter out special flags like 'archive', 'favourite', 'bin'
    for (var recipients in _imageRecipientMap.values) {
      for (var recipient in recipients) {
        if (!_specialFlags.contains(recipient)) {
          recipientIds.add(recipient);
        }
      }
    }

    final recipientIdsList = recipientIds.toList();

    if (recipientIdsList.isEmpty) {
      _error = 'No recipients selected';
      debugPrint(
        '❌ [SharingProvider] Confirm share failed: No recipients selected',
      );
      notifyListeners();
      return false;
    }

    debugPrint('📤 [SharingProvider] Confirming share...');
    debugPrint('   Batch ID: $_currentBatchId');
    debugPrint('   User ID: $_userId');
    debugPrint('   Recipients: ${recipientIdsList.length}');
    debugPrint('   Recipients IDs: $recipientIdsList');
    debugPrint('   Auto Clean: $_autoClean');
    if (_imageRecipientMap.isNotEmpty) {
      debugPrint(
        '   Custom per-image recipients: ${_imageRecipientMap.length} images',
      );
    }

    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient
          .confirmShare(
            batchId: _currentBatchId!,
            recipients: recipientIdsList,
            autoClean: _autoClean,
            imageRecipientMap: _imageRecipientMap.isEmpty
                ? null
                : _imageRecipientMap,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Confirm share timeout');
            },
          );

      // Store the confirmation results before reset
      _sharedPhotoCount = _batchStatus?.images.length ?? _selectedImages.length;
      _sharedRecipientCount =
          response['recipient_count'] as int? ?? recipientIdsList.length;

      debugPrint('✅ [SharingProvider] Share confirmed successfully');
      debugPrint('   Photos shared: $_sharedPhotoCount');
      debugPrint('   Recipients: $_sharedRecipientCount');

      _isProcessing = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      _isProcessing = false;
      debugPrint('❌ [SharingProvider] Confirm share error: $e');
      notifyListeners();
      return false;
    }
  }

  // Reset all state
  void reset() {
    _pollingTimer?.cancel();
    _disconnectBatchStream();
    _selectedImages.clear();
    _description = '';
    _autoClean = false;
    _isUploading = false;
    _isProcessing = false;
    _uploadProgress = 0.0;
    _error = null;
    _currentBatchId = null;
    _batchStatus = null;
    _imageRecipientMap.clear();
    _allFriends.clear();
    _sendNoFaceToAll = false;
    _bulkAssignedNoFaceImageIds.clear();
    _sseStatusMessage = null;
    _batchWatchFinalized = false;
    _handlingSseTerminal = false;

    // Ensure notifications are cleared
    _notificationService.cancel(101);
    _notificationService.cancel(102);

    notifyListeners();
  }

  // Cancel current operation
  Future<void> cancel() async {
    debugPrint('⏹️ [SharingProvider] Cancelling current operation');
    _batchWatchFinalized = true;
    _pollingTimer?.cancel();
    _disconnectBatchStream();

    // Call backend to clean up if we have a batch ID
    if (_currentBatchId != null && _userId != null) {
      try {
        debugPrint(
          '🗑️ [SharingProvider] Calling backend cancel for batch: $_currentBatchId',
        );
        await _apiClient.cancelBatch(
          batchId: _currentBatchId!,
        );
        debugPrint('✅ [SharingProvider] Backend cancel successful');
      } catch (e) {
        debugPrint('⚠️ [SharingProvider] Backend cancel failed (ignoring): $e');
      }
    }

    _isUploading = false;
    _isProcessing = false;
    clearBatch();
    _currentBatchId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _disconnectBatchStream();
    super.dispose();
  }
}
