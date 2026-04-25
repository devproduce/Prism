import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/sharing_models.dart';
import 'package:prism/services/local_notification_service.dart';
import 'package:prism/utils/globals.dart';

class SharingProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
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
  Timer? _pollingTimer;

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

    notifyListeners();
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

      final response = await _apiClient.getBatchStatus(
        batchId: batchId,
        userId: userId,
      );

      _batchStatus = BatchStatusResponse.fromJson(response);

      // Auto-select detected recipients for each image
      _autoSelectDetectedRecipients();

      // Fetch all friends for the recipient selector
      await _fetchAllFriends();

      debugPrint('✅ [SharingProvider] Batch status loaded successfully');
      debugPrint('   Images: ${_batchStatus!.images.length}');
      debugPrint('   Recipients: ${_batchStatus!.recipients.length}');

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
            userId: userId,
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

      // Start polling for batch status
      debugPrint('🔄 [SharingProvider] Starting polling for batch status...');
      await _startPolling();

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

  // Start polling for batch status
  int _pollingAttempts = 0;
  static const int _maxPollingAttempts = 150; // 5 minutes at 2-second intervals

  Future<void> _startPolling() async {
    if (_currentBatchId == null) {
      debugPrint('⚠️ [SharingProvider] Cannot start polling: No batch ID');
      return;
    }

    _isProcessing = true;
    _error = null;
    _pollingAttempts = 0;
    debugPrint(
      '🔄 [SharingProvider] Starting polling (max $_maxPollingAttempts attempts)',
    );
    notifyListeners();

    // Initial fetch
    await _fetchBatchStatus();

    // Poll every 2 seconds until completed
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _pollingAttempts++;
      debugPrint(
        '🔄 [SharingProvider] Polling attempt $_pollingAttempts/$_maxPollingAttempts',
      );

      await _fetchBatchStatus();

      if (_batchStatus?.isCompleted == true || _batchStatus?.isFailed == true) {
        timer.cancel();
        _isProcessing = false;
        debugPrint(
          '⏹️ [SharingProvider] Polling stopped: ${_batchStatus?.status}',
        );
        notifyListeners();

        // Processing complete
        if (_batchStatus?.isCompleted == true) {
          _notificationService.cancel(101); // Cancel progress
          _notificationService.showCompletionNotification(
            id: 102,
            title: 'Ready to Review!',
            body:
                'We found ${_batchStatus?.recipients.length ?? 0} friends in your photos.',
            payload: 'REVIEW_READY:$_currentBatchId', // Include batch ID
          );

          // Auto-navigate if app is open
          if (navigatorKey.currentState != null) {
            // Use pushReplacementNamed to remove processing screen from stack
            // so back button from review screen goes directly to share screen
            navigatorKey.currentState!.pushReplacementNamed('/confirm_share');
          }
        }
      } else if (_pollingAttempts >= _maxPollingAttempts) {
        timer.cancel();
        _isProcessing = false;
        _error = 'Processing timeout: took longer than expected';
        debugPrint(
          '⏱️ [SharingProvider] Polling stopped: Max attempts reached',
        );
        notifyListeners();
      }
    });
  }

  // Fetch batch status
  Future<void> _fetchBatchStatus() async {
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
            userId: _userId!, // Added for authorization
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Batch status check timeout');
            },
          );

      debugPrint('📦 [SharingProvider] Batch status response received');

      _batchStatus = BatchStatusResponse.fromJson(response);

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
        _error = 'Processing failed';
        debugPrint('❌ [SharingProvider] Batch processing failed');
      } else if (_batchStatus!.isCompleted) {
        debugPrint(
          '✅ [SharingProvider] Batch processing completed successfully',
        );
        // Auto-select detected recipients for each image
        _autoSelectDetectedRecipients();
        // Fetch all friends when batch is complete
        _fetchAllFriends();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isProcessing = false;
      _pollingTimer?.cancel();
      debugPrint('❌ [SharingProvider] Fetch batch status error: $e');
      notifyListeners();
    }
  }

  // Auto-select detected recipients
  void _autoSelectDetectedRecipients() {
    if (_batchStatus == null || _userId == null) return;

    for (var image in _batchStatus!.images) {
      if (image.detectedFaces != null) {
        for (var face in image.detectedFaces!) {
          if (face is Map && face['user_id'] != null) {
            final userId = face['user_id'].toString();

            // Don't add current user as a recipient (can't share with yourself)
            if (userId == _userId) {
              debugPrint('⏭️ Skipping current user from recipients: $userId');
              continue;
            }

            // Add to image recipient map
            if (!_imageRecipientMap.containsKey(image.id)) {
              _imageRecipientMap[image.id] = [];
            }
            if (!_imageRecipientMap[image.id]!.contains(userId)) {
              _imageRecipientMap[image.id]!.add(userId);
              debugPrint(
                '✅ Auto-selected recipient $userId for image ${image.id}',
              );
            }
          }
        }
      }
    }
  }

  // Fetch all friends
  Future<void> _fetchAllFriends() async {
    if (_userId == null) return;
    try {
      final friendsJson = await _apiClient.getFriends(userId: _userId!);
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
    const specialFlags = {'archive', 'favourite', 'bin'};
    for (var recipients in _imageRecipientMap.values) {
      for (var recipient in recipients) {
        if (!specialFlags.contains(recipient)) {
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
            userId: _userId!, // Added for authorization
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

    // Ensure notifications are cleared
    _notificationService.cancel(101);
    _notificationService.cancel(102);

    notifyListeners();
  }

  // Cancel current operation
  Future<void> cancel() async {
    debugPrint('⏹️ [SharingProvider] Cancelling current operation');
    debugPrint('   Polling attempts made: $_pollingAttempts');
    _pollingTimer?.cancel();

    // Call backend to clean up if we have a batch ID
    if (_currentBatchId != null && _userId != null) {
      try {
        debugPrint(
          '🗑️ [SharingProvider] Calling backend cancel for batch: $_currentBatchId',
        );
        await _apiClient.cancelBatch(
          batchId: _currentBatchId!,
          userId: _userId!,
        );
        debugPrint('✅ [SharingProvider] Backend cancel successful');
      } catch (e) {
        debugPrint('⚠️ [SharingProvider] Backend cancel failed (ignoring): $e');
      }
    }

    _isUploading = false;
    _isProcessing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
