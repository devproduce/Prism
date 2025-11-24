import 'package:flutter/material.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/friend_model.dart';

class FriendsProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<Friend> _friends = [];
  List<FriendRequest> _pendingRequests = [];
  List<FriendRequest> _sentRequests = [];
  List<Friend> _searchResults = [];

  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;

  // Getters
  List<Friend> get friends => _friends;
  List<FriendRequest> get pendingRequests => _pendingRequests;
  List<FriendRequest> get sentRequests => _sentRequests;
  List<Friend> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;

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
  Future<void> fetchFriends(String userId) async {
    try {
      _setLoading(true);
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
      _pendingRequests = pendingReceived;
      _sentRequests = pendingSent;

      _setLoading(false);
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
    } catch (e) {
      _setError('Failed to fetch friends: ${e.toString()}');
      _setLoading(false);
    }
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

      final data = await _apiClient.searchUsers(
        username: username,
        userId: userId,
      );
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

      await _apiClient.sendFriendRequest(
        userId: userId,
        targetUsername: targetUsername,
      );

      // Refresh friends (includes sent requests)
      await fetchFriends(userId);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to send friend request: ${e.toString()}');
      return false;
    }
  }

  /// Accept friend request
  Future<bool> acceptFriendRequest(String friendshipId, String userId) async {
    try {
      _setError(null);

      await _apiClient.acceptFriendRequest(
        friendshipId: friendshipId,
        userId: userId,
      );

      // Refresh friends (includes pending requests)
      await fetchFriends(userId);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to accept friend request: ${e.toString()}');
      return false;
    }
  }

  /// Reject friend request
  Future<bool> rejectFriendRequest(String friendshipId, String userId) async {
    try {
      _setError(null);

      await _apiClient.rejectFriendRequest(
        friendshipId: friendshipId,
        userId: userId,
      );

      // Refresh friends (includes pending requests)
      await fetchFriends(userId);

      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to reject friend request: ${e.toString()}');
      return false;
    }
  }

  /// Refresh all friend data (now handled by single fetchFriends call)
  Future<void> refreshAll(String userId) async {
    await fetchFriends(userId);
  }
}
