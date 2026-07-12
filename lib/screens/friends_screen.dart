import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/friend_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prism/models/contact_sync_result.dart';
import 'package:prism/screens/user_profile_screen.dart';
import 'package:prism/screens/collection_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/widgets/prism_text_field.dart';
import 'package:prism/widgets/empty_state_widget.dart';
import 'package:prism/widgets/shimmer_placeholder.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:prism/widgets/friendship_action_pill.dart';
import 'package:prism/widgets/unknown_faces_strip.dart';

class FriendsScreen extends StatefulWidget {
  final bool openRequestsDirectly;
  final String? initialSearchQuery;

  const FriendsScreen({
    super.key,
    this.openRequestsDirectly = false,
    this.initialSearchQuery,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _inviteSearchController = TextEditingController();
  String _inviteSearchQuery = '';
  Timer? _searchStatusRefreshTimer;

  @override
  void initState() {
    super.initState();

    // Fetch friends data on load
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final friendsProvider = Provider.of<FriendsProvider>(
        context,
        listen: false,
      );

      if (authProvider.currentUser != null &&
          await ApiClient().ensureAuthenticated()) {
        friendsProvider.refreshAll(authProvider.currentUser!.userId);
      }

      if (!mounted) return;

      if (widget.openRequestsDirectly) {
        _showRequestsBottomSheet(context, friendsProvider, authProvider);
      }

      final initialQuery = widget.initialSearchQuery?.trim();
      final userId = authProvider.currentUser?.userId;
      if (initialQuery != null &&
          initialQuery.isNotEmpty &&
          userId != null &&
          await ApiClient().ensureAuthenticated()) {
        _searchController.text = initialQuery;
        setState(() {});
        _updateSearchStatusRefreshTimer(true);
        friendsProvider.searchUsers(initialQuery, userId);
      }
    });
  }

  @override
  void dispose() {
    _searchStatusRefreshTimer?.cancel();
    _inviteSearchController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearchStatusRefreshTimer(bool searchActive) {
    if (!searchActive) {
      _searchStatusRefreshTimer?.cancel();
      _searchStatusRefreshTimer = null;
      return;
    }

    if (_searchStatusRefreshTimer != null) return;

    _searchStatusRefreshTimer = Timer.periodic(const Duration(seconds: 12), (
      _,
    ) async {
      if (!mounted) return;
      final userId = context.read<AuthProvider>().currentUser?.userId;
      if (userId == null) return;
      if (!await ApiClient().ensureAuthenticated()) return;
      if (!mounted) return;
      context.read<FriendsProvider>().syncFriendshipsIfStale(
        userId,
        force: true,
      );
    });
  }

  Future<void> _syncContacts(
    FriendsProvider friendsProvider,
    AuthProvider authProvider,
  ) async {
    final userId = authProvider.currentUser?.userId;
    if (userId == null) return;

    HapticFeedback.mediumImpact();
    final user = authProvider.currentUser;
    final ownerName = user != null
        ? '${user.firstName} ${user.lastName ?? ''}'.trim()
        : '';

    final outcome = await friendsProvider.syncAndGetRecommendations(
      userId,
      accountCountryCode: user?.countryCode,
      accountPhone: user?.phoneNumber,
      accountDisplayName:
          ownerName.isNotEmpty ? ownerName : user?.username,
    );

    if (!mounted) return;

    if (outcome.isSuccess) {
      ErrorHandler.showSuccessSnackbar(
        context,
        message: 'Contacts synced successfully!',
      );
      return;
    }

    switch (outcome.issue) {
      case ContactSyncIssue.permissionDenied:
        final status = await Permission.contacts.status;
        if (!mounted) return;
        if (status.isPermanentlyDenied) {
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: PrismColors.surfaceGray,
              title: Text('Contacts permission', style: PrismTextStyles.h3),
              content: Text(
                'Prism needs access to your contacts to find friends. '
                'Enable Contacts permission in Settings.',
                style: PrismTextStyles.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: PrismTextStyles.button.copyWith(
                      color: PrismColors.secondaryText,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'Open Settings',
                    style: PrismTextStyles.button.copyWith(
                      color: PrismColors.prismYellow,
                    ),
                  ),
                ),
              ],
            ),
          );
          if (openSettings == true) {
            await openAppSettings();
          }
        } else {
          ErrorHandler.showErrorSnackbar(
            context,
            message:
                'Contacts permission is required. Tap Sync Contacts again to allow access.',
          );
        }
      case ContactSyncIssue.noContacts:
        ErrorHandler.showErrorSnackbar(
          context,
          message: 'No contacts found on this device to sync.',
        );
      case ContactSyncIssue.uploadFailed:
      case null:
        ErrorHandler.showErrorSnackbar(
          context,
          message: friendsProvider.error ??
              'Could not upload contacts. Please try again.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final friendsProvider = Provider.of<FriendsProvider>(context);

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text('Friends', style: PrismTextStyles.h2),
        backgroundColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Sync contacts',
            icon: friendsProvider.isSyncingContacts
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PrismColors.prismYellow,
                    ),
                  )
                : const Icon(
                    Icons.contacts_rounded,
                    color: PrismColors.prismYellow,
                  ),
            onPressed: friendsProvider.isSyncingContacts
                ? null
                : () => _syncContacts(friendsProvider, authProvider),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: PrismColors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (authProvider.currentUser != null) {
                friendsProvider.refreshAll(authProvider.currentUser!.userId);
              }
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.inbox_rounded, color: PrismColors.white),
                onPressed: () => _showRequestsBottomSheet(
                  context,
                  friendsProvider,
                  authProvider,
                ),
              ),
              if (friendsProvider.pendingRequests.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: PrismColors.destructiveRed,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${friendsProvider.pendingRequests.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: PrismTextField(
              controller: _searchController,
              hintText: 'Search by username...',
              prefixIcon: Icons.search_rounded,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: PrismColors.secondaryText,
                      ),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          friendsProvider.clearSearchResults();
                        });
                        _updateSearchStatusRefreshTimer(false);
                      },
                    )
                  : null,
              onChanged: (value) {
                setState(() {});
                _updateSearchStatusRefreshTimer(value.isNotEmpty);
                if (authProvider.currentUser != null) {
                  friendsProvider.searchUsers(
                    value,
                    authProvider.currentUser!.userId,
                  );
                }
              },
              onSubmitted: (value) async {
                if (value.isNotEmpty && authProvider.currentUser != null) {
                  final isPassword = await authProvider.verifyPassword(value);
                  if (!context.mounted) return;

                  if (isPassword) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CollectionDetailScreen(title: 'Archived'),
                      ),
                    );
                    _searchController.clear();
                    friendsProvider.clearSearchResults();
                  } else {
                    friendsProvider.searchUsers(
                      value,
                      authProvider.currentUser!.userId,
                    );
                  }
                }
              },
            ),
          ),

          if (_searchController.text.isEmpty)
            UnknownFacesStrip(faces: friendsProvider.displayUnknownFaces),

          Expanded(
            child: _searchController.text.isNotEmpty
                ? _buildSearchResults(friendsProvider, authProvider)
                : RefreshIndicator(
                    color: PrismColors.prismYellow,
                    backgroundColor: PrismColors.surfaceGray,
                    onRefresh: () async {
                      if (authProvider.currentUser != null) {
                        await friendsProvider.refreshAll(
                          authProvider.currentUser!.userId,
                        );
                      }
                    },
                    child: CustomScrollView(
                      // AlwaysScrollableScrollPhysics ensures pull-to-refresh
                      // works even when content is shorter than the viewport.
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // ── Sync banner + People You May Know ────────────────
                        SliverToBoxAdapter(
                          child: _buildDiscoverHeader(friendsProvider),
                        ),
                        _buildOnPlatformSliver(friendsProvider, authProvider),
                        // ── YOUR FRIENDS label ────────────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Text(
                              'YOUR FRIENDS',
                              style: PrismTextStyles.bodySmall.copyWith(
                                color: PrismColors.secondaryText,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                        // ── Friends list ─────────────────────────────────────
                        _buildFriendsSliver(friendsProvider, authProvider),
                        // ── Sync prompt (only when backend has no contacts) ──
                        SliverToBoxAdapter(
                          child: _buildSyncPromptBelowFriends(
                            friendsProvider,
                            authProvider,
                          ),
                        ),
                        // ── Invite to Prism header + search ──────────────────
                        SliverToBoxAdapter(
                          child: _buildInviteHeader(friendsProvider),
                        ),
                        // ── Invite contacts list ──────────────────────────────
                        _buildInviteSliver(friendsProvider, authProvider),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showRequestsBottomSheet(
    BuildContext context,
    FriendsProvider friendsProvider,
    AuthProvider authProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PrismColors.surfaceGray,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Consumer<FriendsProvider>(
          builder: (context, provider, _) {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                          color: PrismColors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text('Requests', style: PrismTextStyles.h3),
                      ),
                      TabBar(
                        indicatorColor: PrismColors.prismYellow,
                        labelColor: PrismColors.prismYellow,
                        unselectedLabelColor: PrismColors.secondaryText,
                        dividerColor: Colors.transparent,
                        tabs: [
                          Tab(
                            text:
                                'Received (${provider.pendingRequests.length})',
                          ),
                          Tab(text: 'Sent (${provider.sentRequests.length})'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildPendingRequestsTab(
                              provider,
                              auth,
                              scrollController,
                            ),
                            _buildSentRequestsTab(
                              provider,
                              auth,
                              scrollController,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Friends Sliver
  Widget _buildFriendsSliver(
    FriendsProvider provider,
    AuthProvider authProvider,
  ) {
    if (provider.isLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ShimmerLayouts.listItems(count: 5),
        ),
      );
    }

    if (provider.friends.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyStateWidget.noFriends(
          onFindFriends: () {
            // No action needed as search is available above
          },
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final friend = provider.friends[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildFriendCard(friend),
          );
        }, childCount: provider.friends.length),
      ),
    );
  }

  Widget _buildSearchResults(
    FriendsProvider provider,
    AuthProvider authProvider,
  ) {
    return provider.isSearching
        ? const Center(
            child: CircularProgressIndicator(color: PrismColors.prismYellow),
          )
        : provider.searchResults.isEmpty
        ? _buildEmptyState(
            'No users found',
            'Try a different username',
            Icons.search_off_rounded,
          )
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: provider.searchResults.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildSearchResultCard(
                provider.searchResults[index],
                provider,
                authProvider,
              );
            },
          );
  }

  // Pending Requests Tab
  Widget _buildPendingRequestsTab(
    FriendsProvider provider,
    AuthProvider authProvider,
    ScrollController scrollController,
  ) {
    if (provider.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ShimmerLayouts.listItems(count: 3),
      );
    }
    if (provider.pendingRequests.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.inbox_rounded,
        title: 'No pending requests',
        message: 'Friend requests you receive will appear here',
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: provider.pendingRequests.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildPendingRequestCard(
          provider.pendingRequests[index],
          provider,
          authProvider,
        );
      },
    );
  }

  // Sent Requests List
  Widget _buildSentRequestsTab(
    FriendsProvider provider,
    AuthProvider authProvider,
    ScrollController scrollController,
  ) {
    if (provider.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ShimmerLayouts.listItems(count: 3),
      );
    }
    if (provider.sentRequests.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.send_rounded,
        title: 'No sent requests',
        message: 'Requests you send will appear here',
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: provider.sentRequests.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildSentRequestCard(provider.sentRequests[index]);
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: PrismColors.inputGray),
          const SizedBox(height: 16),
          Text(
            title,
            style: PrismTextStyles.h3.copyWith(
              color: PrismColors.secondaryText,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: PrismTextStyles.bodySmall.copyWith(
                color: PrismColors.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Friend Card Widget
  Widget _buildFriendCard(Friend friend) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendsProvider = Provider.of<FriendsProvider>(
      context,
      listen: false,
    );
    final isKept = friend.keep != null && friend.keep!.isNotEmpty;

    return PrismCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: PrismColors.prismYellow.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: PrismColors.inputGray,
                backgroundImage: friend.profilePictureUrl.isNotEmpty
                    ? CachedNetworkImageProvider(friend.profilePictureUrl)
                    : null,
                child: friend.profilePictureUrl.isEmpty
                    ? Text(
                        friend.displayName[0].toUpperCase(),
                        style: const TextStyle(color: PrismColors.white),
                      )
                    : null,
              ),
            ),
            if (isKept)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: PrismColors.prismYellow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 10,
                    color: PrismColors.black,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          friend.displayName,
          style: PrismTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '@${friend.username}',
          style: PrismTextStyles.bodySmall.copyWith(
            color: PrismColors.secondaryText,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(
            Icons.more_vert_rounded,
            color: PrismColors.secondaryText,
          ),
          color: PrismColors.surfaceGray,
          onSelected: (value) async {
            if (authProvider.currentUser == null) return;
            switch (value) {
              case 'keep':
                await _handleToggleKeep(
                  friend.userId,
                  authProvider.currentUser!.userId,
                  isKept,
                  friend.displayName,
                  friendsProvider,
                );
                break;
              case 'block':
                await _handleBlockUser(
                  friend.userId,
                  authProvider.currentUser!.userId,
                  friend.displayName,
                  friendsProvider,
                );
                break;
              case 'remove':
                await _handleRemoveFriend(
                  friend.userId,
                  authProvider.currentUser!.userId,
                  friend.displayName,
                  friendsProvider,
                );
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'keep',
              child: Row(
                children: [
                  Icon(
                    isKept ? Icons.star_border_rounded : Icons.star_rounded,
                    color: PrismColors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isKept ? 'Un-favorite' : 'Favorite',
                    style: const TextStyle(color: PrismColors.white),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(
                    Icons.block,
                    color: PrismColors.destructiveRed,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Block',
                    style: TextStyle(color: PrismColors.destructiveRed),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(
                    Icons.person_remove,
                    color: PrismColors.secondaryText,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Remove',
                    style: TextStyle(color: PrismColors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(
                userId: friend.userId,
                username: friend.username,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResultCard(
    Friend user,
    FriendsProvider provider,
    AuthProvider authProvider,
  ) {
    final status = provider.friendshipDisplayStatusFor(
      userId: user.userId,
      username: user.username,
    );

    return PrismCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: PrismColors.inputGray,
          backgroundImage: user.profilePictureUrl.isNotEmpty
              ? CachedNetworkImageProvider(user.profilePictureUrl)
              : null,
          child: user.profilePictureUrl.isEmpty
              ? const Icon(Icons.person, color: PrismColors.secondaryText)
              : null,
        ),
        title: Text(user.displayName, style: PrismTextStyles.bodyLarge),
        subtitle: Text('@${user.username}', style: PrismTextStyles.bodySmall),
        trailing: FriendshipActionPill(
          status: status,
          onAddTap: status == FriendshipDisplayStatus.none
              ? () async {
                  if (authProvider.currentUser == null) return;
                  await provider.sendFriendRequest(
                    authProvider.currentUser!.userId,
                    user.username,
                  );
                }
              : null,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(
                userId: user.userId,
                username: user.username,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingRequestCard(
    FriendRequest request,
    FriendsProvider provider,
    AuthProvider authProvider,
  ) {
    return PrismCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(
                userId: request.userId,
                username: request.username,
              ),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: PrismColors.inputGray,
          backgroundImage: request.profilePictureUrl.isNotEmpty
              ? CachedNetworkImageProvider(request.profilePictureUrl)
              : null,
          child: request.profilePictureUrl.isEmpty
              ? const Icon(Icons.person, color: PrismColors.secondaryText)
              : null,
        ),
        title: Text(request.displayName, style: PrismTextStyles.bodyLarge),
        subtitle: Text(
          '@${request.username}',
          style: PrismTextStyles.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.check_circle_rounded,
                color: PrismColors.successGreen,
                size: 32,
              ),
              onPressed: () async {
                final success = await provider.acceptFriendRequest(
                  request.friendshipId,
                  authProvider.currentUser!.userId,
                );
                if (!context.mounted) return;
                if (!success && provider.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${provider.error}')),
                  );
                } else if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friend request accepted!')),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.cancel_rounded,
                color: PrismColors.destructiveRed,
                size: 32,
              ),
              onPressed: () async {
                final success = await provider.rejectFriendRequest(
                  request.friendshipId,
                  authProvider.currentUser!.userId,
                );
                if (!context.mounted) return;
                if (!success && provider.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${provider.error}')),
                  );
                } else if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friend request rejected!')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentRequestCard(FriendRequest request) {
    return PrismCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: PrismColors.inputGray,
          child: const Icon(Icons.person, color: PrismColors.secondaryText),
        ),
        title: Text(request.username, style: PrismTextStyles.bodyLarge),
        subtitle: Text(
          'Request Sent',
          style: PrismTextStyles.bodySmall.copyWith(
            color: PrismColors.secondaryText,
          ),
        ),
        trailing: const Icon(
          Icons.hourglass_empty_rounded,
          color: PrismColors.secondaryText,
        ),
      ),
    );
  }

  // ── "People You May Know" section header (non-list parts) ──
  Widget _buildDiscoverHeader(FriendsProvider provider) {
    final result = provider.contactSyncResult;
    final isLoadingRecs = provider.isLoadingRecommendations;

    final side = _discoverSidePadding(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(side, 8, side, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _discoverContentWidth(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoadingRecs)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                      color: PrismColors.prismYellow,
                    ),
                  ),
                )
              else if (provider.hasBackendContacts && result != null) ...[
                if (provider.visibleOnPlatformRecommendations.isNotEmpty)
                  _buildDiscoverSectionHeader(
                    'PEOPLE YOU MAY KNOW',
                    Icons.people_rounded,
                  ),
                if (result.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.people_outline_rounded,
                            color: PrismColors.secondaryText,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No suggestions yet',
                            style: PrismTextStyles.bodyLarge.copyWith(
                              color: PrismColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Re-sync after more of your contacts join Prism',
                            style: PrismTextStyles.bodySmall.copyWith(
                              color: PrismColors.secondaryText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "People You May Know" sliver — uses SliverChildListDelegate so Flutter
  /// knows the exact scroll extent and can lazily dispose off-screen renders.
  double _discoverSidePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 12;
    if (width <= 720) return 16;
    return ((width - 640) / 2).clamp(16, 80);
  }

  double _discoverContentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final side = _discoverSidePadding(context);
    return width - (side * 2);
  }

  Widget _buildOnPlatformSliver(
    FriendsProvider provider,
    AuthProvider authProvider,
  ) {
    final suggestions = provider.visibleOnPlatformRecommendations;
    if (suggestions.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final side = _discoverSidePadding(context);

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(side, 10, side, 8),
      sliver: SliverList(
        delegate: SliverChildListDelegate(
          suggestions
              .map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: _discoverContentWidth(context),
                      ),
                      child: _buildOnPlatformCard(user, provider, authProvider),
                    ),
                  ),
                ),
              )
              .toList(),
          addRepaintBoundaries: true,
        ),
      ),
    );
  }

  Widget _buildSyncPromptBelowFriends(
    FriendsProvider provider,
    AuthProvider authProvider,
  ) {
    if (provider.isLoadingRecommendations || provider.hasBackendContacts) {
      return const SizedBox.shrink();
    }

    final side = _discoverSidePadding(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(side, 16, side, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _discoverContentWidth(context)),
          child: PrismCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.contacts_rounded,
                        color: PrismColors.prismYellow,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Find friends from contacts',
                          style: PrismTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sync your phonebook to discover friends on Prism and invite others.',
                    style: PrismTextStyles.bodySmall.copyWith(
                      color: PrismColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: provider.isSyncingContacts
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: CircularProgressIndicator(
                                color: PrismColors.prismYellow,
                              ),
                            ),
                          )
                        : PrismButton(
                            text: 'Sync Contacts',
                            type: PrismButtonType.primary,
                            icon: Icons.sync_rounded,
                            onPressed: authProvider.currentUser == null
                                ? null
                                : () => _syncContacts(provider, authProvider),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── "Invite to Prism" section header + search bar (non-list parts) ────────
  Widget _buildInviteHeader(FriendsProvider provider) {
    final result = provider.contactSyncResult;
    final isLoadingRecs = provider.isLoadingRecommendations;

    if (isLoadingRecs || !provider.hasBackendContacts || result == null) {
      return const SizedBox.shrink();
    }

    final hasPhoneInvites = result.notOnPlatform.isNotEmpty;
    if (!hasPhoneInvites) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDiscoverSectionHeader(
            'INVITE TO PRISM',
            Icons.mail_outline_rounded,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _inviteSearchController,
            style: PrismTextStyles.bodyMedium,
            onChanged: (value) {
              setState(() {
                _inviteSearchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              hintStyle: PrismTextStyles.bodyMedium.copyWith(
                color: PrismColors.secondaryText,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: PrismColors.secondaryText,
              ),
              filled: true,
              fillColor: PrismColors.inputGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              suffixIcon: _inviteSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: PrismColors.secondaryText,
                      ),
                      onPressed: () {
                        _inviteSearchController.clear();
                        setState(() => _inviteSearchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// "Invite to Prism" sliver — uses SliverChildListDelegate so all contacts
  /// are present in the widget tree (correct scroll extent) while Flutter
  /// lazily disposes their render objects when off-screen.
  Widget _buildInviteSliver(
    FriendsProvider provider,
    AuthProvider authProvider,
  ) {
    final result = provider.contactSyncResult;
    final isLoadingRecs = provider.isLoadingRecommendations;

    if (isLoadingRecs ||
        !provider.hasBackendContacts ||
        result == null ||
        result.notOnPlatform.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final inviteTargets = result.notOnPlatform
        .where(
          (c) => c.displayName.toLowerCase().contains(
            _inviteSearchQuery.toLowerCase(),
          ),
        )
        .toList();

    if (inviteTargets.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No contacts found',
              style: TextStyle(color: PrismColors.secondaryText),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverList(
        delegate: SliverChildListDelegate(
          inviteTargets
              .map(
                (contact) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildInviteCard(contact, authProvider),
                ),
              )
              .toList(),
          addRepaintBoundaries: true,
        ),
      ),
    );
  }

  Widget _buildDiscoverSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: PrismColors.secondaryText),
        const SizedBox(width: 6),
        Text(
          title,
          style: PrismTextStyles.bodySmall.copyWith(
            color: PrismColors.secondaryText,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildOnPlatformCard(
    OnPlatformUser user,
    FriendsProvider provider,
    AuthProvider authProvider,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    final avatarRadius = isCompact ? 20.0 : 24.0;
    final cardPaddingH = isCompact ? 10.0 : 14.0;
    final cardPaddingV = isCompact ? 10.0 : 12.0;

    final status = provider.friendshipDisplayStatusFor(
      userId: user.userId,
      username: user.username,
    );
    final displayName = user.contactName?.trim().isNotEmpty == true
        ? user.contactName!.trim()
        : '@${user.username}';

    return PrismCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: cardPaddingH,
          vertical: cardPaddingV,
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        userId: user.userId,
                        username: user.username,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: PrismColors.inputGray,
                      backgroundImage: user.profilePictureUrl.isNotEmpty
                          ? CachedNetworkImageProvider(user.profilePictureUrl)
                          : null,
                      child: user.profilePictureUrl.isEmpty
                          ? Text(
                              user.username.isNotEmpty
                                  ? user.username[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: PrismColors.white),
                            )
                          : null,
                    ),
                    SizedBox(width: isCompact ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: PrismTextStyles.bodyLarge.copyWith(
                              fontSize: isCompact ? 14 : 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (user.contactName?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 2),
                            Text(
                              '@${user.username}',
                              style: PrismTextStyles.bodySmall.copyWith(
                                color: PrismColors.secondaryText,
                                fontSize: isCompact ? 11 : 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (user.mutualContactCount > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.people_outline_rounded,
                                  size: isCompact ? 12 : 13,
                                  color: PrismColors.secondaryText,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${user.mutualContactCount} mutual contact${user.mutualContactCount > 1 ? 's' : ''}',
                                    style: PrismTextStyles.bodySmall.copyWith(
                                      color: PrismColors.secondaryText,
                                      fontSize: isCompact ? 11 : 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (status != FriendshipDisplayStatus.friend &&
                status != FriendshipDisplayStatus.pendingSent)
              IconButton(
                tooltip: 'Dismiss suggestion',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: isCompact ? 32 : 40,
                  minHeight: isCompact ? 32 : 40,
                ),
                icon: Icon(
                  Icons.close_rounded,
                  color: PrismColors.secondaryText,
                  size: isCompact ? 18 : 20,
                ),
                onPressed: () async {
                  if (authProvider.currentUser == null) return;
                  HapticFeedback.selectionClick();
                  await provider.dismissRecommendation(
                    authProvider.currentUser!.userId,
                    user.userId,
                  );
                },
              ),
            FriendshipActionPill(
              status: status,
              style: isCompact
                  ? FriendshipActionStyle.compact
                  : FriendshipActionStyle.pill,
              onAddTap: status == FriendshipDisplayStatus.none
                  ? () async {
                      if (authProvider.currentUser == null) return;
                      final ok = await provider.sendFriendRequest(
                        authProvider.currentUser!.userId,
                        user.username,
                      );
                      if (!context.mounted) return;
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Request sent to @${user.username}',
                              style: PrismTextStyles.bodySmall.copyWith(
                                color: PrismColors.black,
                              ),
                            ),
                            backgroundColor: PrismColors.prismYellow,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else if (provider.error != null) {
                        ErrorHandler.showErrorSnackbar(
                          context,
                          message: provider.error!,
                        );
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard(
    NotOnPlatformContact contact,
    AuthProvider authProvider,
  ) {
    return PrismCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: PrismColors.inputGray,
          child: Text(
            contact.displayName.isNotEmpty
                ? contact.displayName[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: PrismColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(contact.displayName, style: PrismTextStyles.bodyLarge),
        subtitle: Text(
          'Not on Prism yet',
          style: PrismTextStyles.bodySmall.copyWith(
            color: PrismColors.secondaryText,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // WhatsApp invite
            if (contact.whatsappLink.isNotEmpty)
              _buildInviteButton(
                color: const Color(0xFF25D366),
                iconWidget: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  size: 16,
                  color: Color(0xFF25D366),
                ),
                onTap: () {
                  final username =
                      authProvider.currentUser?.username ?? 'Your friend';
                  final message =
                      "$username is on Prism , why dont you try it out with a link attached there www.prismapp.in";
                  final encodedMessage = Uri.encodeComponent(message);

                  String finalUrl = contact.whatsappLink;
                  if (finalUrl.contains('?')) {
                    // Strip any existing query parameters (like an old text= parameter)
                    finalUrl = finalUrl.split('?').first;
                  }
                  finalUrl = '$finalUrl?text=$encodedMessage';

                  _launchUrl(finalUrl);
                },
              ),
            if (contact.whatsappLink.isNotEmpty && contact.smsLink.isNotEmpty)
              const SizedBox(width: 8),
            // SMS invite
            if (contact.smsLink.isNotEmpty)
              _buildInviteButton(
                color: PrismColors.electricBlue,
                iconWidget: const Icon(
                  Icons.sms_rounded,
                  size: 16,
                  color: PrismColors.electricBlue,
                ),
                onTap: () {
                  final username =
                      authProvider.currentUser?.username ?? 'Your friend';
                  final message =
                      "$username is on Prism , why dont you try it out with a link attached there www.prismapp.in";
                  final encodedMessage = Uri.encodeComponent(message);

                  String finalUrl = contact.smsLink;
                  if (finalUrl.contains('?')) {
                    finalUrl = finalUrl.split('?').first;
                  }

                  // SMS uses 'body' parameter instead of 'text'
                  finalUrl = '$finalUrl?body=$encodedMessage';

                  _launchUrl(finalUrl);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteButton({
    required Color color,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: iconWidget,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[FriendsScreen] Could not launch URL: $url — $e');
    }
  }

  // Handle Toggle Keep Status (Existing Logic kept)
  Future<void> _handleToggleKeep(
    String friendId,
    String userId,
    bool isCurrentlyKept,
    String friendName,
    FriendsProvider friendsProvider,
  ) async {
    final success = await friendsProvider.toggleKeepUser(
      friendId,
      userId,
      isCurrentlyKept,
    );

    if (mounted) {
      if (success) {
        ErrorHandler.showSuccessSnackbar(
          context,
          message: isCurrentlyKept
              ? '$friendName removed from favorites'
              : '$friendName added to favorites',
        );
      } else {
        ErrorHandler.showErrorSnackbar(
          context,
          message: friendsProvider.error ?? 'Failed to update status',
        );
      }
    }
  }

  // Handle Block User
  Future<void> _handleBlockUser(
    String friendId,
    String userId,
    String friendName,
    FriendsProvider friendsProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PrismColors.surfaceGray,
        title: Text('Block User', style: PrismTextStyles.h3),
        content: Text(
          'Are you sure you want to block $friendName? They will be removed from your friends list.',
          style: PrismTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: PrismColors.secondaryText),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: PrismColors.destructiveRed,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await friendsProvider.blockUser(friendId, userId);

    if (mounted) {
      if (success) {
        ErrorHandler.showSuccessSnackbar(
          context,
          message: '$friendName has been blocked',
        );
      } else {
        ErrorHandler.showErrorSnackbar(
          context,
          message: friendsProvider.error ?? 'Failed to block user',
        );
      }
    }
  }

  // Handle Remove Friend
  // ... similar logic update for remove friend

  Future<void> _handleRemoveFriend(
    String friendId,
    String userId,
    String friendName,
    FriendsProvider friendsProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PrismColors.surfaceGray,
        title: Text('Remove Friend', style: PrismTextStyles.h3),
        content: Text(
          'Are you sure you want to remove $friendName from your friends list?',
          style: PrismTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: PrismColors.secondaryText),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: PrismColors.destructiveRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await friendsProvider.unfriend(friendId, userId);

    if (mounted) {
      if (success) {
        ErrorHandler.showSuccessSnackbar(
          context,
          message: '$friendName removed from friends',
        );
      } else {
        ErrorHandler.showErrorSnackbar(
          context,
          message: friendsProvider.error ?? 'Failed to remove friend',
        );
      }
    }
  }
}
