import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/models/user_model.dart';
import 'package:prism/models/gallery_image_model.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/screens/image_viewer_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/widgets/prism_media_preview.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:prism/widgets/shimmer_placeholder.dart';
import 'package:prism/widgets/empty_state_widget.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? username;
  final String? initialProfileTab;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.username,
    this.initialProfileTab,
  });

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
    final initialIndex = widget.initialProfileTab == 'received' ? 1 : 0;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
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

      if (!await apiClient.ensureAuthenticated()) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

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
      if (!await apiClient.ensureAuthenticated()) return;

      debugPrint('📸 Fetching shared gallery for friend: ${widget.userId}');

      final data = await apiClient.getSharedGallery(
        friendId: widget.userId,
      );

      if (!mounted) return;

      final images = data
          .map((json) => GalleryImage.fromJson(json as Map<String, dynamic>))
          .toList();

      setState(() {
        _sharedImages = images;
        _isLoadingSharedImages = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading shared images: $e');
      if (mounted) {
        setState(() => _isLoadingSharedImages = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: PrismColors.voidBlack,
        body: Center(child: ShimmerLayouts.profileHeader()),
      );
    }

    if (_userData == null) {
      return Scaffold(
        backgroundColor: PrismColors.voidBlack,
        appBar: AppBar(
          title: Text('Profile', style: PrismTextStyles.h2),
          backgroundColor: Colors.transparent,
          centerTitle: true,
          elevation: 0,
          leading: BackButton(
            color: PrismColors.white,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_off_outlined,
                size: 64,
                color: PrismColors.secondaryText,
              ),
              const SizedBox(height: 16),
              Text(
                'User not found',
                style: PrismTextStyles.h3.copyWith(
                  color: PrismColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text(
                _userData?.username ?? widget.username ?? 'Profile',
                style: PrismTextStyles.h2,
              ),
              backgroundColor: PrismColors.voidBlack,
              centerTitle: true,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: BackButton(
                color: PrismColors.white,
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (_isFriend)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: PrismColors.white),
                    color: PrismColors.surfaceGray,
                    onSelected: (value) async {
                      final friendsProvider = Provider.of<FriendsProvider>(
                        context,
                        listen: false,
                      );
                      final authProvider = Provider.of<AuthProvider>(
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
                            Icon(
                              Icons.block,
                              color: PrismColors.destructiveRed,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Block User',
                              style: TextStyle(
                                color: PrismColors.destructiveRed,
                              ),
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
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Remove Friend',
                              style: TextStyle(
                                color: PrismColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
              pinned: true,
              floating: false,
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
                              color: PrismColors.surfaceGray,
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
                                      color: PrismColors.surfaceGray,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                          Icons.person,
                                          color: PrismColors.secondaryText,
                                        ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: PrismColors.secondaryText,
                                  ),
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
                      style: PrismTextStyles.h3,
                    ),
                    if (_userData?.pronouns != null &&
                        _userData!.pronouns!.isNotEmpty)
                      Text(
                        _userData!.pronouns!,
                        style: PrismTextStyles.bodySmall.copyWith(
                          color: PrismColors.secondaryText,
                        ),
                      ),
                    if (_userData?.bio != null && _userData!.bio!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _userData!.bio!,
                          style: PrismTextStyles.bodyMedium,
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    if (!_isFriend && !_isPending)
                      SizedBox(
                        width: double.infinity,
                        child: PrismButton(
                          text: 'Add Friend',
                          icon: Icons.person_add,
                          onPressed: () => _handleSendFriendRequest(),
                        ),
                      ),
                    if (!_isFriend && _isPending)
                      SizedBox(
                        width: double.infinity,
                        child: PrismButton(
                          text: 'Request Pending',
                          icon: Icons.schedule,
                          type: PrismButtonType.secondary,
                          onPressed: () {}, // No action, just status
                        ),
                      ),
                    if (_isFriend)
                      SizedBox(
                        width: double.infinity,
                        child: PrismButton(
                          text: 'View Friends',
                          icon: Icons.people,
                          type: PrismButtonType.secondary,
                          onPressed: () => _showFriendsList(),
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
                    indicatorColor: PrismColors.prismYellow,
                    labelColor: PrismColors.prismYellow,
                    unselectedLabelColor: PrismColors.secondaryText,
                    dividerColor: PrismColors.white.withValues(alpha: 0.1),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: PrismTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: PrismTextStyles.bodyMedium,
                    overlayColor: WidgetStateProperty.all(
                      PrismColors.prismYellow.withValues(alpha: 0.1),
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
    return Column(
      children: [
        Text(value, style: PrismTextStyles.h3),
        Text(
          label,
          style: PrismTextStyles.bodySmall.copyWith(
            color: PrismColors.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildNonFriendView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 64,
              color: PrismColors.secondaryText,
            ),
            const SizedBox(height: 16),
            Text('This account is private', style: PrismTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              'Follow this user to see their shared photos and videos.',
              textAlign: TextAlign.center,
              style: PrismTextStyles.bodyMedium.copyWith(
                color: PrismColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentImagesTab() {
    // Filter images where type is 'sent' (sent TO the friend)
    final sentImages = _sharedImages
        .where((img) => img.type == 'sent')
        .toList();

    if (_isLoadingSharedImages) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ShimmerLayouts.galleryGrid(itemCount: 9, crossAxisCount: 3),
      );
    }

    if (sentImages.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.send_outlined,
        title: 'No images sent yet',
        message: '',
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
          child: PrismMediaPreview(
            imageUrl: image.image.imageUrl,
            mediaType: image.image.mediaType,
            fit: BoxFit.cover,
            placeholderColor: PrismColors.surfaceGray,
          ),
        );
      },
    );
  }

  Widget _buildReceivedImagesTab() {
    // Filter images where type is 'received' (received FROM the friend)
    final receivedImages = _sharedImages
        .where((img) => img.type == 'received')
        .toList();

    if (_isLoadingSharedImages) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ShimmerLayouts.galleryGrid(itemCount: 9, crossAxisCount: 3),
      );
    }

    if (receivedImages.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.inbox_outlined,
        title: 'No images received yet',
        message: '',
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
          child: PrismMediaPreview(
            imageUrl: image.image.imageUrl,
            mediaType: image.image.mediaType,
            fit: BoxFit.cover,
            placeholderColor: PrismColors.surfaceGray,
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

      if (success) {
        ErrorHandler.showSuccessSnackbar(
          context,
          message: 'Friend request sent!',
        );
      } else {
        ErrorHandler.showErrorSnackbar(
          context,
          message: friendsProvider.error ?? 'Failed to send request',
        );
      }
    }
  }

  Future<void> _handleBlockUser(
    String friendId,
    String userId,
    String friendName,
    FriendsProvider friendsProvider,
  ) async {
    HapticFeedback.selectionClick();

    final confirmed = await ErrorHandler.showConfirmationDialog(
      context,
      title: 'Block User',
      message:
          'Are you sure you want to block $friendName? They will be removed from your friends list.',
      confirmText: 'Block',
      isDestructive: true,
    );

    if (confirmed != true) return;

    if (mounted) {
      ErrorHandler.showInfoSnackbar(context, message: 'Blocking user...');
    }

    final success = await friendsProvider.blockUser(friendId, userId);

    if (mounted) {
      if (success) {
        ErrorHandler.showSuccessSnackbar(
          context,
          message: '$friendName has been blocked',
        );
        Navigator.pop(context);
      } else {
        ErrorHandler.showErrorSnackbar(
          context,
          message: friendsProvider.error ?? 'Failed to block user',
        );
      }
    }
  }

  Future<void> _handleRemoveFriend(
    String friendId,
    String userId,
    String friendName,
    FriendsProvider friendsProvider,
  ) async {
    HapticFeedback.selectionClick();

    final confirmed = await ErrorHandler.showConfirmationDialog(
      context,
      title: 'Remove Friend',
      message:
          'Are you sure you want to remove $friendName from your friends list?',
      confirmText: 'Remove',
      isDestructive: true,
    );

    if (confirmed != true) return;

    final success = await friendsProvider.unfriend(friendId, userId);

    if (mounted) {
      if (success) {
        ErrorHandler.showSuccessSnackbar(
          context,
          message: '$friendName removed from friends',
        );
        setState(() {
          _isFriend = false;
        });
      } else {
        ErrorHandler.showErrorSnackbar(
          context,
          message: friendsProvider.error ?? 'Failed to remove friend',
        );
      }
    }
  }

  Future<void> _showFriendsList() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: PrismColors.surfaceGray,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.engineering,
              size: 48,
              color: PrismColors.prismYellow,
            ),
            const SizedBox(height: 16),
            Text('Coming Soon', style: PrismTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Viewing other user\'s friends list will be available in a future update.',
              textAlign: TextAlign.center,
              style: PrismTextStyles.bodyMedium.copyWith(
                color: PrismColors.secondaryText,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
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
    return Container(
      color: PrismColors.voidBlack, // Match scaffold background
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
