import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/models/user_model.dart';
import 'package:prism/models/friend_model.dart';
import 'package:prism/models/gallery_image_model.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/widgets/gradient_scaffold.dart';
import 'package:prism/screens/image_viewer_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? username;

  const UserProfileScreen({super.key, required this.userId, this.username});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _userData;
  bool _isLoading = true;
  bool _isFriend = false;
  bool _isPending = false;
  int _friendsCount = 0;
  late TabController _tabController;
  List<GalleryImage> _sharedImages = [];
  bool _isLoadingSharedImages = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      _loadSharedImages();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final friendsProvider = Provider.of<FriendsProvider>(
        context,
        listen: false,
      );
      final apiClient = ApiClient();

      if (authProvider.currentUser != null) {
        // Check if user is a friend (without triggering rebuild)
        if (friendsProvider.friends.isEmpty) {
          await friendsProvider.fetchFriends(authProvider.currentUser!.userId);
        }

        final isFriend = friendsProvider.friends.any(
          (friend) => friend.userId == widget.userId,
        );

        final isPending = friendsProvider.sentRequests.any(
          (request) => request.receiverId == widget.userId,
        );

        if (!mounted) return;
        setState(() {
          _isFriend = isFriend;
          _isPending = isPending;
        });

        final userData = await apiClient.getUserById(widget.userId);

        if (!mounted) return;
        setState(() {
          _friendsCount = userData['friends_count'] ?? 0;
          _userData = UserModel(
            userId: userData['id'] ?? widget.userId,
            username: userData['username'] ?? '',
            email: userData['email'] ?? '',
            firstName: userData['first_name'] ?? '',
            profilePicId: userData['profile_pic_id'],
            lastName: userData['last_name'],
            bio: userData['bio'],
            pronouns: userData['pronouns'],
            dob: userData['dob'] != null
                ? DateTime.tryParse(userData['dob'])
                : null,
            countryCode: userData['country_code'],
            phoneNumber: userData['phone_number'],
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSharedImages() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;

    setState(() => _isLoadingSharedImages = true);

    try {
      final apiClient = ApiClient();
      debugPrint('📸 Fetching shared gallery for friend: ${widget.userId}');
      debugPrint('📸 Current user: ${authProvider.currentUser!.userId}');

      final data = await apiClient.getSharedGallery(
        userId: authProvider.currentUser!.userId,
        friendId: widget.userId,
      );

      debugPrint('📸 Received ${data.length} items from API');

      if (!mounted) return;

      final images = data
          .map((json) => GalleryImage.fromJson(json as Map<String, dynamic>))
          .toList();

      setState(() {
        _sharedImages = images;
        _isLoadingSharedImages = false;
      });

      debugPrint('📸 Loaded ${_sharedImages.length} shared images');

      // Debug: Log type information
      for (var img in _sharedImages) {
        debugPrint('📸 Image ${img.image.id} type: ${img.type}');
      }

      // Count sent and received
      final sentCount = _sharedImages.where((img) => img.type == 'sent').length;
      final receivedCount = _sharedImages
          .where((img) => img.type == 'received')
          .length;

      debugPrint('📸 Sent images: $sentCount');
      debugPrint('📸 Received images: $receivedCount');
    } catch (e) {
      debugPrint('❌ Error loading shared images: $e');
      if (mounted) {
        setState(() => _isLoadingSharedImages = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);

    if (_isLoading) {
      return GradientScaffold(
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    if (_userData == null) {
      final isDark = theme.brightness == Brightness.dark;
      return GradientScaffold(
        appBar: AppBar(
          title: Text(
            'Profile',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 22,
              color: theme.colorScheme.onSurface,
            ),
          ),
          backgroundColor: isDark
              ? const Color(0xFF1E1E1E)
              : const Color(0xFFF5F5F5),
          centerTitle: true,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text('User not found', style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    return GradientScaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text(
                _userData?.username ?? widget.username ?? 'Profile',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              backgroundColor: Colors.transparent,
              centerTitle: true,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              actions: [
                if (_isFriend)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      final friendsProvider = Provider.of<FriendsProvider>(
                        context,
                        listen: false,
                      );

                      switch (value) {
                        case 'block':
                          await _handleBlockUser(
                            widget.userId,
                            authProvider.currentUser!.userId,
                            _userData?.firstName ??
                                _userData?.username ??
                                'this user',
                            friendsProvider,
                          );
                          break;
                        case 'remove':
                          await _handleRemoveFriend(
                            widget.userId,
                            authProvider.currentUser!.userId,
                            _userData?.firstName ??
                                _userData?.username ??
                                'this user',
                            friendsProvider,
                          );
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Block User',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.person_remove, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'Remove Friend',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
              pinned: true,
              floating: false,
              expandedHeight: 0,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surfaceContainerHighest,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child:
                                _userData?.profilePictureUrl != null &&
                                    _userData!.profilePictureUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: _userData!.profilePictureUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.person),
                                  )
                                : const Icon(Icons.person, size: 40),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Stats
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatColumn(
                                _friendsCount.toString(),
                                'Friends',
                              ),
                              // Add more stats if available
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Name & Bio
                    Text(
                      '${_userData?.firstName ?? ''} ${_userData?.lastName ?? ''}'
                          .trim(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_userData?.pronouns != null &&
                        _userData!.pronouns!.isNotEmpty)
                      Text(
                        _userData!.pronouns!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (_userData?.bio != null && _userData!.bio!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _userData!.bio!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    if (!_isFriend && !_isPending)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _handleSendFriendRequest(),
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add Friend'),
                        ),
                      ),
                    if (!_isFriend && _isPending)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.schedule),
                          label: const Text('Request Pending'),
                        ),
                      ),
                    if (_isFriend)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showFriendsList(),
                          icon: const Icon(Icons.people),
                          label: const Text('View Friends'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_isFriend)
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: theme.colorScheme.primary,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    dividerColor: theme.colorScheme.outlineVariant.withOpacity(
                      0.3,
                    ),
                    overlayColor: WidgetStateProperty.all(
                      theme.colorScheme.primary.withOpacity(0.1),
                    ),
                    tabs: const [
                      Tab(text: 'Sent'),
                      Tab(text: 'Received'),
                    ],
                  ),
                ),
                pinned: true,
                floating: false,
              ),
          ];
        },
        body: _isFriend
            ? TabBarView(
                controller: _tabController,
                children: [_buildSentImagesTab(), _buildReceivedImagesTab()],
              )
            : _buildNonFriendView(),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildNonFriendView() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'This account is private',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow this user to see their shared photos and videos.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentImagesTab() {
    final theme = Theme.of(context);

    // Filter images where type is 'sent' (sent TO the friend)
    final sentImages = _sharedImages
        .where((img) => img.type == 'sent')
        .toList();

    if (_isLoadingSharedImages) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (sentImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.send_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No images sent yet', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: sentImages.length,
      itemBuilder: (context, index) {
        final image = sentImages[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ImageViewerScreen(images: sentImages, initialIndex: index),
              ),
            );
          },
          child: CachedNetworkImage(
            imageUrl: image.image.imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[800],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[800],
              child: const Icon(Icons.error),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceivedImagesTab() {
    final theme = Theme.of(context);

    // Filter images where type is 'received' (received FROM the friend)
    final receivedImages = _sharedImages
        .where((img) => img.type == 'received')
        .toList();

    if (_isLoadingSharedImages) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (receivedImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No images received yet', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: receivedImages.length,
      itemBuilder: (context, index) {
        final image = receivedImages[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageViewerScreen(
                  images: receivedImages,
                  initialIndex: index,
                ),
              ),
            );
          },
          child: CachedNetworkImage(
            imageUrl: image.image.imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[800],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[800],
              child: const Icon(Icons.error),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSendFriendRequest() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendsProvider = Provider.of<FriendsProvider>(
      context,
      listen: false,
    );

    if (authProvider.currentUser == null) return;

    // Optimistically update UI
    setState(() {
      _isPending = true;
    });

    final success = await friendsProvider.sendFriendRequest(
      authProvider.currentUser!.userId,
      _userData?.username ?? widget.userId,
    );

    if (mounted) {
      // Revert on failure
      if (!success) {
        setState(() {
          _isPending = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Friend request sent!'
                : friendsProvider.error ?? 'Failed to send request',
          ),
          backgroundColor: success
              ? Colors.green
              : Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleBlockUser(
    String friendId,
    String userId,
    String friendName,
    FriendsProvider friendsProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text(
          'Are you sure you want to block $friendName? They will be removed from your friends list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blocking user...'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final success = await friendsProvider.blockUser(friendId, userId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '$friendName has been blocked'
                : friendsProvider.error ?? 'Failed to block user',
          ),
          backgroundColor: success
              ? Colors.green
              : Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (success) {
        Navigator.pop(context);
      }
    }
  }

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

      if (success) {
        setState(() {
          _isFriend = false;
        });
      }
    }
  }

  Future<void> _showFriendsList() async {
    final apiClient = ApiClient();
    final theme = Theme.of(context);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      ),
    );

    try {
      // Fetch the user's friends list
      final response = await apiClient.getFriends(userId: widget.userId);
      final friendsList = response
          .map((json) => Friend.fromJson(json))
          .toList();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Show friends list in a bottom sheet
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => _buildFriendsListSheet(friendsList),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load friends list'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildFriendsListSheet(List<Friend> friendsList) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '${_userData?.firstName ?? _userData?.username ?? 'User'}\'s Friends',
                style: theme.textTheme.titleLarge,
              ),
            ),
            const Divider(),
            Expanded(
              child: friendsList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No friends yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: friendsList.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final friend = friendsList[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: friend.profilePictureUrl.isNotEmpty
                                ? CachedNetworkImageProvider(
                                    friend.profilePictureUrl,
                                  )
                                : null,
                            child: friend.profilePictureUrl.isEmpty
                                ? Icon(
                                    Icons.person,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  )
                                : null,
                          ),
                          title: Text(
                            friend.displayName,
                            style: theme.textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            '@${friend.username}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context); // Close bottom sheet
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
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: _tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
