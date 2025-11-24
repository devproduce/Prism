import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/sharing_models.dart';

class SharingProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  // State
  List<File> _selectedImages = [];
  String _description = '';
  bool _autoClean = true;
  bool _isUploading = false;
  bool _isProcessing = false;
  double _uploadProgress = 0.0;
  String? _error;
  String? _currentBatchId;
  BatchStatusResponse? _batchStatus;
  Timer? _pollingTimer;

  // Getters
  List<File> get selectedImages => _selectedImages;
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
    debugPrint(
      '   Description: ${_description.isNotEmpty ? _description : "(none)"}',
    );

    _isUploading = true;
    _uploadProgress = 0.0;
    _error = null;
    notifyListeners();

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

      _uploadProgress = 1.0;
      notifyListeners();

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

    try {
      debugPrint(
        '🔄 [SharingProvider] Fetching batch status for: $_currentBatchId',
      );
      final response = await _apiClient
          .getBatchStatus(batchId: _currentBatchId!)
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

    final recipientIds = selectedRecipients.map((r) => r.userId).toList();

    if (recipientIds.isEmpty) {
      _error = 'No recipients selected';
      debugPrint(
        '❌ [SharingProvider] Confirm share failed: No recipients selected',
      );
      notifyListeners();
      return false;
    }

    debugPrint('📤 [SharingProvider] Confirming share...');
    debugPrint('   Batch ID: $_currentBatchId');
    debugPrint('   Recipients: ${recipientIds.length}');
    debugPrint('   Auto Clean: $_autoClean');

    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient
          .confirmShare(
            batchId: _currentBatchId!,
            recipients: recipientIds,
            autoClean: _autoClean,
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
          response['recipient_count'] as int? ?? recipientIds.length;

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
    _autoClean = true;
    _isUploading = false;
    _isProcessing = false;
    _uploadProgress = 0.0;
    _error = null;
    _currentBatchId = null;
    _batchStatus = null;
    notifyListeners();
  }

  // Cancel current operation
  void cancel() {
    debugPrint('⏹️ [SharingProvider] Cancelling current operation');
    debugPrint('   Polling attempts made: $_pollingAttempts');
    _pollingTimer?.cancel();
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
