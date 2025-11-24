import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/models/friend_model.dart';
import 'package:prism/utils/theme.dart';

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
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context);
    final friendsProvider = Provider.of<FriendsProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground(context),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.horizontalPadding(context),
                vertical: size.height * 0.015,
              ),
              child: Row(
                children: [
                  Text(
                    'Friends',
                    style: AppTheme.headlineStyle(
                      context,
                    ).copyWith(fontSize: size.width * 0.06),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: AppTheme.primaryText(context),
                      size: size.width * 0.06,
                    ),
                    onPressed: () {
                      if (authProvider.currentUser != null) {
                        friendsProvider.refreshAll(
                          authProvider.currentUser!.userId,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: AppTheme.horizontalPadding(context),
              ),
              decoration: BoxDecoration(
                color: AppTheme.darkDotInactive.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.primaryAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.secondaryText(context),
                labelStyle: TextStyle(
                  fontSize: size.width * 0.032,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: size.width * 0.032,
                  fontWeight: FontWeight.normal,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Friends'),
                  Tab(text: 'Add Friend'),
                  Tab(text: 'Requests'),
                  Tab(text: 'Sent'),
                ],
              ),
            ),

            SizedBox(height: size.height * 0.02),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFriendsTab(friendsProvider, authProvider, size),
                  _buildAddFriendTab(friendsProvider, authProvider, size),
                  _buildPendingRequestsTab(friendsProvider, authProvider, size),
                  _buildSentRequestsTab(friendsProvider, authProvider, size),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Friends Tab
  Widget _buildFriendsTab(
    FriendsProvider provider,
    AuthProvider authProvider,
    Size size,
  ) {
    if (provider.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryAccent),
      );
    }

    if (provider.friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: size.width * 0.2,
              color: AppTheme.tertiaryText(context),
            ),
            SizedBox(height: size.height * 0.02),
            Text(
              'No friends yet',
              style: TextStyle(
                color: AppTheme.secondaryText(context),
                fontSize: size.width * 0.04,
              ),
            ),
            SizedBox(height: size.height * 0.01),
            Text(
              'Add friends to see them here',
              style: TextStyle(
                color: AppTheme.tertiaryText(context),
                fontSize: size.width * 0.035,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.horizontalPadding(context),
      ),
      itemCount: provider.friends.length,
      itemBuilder: (context, index) {
        final friend = provider.friends[index];
        return _buildFriendCard(friend, size);
      },
    );
  }

  // Add Friend Tab
  Widget _buildAddFriendTab(
    FriendsProvider provider,
    AuthProvider authProvider,
    Size size,
  ) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.horizontalPadding(context),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: AppTheme.primaryText(context)),
            decoration: InputDecoration(
              hintText: 'Search by username...',
              hintStyle: TextStyle(color: AppTheme.tertiaryText(context)),
              filled: true,
              fillColor: AppTheme.darkDotInactive,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AppTheme.tertiaryText(context),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: AppTheme.tertiaryText(context),
                      ),
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

        SizedBox(height: size.height * 0.02),

        // Search Results
        Expanded(
          child: provider.isSearching
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryAccent,
                  ),
                )
              : provider.searchResults.isEmpty &&
                    _searchController.text.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: size.width * 0.15,
                        color: AppTheme.tertiaryText(context),
                      ),
                      SizedBox(height: size.height * 0.02),
                      Text(
                        'No users found',
                        style: TextStyle(
                          color: AppTheme.secondaryText(context),
                          fontSize: size.width * 0.04,
                        ),
                      ),
                    ],
                  ),
                )
              : _searchController.text.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search,
                        size: size.width * 0.15,
                        color: AppTheme.tertiaryText(context),
                      ),
                      SizedBox(height: size.height * 0.02),
                      Text(
                        'Search for users',
                        style: TextStyle(
                          color: AppTheme.secondaryText(context),
                          fontSize: size.width * 0.04,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.horizontalPadding(context),
                  ),
                  itemCount: provider.searchResults.length,
                  itemBuilder: (context, index) {
                    final user = provider.searchResults[index];
                    return _buildSearchResultCard(
                      user,
                      provider,
                      authProvider,
                      size,
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
    Size size,
  ) {
    if (provider.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryAccent),
      );
    }

    if (provider.pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: size.width * 0.2,
              color: AppTheme.tertiaryText(context),
            ),
            SizedBox(height: size.height * 0.02),
            Text(
              'No pending requests',
              style: TextStyle(
                color: AppTheme.secondaryText(context),
                fontSize: size.width * 0.04,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.horizontalPadding(context),
      ),
      itemCount: provider.pendingRequests.length,
      itemBuilder: (context, index) {
        final request = provider.pendingRequests[index];
        return _buildPendingRequestCard(request, provider, authProvider, size);
      },
    );
  }

  // Sent Requests Tab
  Widget _buildSentRequestsTab(
    FriendsProvider provider,
    AuthProvider authProvider,
    Size size,
  ) {
    if (provider.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryAccent),
      );
    }

    if (provider.sentRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.send_outlined,
              size: size.width * 0.2,
              color: AppTheme.tertiaryText(context),
            ),
            SizedBox(height: size.height * 0.02),
            Text(
              'No sent requests',
              style: TextStyle(
                color: AppTheme.secondaryText(context),
                fontSize: size.width * 0.04,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.horizontalPadding(context),
      ),
      itemCount: provider.sentRequests.length,
      itemBuilder: (context, index) {
        final request = provider.sentRequests[index];
        return _buildSentRequestCard(request, size);
      },
    );
  }

  // Friend Card Widget
  Widget _buildFriendCard(Friend friend, Size size) {
    return Container(
      margin: EdgeInsets.only(bottom: size.height * 0.015),
      padding: EdgeInsets.all(size.width * 0.03),
      decoration: BoxDecoration(
        color: AppTheme.darkDotInactive.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Profile Picture
          Container(
            width: size.width * 0.13,
            height: size.width * 0.13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.darkDotInactive,
              image: friend.profilePictureUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(friend.profilePictureUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: friend.profilePictureUrl.isEmpty
                ? Icon(
                    Icons.person,
                    size: size.width * 0.06,
                    color: AppTheme.tertiaryText(context),
                  )
                : null,
          ),
          SizedBox(width: size.width * 0.03),
          // Name and Username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName,
                  style: TextStyle(
                    color: AppTheme.primaryText(context),
                    fontSize: size.width * 0.04,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: size.height * 0.003),
                Text(
                  '@${friend.username}',
                  style: TextStyle(
                    color: AppTheme.secondaryText(context),
                    fontSize: size.width * 0.033,
                  ),
                ),
              ],
            ),
          ),
          // Options Button
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: AppTheme.tertiaryText(context),
              size: size.width * 0.055,
            ),
            onPressed: () {
              // TODO: Show options (view profile, unfriend, etc.)
            },
          ),
        ],
      ),
    );
  }

  // Search Result Card Widget
  Widget _buildSearchResultCard(
    Friend user,
    FriendsProvider provider,
    AuthProvider authProvider,
    Size size,
  ) {
    // Check if already sent request
    final hasSentRequest = provider.sentRequests.any(
      (request) => request.username == user.username,
    );

    return Container(
      margin: EdgeInsets.only(bottom: size.height * 0.015),
      padding: EdgeInsets.all(size.width * 0.03),
      decoration: BoxDecoration(
        color: AppTheme.darkDotInactive.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Profile Picture
          Container(
            width: size.width * 0.13,
            height: size.width * 0.13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.darkDotInactive,
              image: user.profilePictureUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(user.profilePictureUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: user.profilePictureUrl.isEmpty
                ? Icon(
                    Icons.person,
                    size: size.width * 0.06,
                    color: AppTheme.tertiaryText(context),
                  )
                : null,
          ),
          SizedBox(width: size.width * 0.03),
          // Name and Username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: TextStyle(
                    color: AppTheme.primaryText(context),
                    fontSize: size.width * 0.04,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: size.height * 0.003),
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    color: AppTheme.secondaryText(context),
                    fontSize: size.width * 0.033,
                  ),
                ),
                if (user.bio != null && user.bio!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: size.height * 0.005),
                    child: Text(
                      user.bio!,
                      style: TextStyle(
                        color: AppTheme.tertiaryText(context),
                        fontSize: size.width * 0.03,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          // Add Friend Button
          hasSentRequest
              ? Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.03,
                    vertical: size.height * 0.008,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkDotInactive,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pending',
                    style: TextStyle(
                      color: AppTheme.tertiaryText(context),
                      fontSize: size.width * 0.032,
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () async {
                    if (authProvider.currentUser != null) {
                      final success = await provider.sendFriendRequest(
                        authProvider.currentUser!.userId,
                        user.username,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Friend request sent!'
                                  : provider.error ?? 'Failed to send request',
                            ),
                            backgroundColor: success
                                ? Colors.green
                                : Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.03,
                      vertical: size.height * 0.008,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_add,
                          size: size.width * 0.04,
                          color: Colors.white,
                        ),
                        SizedBox(width: size.width * 0.01),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size.width * 0.032,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // Pending Request Card Widget
  Widget _buildPendingRequestCard(
    FriendRequest request,
    FriendsProvider provider,
    AuthProvider authProvider,
    Size size,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: size.height * 0.015),
      padding: EdgeInsets.all(size.width * 0.03),
      decoration: BoxDecoration(
        color: AppTheme.darkDotInactive.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Profile Picture
          Container(
            width: size.width * 0.13,
            height: size.width * 0.13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.darkDotInactive,
              image: request.profilePictureUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(request.profilePictureUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: request.profilePictureUrl.isEmpty
                ? Icon(
                    Icons.person,
                    size: size.width * 0.06,
                    color: AppTheme.tertiaryText(context),
                  )
                : null,
          ),
          SizedBox(width: size.width * 0.03),
          // Name and Username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.displayName,
                  style: TextStyle(
                    color: AppTheme.primaryText(context),
                    fontSize: size.width * 0.04,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: size.height * 0.003),
                Text(
                  '@${request.username}',
                  style: TextStyle(
                    color: AppTheme.secondaryText(context),
                    fontSize: size.width * 0.033,
                  ),
                ),
              ],
            ),
          ),
          // Accept Button
          GestureDetector(
            onTap: () async {
              if (authProvider.currentUser != null) {
                final success = await provider.acceptFriendRequest(
                  request.friendshipId,
                  authProvider.currentUser!.userId,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Friend request accepted!'
                            : provider.error ?? 'Failed to accept request',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            child: Container(
              padding: EdgeInsets.all(size.width * 0.025),
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                size: size.width * 0.045,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: size.width * 0.02),
          // Reject Button
          GestureDetector(
            onTap: () async {
              if (authProvider.currentUser != null) {
                final success = await provider.rejectFriendRequest(
                  request.friendshipId,
                  authProvider.currentUser!.userId,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Friend request rejected'
                            : provider.error ?? 'Failed to reject request',
                      ),
                      backgroundColor: success ? Colors.orange : Colors.red,
                    ),
                  );
                }
              }
            },
            child: Container(
              padding: EdgeInsets.all(size.width * 0.025),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: size.width * 0.045,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Sent Request Card Widget
  Widget _buildSentRequestCard(FriendRequest request, Size size) {
    return Container(
      margin: EdgeInsets.only(bottom: size.height * 0.015),
      padding: EdgeInsets.all(size.width * 0.03),
      decoration: BoxDecoration(
        color: AppTheme.darkDotInactive.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Profile Picture
          Container(
            width: size.width * 0.13,
            height: size.width * 0.13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.darkDotInactive,
              image: request.profilePictureUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(request.profilePictureUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: request.profilePictureUrl.isEmpty
                ? Icon(
                    Icons.person,
                    size: size.width * 0.06,
                    color: AppTheme.tertiaryText(context),
                  )
                : null,
          ),
          SizedBox(width: size.width * 0.03),
          // Name and Username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.displayName,
                  style: TextStyle(
                    color: AppTheme.primaryText(context),
                    fontSize: size.width * 0.04,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: size.height * 0.003),
                Text(
                  '@${request.username}',
                  style: TextStyle(
                    color: AppTheme.secondaryText(context),
                    fontSize: size.width * 0.033,
                  ),
                ),
              ],
            ),
          ),
          // Pending Badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.03,
              vertical: size.height * 0.008,
            ),
            decoration: BoxDecoration(
              color: AppTheme.darkDotInactive,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  size: size.width * 0.035,
                  color: AppTheme.secondaryText(context),
                ),
                SizedBox(width: size.width * 0.01),
                Text(
                  'Pending',
                  style: TextStyle(
                    color: AppTheme.secondaryText(context),
                    fontSize: size.width * 0.032,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
