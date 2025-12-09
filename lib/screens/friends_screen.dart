import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/models/friend_model.dart';
import 'package:prism/screens/user_profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';

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
    // No GradientScaffold, rely on Home background
    final authProvider = Provider.of<AuthProvider>(context);
    final friendsProvider = Provider.of<FriendsProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Friends',
          style: PrismTextStyles.h2,
        ),
        backgroundColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        automaticallyImplyLeading: false, // Managed by Home tabs usually
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () {
              if (authProvider.currentUser != null) {
                friendsProvider.refreshAll(authProvider.currentUser!.userId);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 50,
            decoration: BoxDecoration(
              color: PrismColors.glassDark,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: TabBar(
                controller: _tabController,
                isScrollable: true, // Keep scrollable for safe fit
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.zero, // Remove default padding that might cause offsetting
                labelPadding: const EdgeInsets.symmetric(horizontal: 20), // Consistent padding
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: PrismColors.purple.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: PrismColors.purple.withOpacity(0.5)),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: PrismTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
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
      return Center(child: CircularProgressIndicator(color: PrismColors.purple));
    }

    if (provider.friends.isEmpty) {
      return _buildEmptyState('No friends yet', 'Add friends to see them here', Icons.people_outline_rounded);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: provider.friends.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final friend = provider.friends[index];
        return _buildFriendCard(friend);
      },
    );
  }

  // Add Friend Tab
  Widget _buildAddFriendTab(FriendsProvider provider, AuthProvider authProvider) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: GlassCard(
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by username...',
                hintStyle: const TextStyle(color: Colors.white38),
                border: InputBorder.none,
                icon: const Icon(Icons.search_rounded, color: Colors.white54),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white54),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            provider.clearSearchResults();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {});
                if (authProvider.currentUser != null) {
                  provider.searchUsers(value, authProvider.currentUser!.userId);
                }
              },
            ),
          ),
        ),

        // Search Results
        Expanded(
          child: provider.isSearching
              ? Center(child: CircularProgressIndicator(color: PrismColors.purple))
              : provider.searchResults.isEmpty && _searchController.text.isNotEmpty
                  ? _buildEmptyState('No users found', 'Try a different username', Icons.search_off_rounded)
                  : _searchController.text.isEmpty
                      ? _buildEmptyState('Search for users', 'Find your friends on Prism', Icons.person_search_rounded)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: provider.searchResults.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildSearchResultCard(provider.searchResults[index], provider, authProvider);
                          },
                        ),
        ),
      ],
    );
  }

  // Pending Requests Tab
  Widget _buildPendingRequestsTab(FriendsProvider provider, AuthProvider authProvider) {
    if (provider.isLoading) return Center(child: CircularProgressIndicator(color: PrismColors.purple));
    if (provider.pendingRequests.isEmpty) return _buildEmptyState('No pending requests', '', Icons.inbox_rounded);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: provider.pendingRequests.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildPendingRequestCard(provider.pendingRequests[index], provider, authProvider);
      },
    );
  }

  // Sent Requests Tab
  Widget _buildSentRequestsTab(FriendsProvider provider, AuthProvider authProvider) {
    if (provider.isLoading) return Center(child: CircularProgressIndicator(color: PrismColors.purple));
    if (provider.sentRequests.isEmpty) return _buildEmptyState('No sent requests', '', Icons.send_rounded);

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
          Icon(icon, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(title, style: PrismTextStyles.h3.copyWith(color: Colors.white54)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: PrismTextStyles.bodySmall.copyWith(color: Colors.white38)),
          ],
        ],
      ),
    );
  }

  // Friend Card Widget
  Widget _buildFriendCard(Friend friend) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendsProvider = Provider.of<FriendsProvider>(context, listen: false);
    final isKept = friend.keep != null && friend.keep!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212B), // Deep solid color
        borderRadius: BorderRadius.circular(12), // Slightly smaller radius
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Compact padding
        leading: Stack(
          children: [
            Container(
              width: 44, 
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: PrismColors.primaryBlue.withOpacity(0.3), width: 1.5),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: PrismColors.darkCard,
                backgroundImage: friend.profilePictureUrl.isNotEmpty
                    ? CachedNetworkImageProvider(friend.profilePictureUrl)
                    : null,
                child: friend.profilePictureUrl.isEmpty
                    ? Text(friend.displayName[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                    : null,
              ),
            ),
            if (isKept)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: PrismColors.electricBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.push_pin_rounded, size: 10, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Text(
          friend.displayName, 
          style: PrismTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600, fontSize: 15)
        ),
        subtitle: Text(
          '@${friend.username}', 
          style: PrismTextStyles.bodySmall.copyWith(color: Colors.white54, fontSize: 13)
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () {
            // Show menu manually or use existing PopupMenu
             final RenderBox box = context.findRenderObject() as RenderBox;
             final Offset position = box.localToGlobal(Offset.zero);
             showMenu<String>(
              context: context,
              position: RelativeRect.fromLTRB(position.dx + 250, position.dy, 0, 0),
              color: PrismColors.darkCard,
              items: [
                PopupMenuItem(
                  value: 'keep', 
                  child: Row(
                    children: [
                       Icon(isKept ? Icons.push_pin_outlined : Icons.push_pin, color: Colors.white, size: 18),
                       const SizedBox(width: 8),
                       Text(isKept ? 'Unkeep' : 'Keep', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'block', 
                  child: Row(
                    children: [
                       Icon(Icons.block, color: PrismColors.errorRed, size: 18),
                       const SizedBox(width: 8),
                       Text('Block', style: TextStyle(color: PrismColors.errorRed)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove', 
                  child: Row(
                    children: [
                       Icon(Icons.person_remove, color: Colors.white70, size: 18),
                       const SizedBox(width: 8),
                       Text('Remove', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
             ).then((value) async {
                 if (authProvider.currentUser == null || value == null) return;
                 switch (value) {
                   case 'keep':
                     await _handleToggleKeep(friend.userId, authProvider.currentUser!.userId, isKept, friend.displayName, friendsProvider);
                     break;
                   case 'block': 
                      await _handleBlockUser(friend.userId, authProvider.currentUser!.userId, friend.displayName, friendsProvider);
                     break;
                   case 'remove': 
                      await _handleRemoveFriend(friend.userId, authProvider.currentUser!.userId, friend.displayName, friendsProvider);
                     break;
                 }
             });
          },
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
               builder: (context) => UserProfileScreen(userId: friend.userId, username: friend.username),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResultCard(Friend user, FriendsProvider provider, AuthProvider authProvider) {
    final isFriend = provider.friends.any((f) => f.userId == user.userId);
    final isPending = provider.sentRequests.any((r) => r.receiverId == user.userId);

    return GlassCard(
      borderRadius: 16,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white10,
          backgroundImage: user.profilePictureUrl.isNotEmpty ? CachedNetworkImageProvider(user.profilePictureUrl) : null,
          child: user.profilePictureUrl.isEmpty ? const Icon(Icons.person, color: Colors.white54) : null,
        ),
        title: Text(user.displayName, style: PrismTextStyles.bodyLarge),
        subtitle: Text('@${user.username}', style: PrismTextStyles.bodySmall),
        trailing: isFriend
            ? const Icon(Icons.check_circle_rounded, color: PrismColors.successGreen)
            : isPending
                ? Text('Sent', style: PrismTextStyles.bodySmall.copyWith(color: PrismColors.electricBlue))
                : GlassButton(
                    text: 'Add',
                    width: 70,
                    height: 32,
                    isPrimary: true,
                    onPressed: () async {
                       if (authProvider.currentUser != null) {
                         await provider.sendFriendRequest(authProvider.currentUser!.userId, user.username);
                       }
                    },
                  ),
        onTap: () {
           Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: user.userId, username: user.username)));
        },
      ),
    );
  }

  Widget _buildPendingRequestCard(FriendRequest request, FriendsProvider provider, AuthProvider authProvider) {
    return GlassCard(
      borderRadius: 16,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: request.profilePictureUrl.isNotEmpty ? CachedNetworkImageProvider(request.profilePictureUrl) : null,
           child: request.profilePictureUrl.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Text(request.displayName, style: PrismTextStyles.bodyLarge),
        subtitle: Text('@${request.username}', style: PrismTextStyles.bodySmall),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_rounded, color: PrismColors.successGreen, size: 32),
              onPressed: () => provider.acceptFriendRequest(request.friendshipId, authProvider.currentUser!.userId),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_rounded, color: PrismColors.errorRed, size: 32),
              onPressed: () => provider.rejectFriendRequest(request.friendshipId, authProvider.currentUser!.userId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentRequestCard(FriendRequest request) {
    return GlassCard(
      borderRadius: 16,
      child: ListTile(
        leading: CircleAvatar(child: const Icon(Icons.person)),
        title: Text(request.username, style: PrismTextStyles.bodyLarge),
        subtitle: Text('Request Sent', style: PrismTextStyles.bodySmall.copyWith(color: Colors.white54)),
        trailing: const Icon(Icons.hourglass_empty_rounded, color: Colors.white30),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? isCurrentlyKept
                      ? '$friendName removed from keep list'
                      : '$friendName added to keep list'
                : friendsProvider.error ?? 'Failed to update keep status',
            style: PrismTextStyles.bodyMedium,
          ),
          backgroundColor: success ? PrismColors.electricBlue : PrismColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        backgroundColor: PrismColors.darkCard,
        title: Text('Block User', style: PrismTextStyles.h3),
        content: Text(
          'Are you sure you want to block $friendName? They will be removed from your friends list.',
          style: PrismTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
             child: Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: PrismColors.errorRed),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await friendsProvider.blockUser(friendId, userId);
    // ... snackbar logic
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
        title: const Text('Remove Friend'),
        content: Text(
          'Are you sure you want to remove $friendName from your friends list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '$friendName removed from friends'
                : friendsProvider.error ?? 'Failed to remove friend',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
