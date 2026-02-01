import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/models/friend_model.dart';
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

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Fetch friends data on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final friendsProvider = Provider.of<FriendsProvider>(
        context,
        listen: false,
      );

      if (authProvider.currentUser != null) {
        friendsProvider.refreshAll(authProvider.currentUser!.userId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
            icon: const Icon(Icons.refresh_rounded, color: PrismColors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (authProvider.currentUser != null) {
                friendsProvider.refreshAll(authProvider.currentUser!.userId);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            height: 44,
            width: double.infinity,
            decoration: BoxDecoration(
              color: PrismColors.surfaceGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 20),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: PrismColors.inputGray,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: PrismColors.white.withValues(alpha: 0.1),
                  ),
                ),
                labelColor: PrismColors.prismYellow, // Active Yellow
                unselectedLabelColor: PrismColors.secondaryText,
                labelStyle: PrismTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: PrismTextStyles.bodyMedium,
                tabs: const [
                  Tab(text: 'Friends'),
                  Tab(text: 'Add Friend'),
                  Tab(text: 'Requests'),
                  Tab(text: 'Sent'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsTab(friendsProvider, authProvider),
          _buildAddFriendTab(friendsProvider, authProvider),
          _buildPendingRequestsTab(friendsProvider, authProvider),
          _buildSentRequestsTab(friendsProvider, authProvider),
        ],
      ),
    );
  }

  // Friends Tab
  Widget _buildFriendsTab(FriendsProvider provider, AuthProvider authProvider) {
    if (provider.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ShimmerLayouts.listItems(count: 5),
      );
    }

    if (provider.friends.isEmpty) {
      return EmptyStateWidget.noFriends(
        onFindFriends: () {
          _tabController.animateTo(1);
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: provider.friends.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final friend = provider.friends[index];
        return _buildFriendCard(friend);
      },
    );
  }

  // Add Friend Tab
  Widget _buildAddFriendTab(
    FriendsProvider provider,
    AuthProvider authProvider,
  ) {
    return Column(
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
                        provider.clearSearchResults();
                      });
                    },
                  )
                : null,
            onChanged: (value) {
              setState(() {});
              if (authProvider.currentUser != null) {
                provider.searchUsers(value, authProvider.currentUser!.userId);
              }
            },
            onSubmitted: (value) async {
              if (value.isNotEmpty && authProvider.currentUser != null) {
                final isPassword = await authProvider.verifyPassword(value);
                if (mounted) {
                  if (isPassword) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const CollectionDetailScreen(title: 'Archived'),
                      ),
                    );
                    _searchController.clear();
                    provider.clearSearchResults();
                  } else {
                    provider.searchUsers(
                      value,
                      authProvider.currentUser!.userId,
                    );
                  }
                }
              }
            },
          ),
        ),

        // Search Results
        Expanded(
          child: provider.isSearching
              ? const Center(
                  child: CircularProgressIndicator(
                    color: PrismColors.prismYellow,
                  ),
                )
              : provider.searchResults.isEmpty &&
                    _searchController.text.isNotEmpty
              ? _buildEmptyState(
                  'No users found',
                  'Try a different username',
                  Icons.search_off_rounded,
                )
              : _searchController.text.isEmpty
              ? _buildEmptyState(
                  'Search for users',
                  'Find your friends on Prism',
                  Icons.person_search_rounded,
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
                ),
        ),
      ],
    );
  }

  // Pending Requests Tab
  Widget _buildPendingRequestsTab(
    FriendsProvider provider,
    AuthProvider authProvider,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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

  // Sent Requests Tab
  Widget _buildSentRequestsTab(
    FriendsProvider provider,
    AuthProvider authProvider,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
        trailing: IconButton(
          icon: const Icon(
            Icons.more_vert_rounded,
            color: PrismColors.secondaryText,
          ),
          onPressed: () {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final Offset position = box.localToGlobal(Offset.zero);
            showMenu<String>(
              context: context,
              position: RelativeRect.fromLTRB(
                position.dx + 250,
                position.dy,
                0,
                0,
              ),
              color: PrismColors.surfaceGray,
              items: [
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
            ).then((value) async {
              if (authProvider.currentUser == null || value == null) return;
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
            });
          },
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
    final isFriend = provider.friends.any((f) => f.userId == user.userId);
    final isPending = provider.sentRequests.any(
      (r) => r.receiverId == user.userId,
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
        trailing: isFriend
            ? const Icon(
                Icons.check_circle_rounded,
                color: PrismColors.successGreen,
              )
            : isPending
            ? Text(
                'Sent',
                style: PrismTextStyles.bodySmall.copyWith(
                  color: PrismColors.electricCyan,
                ),
              )
            : PrismButton(
                text: 'Add',
                width: 70,
                height: 32,
                type: PrismButtonType.primary,
                onPressed: () async {
                  if (authProvider.currentUser != null) {
                    await provider.sendFriendRequest(
                      authProvider.currentUser!.userId,
                      user.username,
                    );
                  }
                },
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
              onPressed: () => provider.acceptFriendRequest(
                request.friendshipId,
                authProvider.currentUser!.userId,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.cancel_rounded,
                color: PrismColors.destructiveRed,
                size: 32,
              ),
              onPressed: () => provider.rejectFriendRequest(
                request.friendshipId,
                authProvider.currentUser!.userId,
              ),
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
