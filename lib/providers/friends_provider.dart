import 'package:flutter/material.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/friend_model.dart';
import 'package:prism/models/contact_sync_result.dart';
import 'package:prism/models/review_models.dart';
import 'package:prism/models/sharing_models.dart';
import 'package:prism/services/batch_unknown_faces_store.dart';
import 'package:prism/services/contact_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FriendshipDisplayStatus { none, pendingSent, friend }

class FriendsProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final ContactService _contactService = ContactService();

  List<Friend> _friends = [];
  List<FriendRequest> _pendingRequests = [];
  List<FriendRequest> _sentRequests = [];
  List<Friend> _searchResults = [];

  // V2 Discovery state
  ContactSyncResult? _contactSyncResult;
  bool _isLoadingRecommendations = false;
  bool _isSyncingContacts = false;
  DateTime? _lastSyncedAt;
  bool _hasSynced = false;
  bool _hasContactsPermission = false;
  bool _hasBackendContacts = false;
  int _backendContactCount = 0;
  List<UnknownFaceRecommendation> _batchUnknownFaces = [];

  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;
  DateTime? _lastFriendshipSyncAt;

  // Getters — existing
  List<Friend> get friends => _friends;
  List<FriendRequest> get pendingRequests => _pendingRequests;
  List<FriendRequest> get sentRequests => _sentRequests;
  List<Friend> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;

  // Getters — V2 discovery
  ContactSyncResult? get contactSyncResult => _contactSyncResult;

  /// Unknown faces from batch uploads + recommendations API (deduped by face id).
  List<UnknownFaceRecommendation> get displayUnknownFaces {
    final byFaceId = <String, UnknownFaceRecommendation>{};
    for (final face
        in _contactSyncResult?.unknownFaceRecommendations ?? const []) {
      if (face.faceId.isNotEmpty) byFaceId[face.faceId] = face;
    }
    for (final face in _batchUnknownFaces) {
      if (face.faceId.isNotEmpty) {
        byFaceId.putIfAbsent(face.faceId, () => face);
      }
    }
    return byFaceId.values.toList();
  }

  bool get isLoadingRecommendations => _isLoadingRecommendations;
  bool get isSyncingContacts => _isSyncingContacts;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get hasSynced => _hasSynced;
  bool get hasContactsPermission => _hasContactsPermission;

  /// True when the backend already has this user's phonebook stored.
  bool get hasBackendContacts => _hasBackendContacts;

  int get backendContactCount => _backendContactCount;

  /// Show sync CTA only when the backend phonebook column is empty.
  bool get shouldPromptContactSync => !_hasBackendContacts;

  /// On-platform suggestions excluding friends and already-sent requests.
  List<OnPlatformUser> get visibleOnPlatformRecommendations {
    final result = _contactSyncResult;
    if (result == null) return [];
    return result.onPlatform.where((user) {
      return !_isAlreadyFriend(user.userId, user.username) &&
          !_hasPendingSentTo(user.userId, user.username);
    }).toList();
  }

  bool _isAlreadyFriend(String userId, String username) {
    return _friends.any((f) => f.userId == userId || f.username == username);
  }

  bool _hasPendingSentTo(String userId, String username) {
    return _sentRequests.any(
      (r) =>
          r.userId == userId ||
          r.receiverId == userId ||
          r.username == username,
    );
  }

  /// Resolve how a user should appear in search / discovery cards.
  FriendshipDisplayStatus friendshipDisplayStatusFor({
    required String userId,
    required String username,
  }) {
    if (_isAlreadyFriend(userId, username)) {
      return FriendshipDisplayStatus.friend;
    }
    if (_hasPendingSentTo(userId, username)) {
      return FriendshipDisplayStatus.pendingSent;
    }
    return FriendshipDisplayStatus.none;
  }

  /// Merges batch API contacts with face matches cross-referenced against synced contacts.
  List<ReviewSuggestion> mergeBatchSuggestions({
    required List<ReviewSuggestion> fromBatch,
    required BatchStatusResponse batch,
    required String currentUserId,
  }) {
    final byUserId = {
      for (final suggestion in fromBatch) suggestion.userId: suggestion,
    };

    final onPlatform = _contactSyncResult?.onPlatform ?? const [];

    void addContactSuggestion({
      required String userId,
      required String username,
      String? profilePicId,
      String? contactName,
      required int photoCount,
    }) {
      if (userId == currentUserId || byUserId.containsKey(userId)) return;
      if (_isAlreadyFriend(userId, username)) return;
      if (batch.recipients.any((r) => r.userId == userId)) return;

      byUserId[userId] = ReviewSuggestion(
        userId: userId,
        username: username,
        profilePicId: profilePicId,
        contactName: contactName,
        photoCount: photoCount,
      );
    }

    for (final contact in batch.contacts) {
      if (contact.userId == currentUserId) continue;
      if (_isAlreadyFriend(contact.userId, contact.username)) continue;

      final platformUser = onPlatform
          .where((user) => user.userId == contact.userId)
          .firstOrNull;

      addContactSuggestion(
        userId: contact.userId,
        username: contact.username,
        profilePicId: contact.profilePicId ?? platformUser?.profilePicId,
        contactName: platformUser?.contactName,
        photoCount: batch.images
            .where(
              (image) =>
                  !batch.reviewIndex.unknownFaceImageIds.contains(image.id) &&
                  image.recognizedUserIds.contains(contact.userId),
            )
            .length,
      );
    }

    for (final userIds in batch.reviewIndex.explicitImageToUserIds.values) {
      for (final userId in userIds) {
        if (userId == currentUserId || byUserId.containsKey(userId)) continue;
        if (_isAlreadyFriend(userId, '')) continue;

        final platformUser = onPlatform
            .where((user) => user.userId == userId)
            .firstOrNull;
        if (platformUser == null) continue;

        addContactSuggestion(
          userId: userId,
          username: platformUser.username,
          profilePicId: platformUser.profilePicId,
          contactName: platformUser.contactName,
          photoCount: batch.images
              .where(
                (image) =>
                    !batch.reviewIndex.unknownFaceImageIds.contains(image.id) &&
                    image.recognizedUserIds.contains(userId),
              )
              .length,
        );
      }
    }

    for (final image in batch.images) {
      for (final face in image.detectedFaces ?? const <dynamic>[]) {
        final userId = BatchFaceParser.userId(face);
        if (userId == null || userId.isEmpty) continue;
        if (userId == currentUserId || byUserId.containsKey(userId)) continue;
        if (_isAlreadyFriend(userId, '')) continue;

        final platformUser = onPlatform
            .where((user) => user.userId == userId)
            .firstOrNull;
        if (platformUser == null) continue;

        addContactSuggestion(
          userId: userId,
          username: platformUser.username,
          profilePicId: platformUser.profilePicId,
          contactName: platformUser.contactName,
          photoCount: batch.images
              .where(
                (image) =>
                    !batch.reviewIndex.unknownFaceImageIds.contains(image.id) &&
                    image.recognizedUserIds.contains(userId),
              )
              .length,
        );
      }
    }

    final merged = byUserId.values.toList()
      ..sort((a, b) => b.photoCount.compareTo(a.photoCount));
    return visibleBatchSuggestions(merged);
  }

  /// Batch contact suggestions excluding friends, enriched with phonebook names.
  List<ReviewSuggestion> visibleBatchSuggestions(
    List<ReviewSuggestion> suggestions,
  ) {
    final onPlatform = _contactSyncResult?.onPlatform ?? [];

    return suggestions
        .where(
          (suggestion) =>
              friendshipDisplayStatusFor(
                userId: suggestion.userId,
                username: suggestion.username,
              ) !=
              FriendshipDisplayStatus.friend,
        )
        .map((suggestion) {
          final platformUser = onPlatform
              .where((user) => user.userId == suggestion.userId)
              .firstOrNull;

          if (platformUser == null) return suggestion;

          return ReviewSuggestion(
            userId: suggestion.userId,
            username: suggestion.username,
            profilePicId: suggestion.profilePicId ?? platformUser.profilePicId,
            contactName: platformUser.contactName,
            photoCount: suggestion.photoCount,
          );
        })
        .toList();
  }

  /// Keep friendship lists fresh while searching without spamming the API.
  Future<void> syncFriendshipsIfStale(
    String userId, {
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _lastFriendshipSyncAt != null &&
        now.difference(_lastFriendshipSyncAt!) < const Duration(seconds: 8)) {
      return;
    }
    _lastFriendshipSyncAt = now;
    await fetchFriends(userId, showLoading: false);
  }

  void _removeFromOnPlatformRecommendations({
    required String username,
    String? userId,
  }) {
    if (_contactSyncResult == null) return;
    _contactSyncResult = ContactSyncResult(
      onPlatform: _contactSyncResult!.onPlatform
          .where(
            (u) =>
                u.username != username &&
                (userId == null || u.userId != userId),
          )
          .toList(),
      notOnPlatform: _contactSyncResult!.notOnPlatform,
      unknownFaceRecommendations:
          _contactSyncResult!.unknownFaceRecommendations,
    );
  }

  // Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Set searching state
  void _setSearching(bool value) {
    _isSearching = value;
    notifyListeners();
  }

  // Set error
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> _ensureAuthenticated() async {
    if (!await _apiClient.ensureAuthenticated()) {
      _setError('Your session has expired. Please log in again.');
      return false;
    }
    return true;
  }

  /// Fetch all friends and parse into accepted/pending/sent
  /// The /friends endpoint returns ALL friendships, so we filter them
  Future<void> fetchFriends(String userId, {bool showLoading = true}) async {
    if (!await _ensureAuthenticated()) return;

    try {
      if (showLoading) {
        _setLoading(true);
      }
      _setError(null);

      final data = await _apiClient.getFriends();

      // Parse and separate friendships
      final List<Friend> acceptedFriends = [];
      final List<FriendRequest> pendingReceived = [];
      final List<FriendRequest> pendingSent = [];

      for (var json in data) {
        final status =
            json['friendship_status'] ?? json['status'] ?? 'accepted';
        final requesterId = json['requester_id'] ?? '';
        final receiverId = json['receiver_id'] ?? json['addressee_id'] ?? '';

        if (status == 'accepted') {
          // Accepted friend - add to friends list
          acceptedFriends.add(Friend.fromJson(json));
        } else if (status == 'pending') {
          // Pending request - determine if sent or received
          if (requesterId == userId) {
            // User sent this request
            pendingSent.add(FriendRequest.fromJson(json));
          } else if (receiverId == userId) {
            // User received this request
            pendingReceived.add(FriendRequest.fromJson(json));
          }
        }
      }

      // Fetch pending received requests from /friends/pending endpoint
      try {
        final pendingData = await _apiClient.getPendingRequests();
        for (var json in pendingData) {
          pendingReceived.add(FriendRequest.fromJson(json));
        }
      } catch (e) {
        debugPrint('Error fetching pending requests: $e');
      }

      // Fetch sent requests separately from /friends/sent endpoint
      try {
        final sentData = await _apiClient.getSentRequests();
        for (var json in sentData) {
          pendingSent.add(FriendRequest.fromJson(json));
        }
      } catch (e) {
        debugPrint('Error fetching sent requests: $e');
      }

      _friends = acceptedFriends;
      _pendingRequests = _dedupeFriendRequests(pendingReceived);
      _sentRequests = _dedupeFriendRequests(pendingSent);

      if (showLoading) {
        _setLoading(false);
      } else {
        notifyListeners();
      }
    } on ApiException catch (e) {
      _setError(e.message);
      if (showLoading) {
        _setLoading(false);
      } else {
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to fetch friends: ${e.toString()}');
      if (showLoading) {
        _setLoading(false);
      } else {
        notifyListeners();
      }
    }
  }

  List<FriendRequest> _dedupeFriendRequests(List<FriendRequest> requests) {
    final seen = <String>{};
    final deduped = <FriendRequest>[];
    for (final request in requests) {
      final key = request.friendshipId.isNotEmpty
          ? request.friendshipId
          : '${request.requesterId}:${request.receiverId}';
      if (seen.add(key)) {
        deduped.add(request);
      }
    }
    return deduped;
  }

  /// Search users by username
  Future<void> searchUsers(String username, String userId) async {
    if (username.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    if (!await _ensureAuthenticated()) return;

    try {
      _setSearching(true);
      _setError(null);

      final results = await Future.wait([
        _apiClient.searchUsers(username: username),
        syncFriendshipsIfStale(userId),
      ]);
      final data = results.first as List<dynamic>;
      _searchResults = data.map((json) => Friend.fromJson(json)).toList();

      _setSearching(false);
    } on ApiException catch (e) {
      _setError(e.message);
      _setSearching(false);
    } catch (e) {
      _setError('Failed to search users: ${e.toString()}');
      _setSearching(false);
    }
  }

  /// Clear search results
  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  /// Send friend request
  Future<bool> sendFriendRequest(String userId, String targetUsername) async {
    if (!await _ensureAuthenticated()) return false;

    try {
      _setError(null);

      final response = await _apiClient.sendFriendRequest(
        targetUsername: targetUsername,
      );

      final addresseeId = response['addressee_id']?.toString() ?? '';

      // Pull profile pic from discovery list when available
      String? profilePicId;
      for (final u in _contactSyncResult?.onPlatform ?? []) {
        if (u.username == targetUsername || u.userId == addresseeId) {
          profilePicId = u.profilePicId;
          break;
        }
      }

      final tempRequest = FriendRequest(
        friendshipId: response['friendship_id']?.toString() ?? '',
        userId: addresseeId,
        username: targetUsername,
        profilePicId: profilePicId,
        firstName: null,
        lastName: null,
        createdAt: DateTime.now(),
        status: 'pending',
        requesterId: userId,
        receiverId: addresseeId,
      );

      final alreadySent = _sentRequests.any(
        (r) => r.username == targetUsername || r.userId == addresseeId,
      );
      if (!alreadySent) {
        _sentRequests.add(tempRequest);
      }

      _removeFromOnPlatformRecommendations(
        username: targetUsername,
        userId: addresseeId.isNotEmpty ? addresseeId : null,
      );
      notifyListeners();

      await fetchFriends(userId, showLoading: false);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _setError('Failed to send friend request: ${e.toString()}');
      notifyListeners();
      return false;
    }
  }

  /// Accept friend request
  Future<bool> acceptFriendRequest(String friendshipId, String userId) async {
    if (!await _ensureAuthenticated()) return false;

    FriendRequest? removedRequest;
    var removedIndex = -1;

    try {
      _setError(null);

      removedIndex = _pendingRequests.indexWhere(
        (r) => r.friendshipId == friendshipId,
      );
      if (removedIndex != -1) {
        removedRequest = _pendingRequests.removeAt(removedIndex);
        notifyListeners();
      }

      await _apiClient.acceptFriendRequest(
        friendshipId: friendshipId,
      );

      await fetchFriends(userId, showLoading: false);

      return true;
    } on ApiException catch (e) {
      if (removedRequest != null && removedIndex != -1) {
        _pendingRequests.insert(
          removedIndex.clamp(0, _pendingRequests.length),
          removedRequest,
        );
      }
      _setError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      if (removedRequest != null && removedIndex != -1) {
        _pendingRequests.insert(
          removedIndex.clamp(0, _pendingRequests.length),
          removedRequest,
        );
      }
      _setError('Failed to accept friend request: ${e.toString()}');
      notifyListeners();
      return false;
    }
  }

  /// Reject friend request
  Future<bool> rejectFriendRequest(String friendshipId, String userId) async {
    if (!await _ensureAuthenticated()) return false;

    FriendRequest? removedRequest;
    var removedIndex = -1;

    try {
      _setError(null);

      removedIndex = _pendingRequests.indexWhere(
        (r) => r.friendshipId == friendshipId,
      );
      if (removedIndex != -1) {
        removedRequest = _pendingRequests.removeAt(removedIndex);
        notifyListeners();
      }

      await _apiClient.rejectFriendRequest(
        friendshipId: friendshipId,
      );

      await fetchFriends(userId, showLoading: false);

      return true;
    } on ApiException catch (e) {
      if (removedRequest != null && removedIndex != -1) {
        _pendingRequests.insert(
          removedIndex.clamp(0, _pendingRequests.length),
          removedRequest,
        );
      }
      _setError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      if (removedRequest != null && removedIndex != -1) {
        _pendingRequests.insert(
          removedIndex.clamp(0, _pendingRequests.length),
          removedRequest,
        );
      }
      _setError('Failed to reject friend request: ${e.toString()}');
      notifyListeners();
      return false;
    }
  }

  /// Refresh all friend data (now handled by single fetchFriends call)
  Future<void> loadBatchUnknownFaces(String userId) async {
    _batchUnknownFaces = await BatchUnknownFacesStore.load(userId);
    notifyListeners();
  }

  Future<void> refreshAll(String userId) async {
    await Future.wait([
      fetchFriends(userId),
      loadRecommendations(userId),
      loadBatchUnknownFaces(userId),
    ]);
  }

  /// Toggle keep status for auto clean
  Future<bool> toggleKeepUser(
    String friendId,
    String userId,
    bool currentlyKept,
  ) async {
    if (!await _ensureAuthenticated()) return false;

    try {
      _setError(null);

      // Determine keep status to send
      final keepStatus = currentlyKept ? 'remove' : 'keep';

      await _apiClient.updateAutoCleanKeep(
        friendId: friendId,
        keepStatus: keepStatus,
      );

      // Refresh friends to get updated keep status
      await fetchFriends(userId);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to update keep status: ${e.toString()}');
      return false;
    }
  }

  /// Get blocked users
  List<BlockedUser> _blockedUsers = [];
  List<BlockedUser> get blockedUsers => _blockedUsers;

  Future<void> fetchBlockedUsers(String userId) async {
    if (!await _ensureAuthenticated()) return;

    try {
      _setLoading(true);
      _setError(null);

      final data = await _apiClient.getBlockedUsers();
      _blockedUsers = data.map((json) => BlockedUser.fromJson(json)).toList();

      _setLoading(false);
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
    } catch (e) {
      _setError('Failed to fetch blocked users: ${e.toString()}');
      _setLoading(false);
    }
  }

  /// Block a user
  Future<bool> blockUser(String friendId, String userId) async {
    if (!await _ensureAuthenticated()) return false;

    try {
      _setError(null);

      await _apiClient.blockUser(friendId: friendId);

      // Refresh friends and blocked users
      await fetchBlockedUsers(userId);
      await fetchFriends(userId);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to block user: ${e.toString()}');
      return false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String friendId, String userId) async {
    if (!await _ensureAuthenticated()) return false;

    try {
      _setError(null);

      await _apiClient.unblockUser(friendId: friendId);

      // Refresh blocked users
      await fetchBlockedUsers(userId);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to unblock user: ${e.toString()}');
      return false;
    }
  }

  /// Unfriend a user
  Future<bool> unfriend(String friendId, String userId) async {
    if (!await _ensureAuthenticated()) return false;

    try {
      _setError(null);

      await _apiClient.unfriend(friendId: friendId);

      // Refresh friends
      await fetchFriends(userId);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to unfriend user: ${e.toString()}');
      return false;
    }
  }
  // ==================== V2 CONTACT DISCOVERY METHODS ====================

  /// Load discovery data: check backend sync-status first, then fetch recommendations
  /// from GET /contacts/recommendations when the phonebook is already stored.
  Future<void> loadRecommendations(String userId) async {
    try {
      _isLoadingRecommendations = true;
      _setError(null);
      notifyListeners();

      if (!await _apiClient.ensureAuthenticated()) {
        _setError('Your session has expired. Please log in again.');
        return;
      }

      _hasContactsPermission = await _contactService.hasContactsPermission();
      final syncStatus = await _contactService.getContactSyncStatus(userId);
      _backendContactCount = syncStatus.contactCount;
      _hasBackendContacts = syncStatus.hasStoredContacts;

      if (_hasBackendContacts) {
        final result = await _contactService.getRecommendations(userId);
        if (result != null) {
          _contactSyncResult = result;
        }
        _hasSynced = true;
        _lastSyncedAt = _parseLastSyncedAt(syncStatus.lastSyncedAt);
      } else {
        _contactSyncResult = null;
        _hasSynced = false;
      }
    } catch (e) {
      _setError('Failed to load recommendations: ${e.toString()}');
    } finally {
      _isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  /// Full sync: reads phonebook → POST /contacts/sync → updates discovery lists.
  /// If the backend already stores the phonebook, skips upload and refreshes from
  /// GET /contacts/recommendations instead.
  Future<ContactSyncOutcome> syncAndGetRecommendations(
    String userId, {
    String? accountCountryCode,
    String? accountPhone,
    String? accountDisplayName,
  }) async {
    try {
      _isSyncingContacts = true;
      _setError(null);
      notifyListeners();

      if (!await _apiClient.ensureAuthenticated()) {
        _setError('Your session has expired. Please log in again.');
        return const ContactSyncOutcome(issue: ContactSyncIssue.uploadFailed);
      }

      final existingStatus = await _contactService.getContactSyncStatus(userId);
      _backendContactCount = existingStatus.contactCount;
      _hasBackendContacts = existingStatus.hasStoredContacts;

      if (_hasBackendContacts) {
        final result = await _contactService.getRecommendations(userId);
        if (result != null) {
          _contactSyncResult = result;
          _hasSynced = true;
          _lastSyncedAt = _parseLastSyncedAt(existingStatus.lastSyncedAt);
          return ContactSyncOutcome(result: result);
        }
        _setError('Could not load contacts from the server. Please try again.');
        return const ContactSyncOutcome(issue: ContactSyncIssue.uploadFailed);
      }

      final outcome = await _contactService.requestPermissionAndSyncContacts(
        userId,
        accountCountryCode: accountCountryCode,
        accountPhone: accountPhone,
        accountDisplayName: accountDisplayName,
      );

      final result = outcome.result;
      if (result != null) {
        _contactSyncResult = result;
        _lastSyncedAt = DateTime.now();
        _hasContactsPermission = true;

        final syncStatus = await _contactService.getContactSyncStatus(userId);
        _backendContactCount = syncStatus.contactCount;
        _hasBackendContacts = syncStatus.hasStoredContacts;
        if (_hasBackendContacts) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('contacts_synced_$userId', true);
          _hasSynced = true;
        }
      } else {
        _hasContactsPermission =
            await _contactService.hasContactsPermission();
        final syncStatus = await _contactService.getContactSyncStatus(userId);
        _backendContactCount = syncStatus.contactCount;
        _hasBackendContacts = syncStatus.hasStoredContacts;
        if (_hasBackendContacts) {
          final refreshed = await _contactService.getRecommendations(userId);
          if (refreshed != null) {
            _contactSyncResult = refreshed;
            _hasSynced = true;
            _lastSyncedAt = _parseLastSyncedAt(syncStatus.lastSyncedAt);
          }
        }
        if (outcome.issue == ContactSyncIssue.permissionDenied) {
          _setError('Contacts permission is required to sync your phonebook.');
        } else if (outcome.issue == ContactSyncIssue.noContacts) {
          _setError('No contacts found on this device to sync.');
        } else if (outcome.issue == ContactSyncIssue.uploadFailed) {
          if (_hasBackendContacts && _contactSyncResult != null) {
            _setError(null);
            return ContactSyncOutcome(result: _contactSyncResult);
          } else {
            _setError('Could not upload contacts. Please try again.');
          }
        }
      }

      return outcome;
    } catch (e) {
      _setError('Failed to sync contacts: ${e.toString()}');
      return const ContactSyncOutcome(issue: ContactSyncIssue.uploadFailed);
    } finally {
      _isSyncingContacts = false;
      notifyListeners();
    }
  }

  DateTime? _parseLastSyncedAt(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  /// Tell backend about permission state change
  Future<void> updateSyncStatus(String userId, String status) async {
    try {
      await _contactService.updateSyncStatus(userId, status);
    } catch (e) {
      debugPrint('[FriendsProvider] Error updating sync status: $e');
    }
  }

  /// Permanently dismiss a "People You May Know" card (V2.2)
  Future<bool> dismissRecommendation(
    String userId,
    String dismissedUserId,
  ) async {
    if (!await _ensureAuthenticated()) return false;

    try {
      _setError(null);
      await _apiClient.dismissRecommendation(
        dismissedUserId: dismissedUserId,
      );

      if (_contactSyncResult != null) {
        _contactSyncResult = ContactSyncResult(
          onPlatform: _contactSyncResult!.onPlatform
              .where((u) => u.userId != dismissedUserId)
              .toList(),
          notOnPlatform: _contactSyncResult!.notOnPlatform,
          unknownFaceRecommendations:
              _contactSyncResult!.unknownFaceRecommendations,
        );
      }
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to dismiss suggestion: ${e.toString()}');
      return false;
    }
  }
}
