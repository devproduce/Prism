import 'package:flutter/material.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/friend_model.dart';
import 'package:prism/models/contact_sync_result.dart';
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
  bool get isLoadingRecommendations => _isLoadingRecommendations;
  bool get isSyncingContacts => _isSyncingContacts;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get hasSynced => _hasSynced;

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
    return _friends.any(
      (f) => f.userId == userId || f.username == username,
    );
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

  /// Keep friendship lists fresh while searching without spamming the API.
  Future<void> syncFriendshipsIfStale(
    String userId, {
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _lastFriendshipSyncAt != null &&
        now.difference(_lastFriendshipSyncAt!) <
            const Duration(seconds: 8)) {
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
            (u) => u.username != username && (userId == null || u.userId != userId),
          )
          .toList(),
      notOnPlatform: _contactSyncResult!.notOnPlatform,
      unknownFaceRecommendations: _contactSyncResult!.unknownFaceRecommendations,
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

  /// Fetch all friends and parse into accepted/pending/sent
  /// The /friends endpoint returns ALL friendships, so we filter them
  Future<void> fetchFriends(String userId, {bool showLoading = true}) async {
    try {
      if (showLoading) {
        _setLoading(true);
      }
      _setError(null);

      final data = await _apiClient.getFriends(userId: userId);

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
        final pendingData = await _apiClient.getPendingRequests(userId: userId);
        for (var json in pendingData) {
          pendingReceived.add(FriendRequest.fromJson(json));
        }
      } catch (e) {
        debugPrint('Error fetching pending requests: $e');
      }

      // Fetch sent requests separately from /friends/sent endpoint
      try {
        final sentData = await _apiClient.getSentRequests(userId: userId);
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

    try {
      _setSearching(true);
      _setError(null);

      final results = await Future.wait([
        _apiClient.searchUsers(username: username, userId: userId),
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
    try {
      _setError(null);

      final response = await _apiClient.sendFriendRequest(
        userId: userId,
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
        userId: userId,
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
        userId: userId,
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
  Future<void> refreshAll(String userId) async {
    await Future.wait([
      fetchFriends(userId),
      loadRecommendations(userId),
    ]);
  }

  /// Toggle keep status for auto clean
  Future<bool> toggleKeepUser(
    String friendId,
    String userId,
    bool currentlyKept,
  ) async {
    try {
      _setError(null);

      // Determine keep status to send
      final keepStatus = currentlyKept ? 'remove' : 'keep';

      await _apiClient.updateAutoCleanKeep(
        friendId: friendId,
        userId: userId,
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
    try {
      _setLoading(true);
      _setError(null);

      final data = await _apiClient.getBlockedUsers(userId: userId);
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
    try {
      _setError(null);

      await _apiClient.blockUser(friendId: friendId, userId: userId);

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
    try {
      _setError(null);

      await _apiClient.unblockUser(friendId: friendId, userId: userId);

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
    try {
      _setError(null);

      await _apiClient.unfriend(friendId: friendId, userId: userId);

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

  /// Load cached recommendations from backend (no phonebook re-read)
  Future<void> loadRecommendations(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSynced = prefs.getBool('contacts_synced_$userId') ?? false;
      notifyListeners();
      
      if (!_hasSynced) return;

      _isLoadingRecommendations = true;
      _setError(null);
      notifyListeners();

      final result = await _contactService.getRecommendations(userId);
      if (result != null) {
        _contactSyncResult = result;
      }
    } catch (e) {
      _setError('Failed to load recommendations: ${e.toString()}');
    } finally {
      _isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  /// Full sync: reads phonebook → POST /contacts/sync → updates discovery lists
  Future<ContactSyncResult?> syncAndGetRecommendations(String userId) async {
    try {
      _isSyncingContacts = true;
      _setError(null);
      notifyListeners();

      final result = await _contactService.requestPermissionAndSyncContacts(
        userId,
      );

      if (result != null) {
        _contactSyncResult = result;
        _lastSyncedAt = DateTime.now();
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('contacts_synced_$userId', true);
        _hasSynced = true;
      }

      return result;
    } catch (e) {
      _setError('Failed to sync contacts: ${e.toString()}');
      return null;
    } finally {
      _isSyncingContacts = false;
      notifyListeners();
    }
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
    try {
      _setError(null);
      await _apiClient.dismissRecommendation(
        userId: userId,
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
