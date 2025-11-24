import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/profile_provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/utils/theme.dart';
import 'package:prism/screens/edit_profile_screen.dart';
import 'package:prism/screens/image_viewer_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch profile data on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );

      if (authProvider.currentUser != null) {
        // Initialize with cached data first
        profileProvider.initializeWithUser(authProvider.currentUser!);
        // Then fetch fresh data from backend
        profileProvider.fetchUserProfile(authProvider.currentUser!.userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final galleryProvider = Provider.of<GalleryProvider>(context);
    final user = profileProvider.currentUser ?? authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.primaryBackground(context),
        body: const Center(child: Text('No user data available')),
      );
    }

    // Show loading overlay if fetching
    if (profileProvider.isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.primaryBackground(context),
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.horizontalPadding(context),
              vertical: size.height * 0.02,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header with username
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      user.username,
                      style: AppTheme.headlineStyle(
                        context,
                      ).copyWith(fontSize: size.width * 0.055),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.menu,
                        color: AppTheme.primaryText(context),
                        size: size.width * 0.07,
                      ),
                      onPressed: () {
                        _showMenuOptions(context, authProvider);
                      },
                    ),
                  ],
                ),

                SizedBox(height: size.height * 0.03),

                // Profile Picture
                Stack(
                  children: [
                    Container(
                      width: size.width * 0.25,
                      height: size.width * 0.25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryAccent,
                          width: 2,
                        ),
                        color: AppTheme.darkDotInactive,
                      ),
                      child: user.profilePictureUrl != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: user.profilePictureUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryAccent,
                                    strokeWidth: 2,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Icon(
                                  Icons.person,
                                  size: size.width * 0.12,
                                  color: AppTheme.tertiaryText(context),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: size.width * 0.12,
                              color: AppTheme.tertiaryText(context),
                            ),
                    ),
                    // Online status indicator
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: size.width * 0.06,
                        height: size.width * 0.06,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryBackground(context),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: size.height * 0.02),

                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatColumn(
                      profileProvider.postsCount.toString(),
                      'Posts',
                      size,
                    ),
                    SizedBox(width: size.width * 0.08),
                    _buildStatColumn(
                      profileProvider.friendsCount.toString(),
                      'Friends',
                      size,
                    ),
                    SizedBox(width: size.width * 0.08),
                    _buildStatColumn(
                      profileProvider.reach.toString(),
                      'Reach',
                      size,
                    ),
                  ],
                ),

                SizedBox(height: size.height * 0.02),

                // User Info Section - Compact Instagram Style
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Name
                      Text(
                        '${user.firstName}${user.lastName != null ? ' ${user.lastName}' : ''}',
                        style: AppTheme.headlineStyle(context).copyWith(
                          fontSize: size.width * 0.042,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      // Pronouns
                      if (user.pronouns != null && user.pronouns!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: size.height * 0.003),
                          child: Text(
                            user.pronouns!,
                            style: TextStyle(
                              color: AppTheme.secondaryText(context),
                              fontSize: size.width * 0.032,
                            ),
                          ),
                        ),

                      // Bio
                      if (user.bio != null && user.bio!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: size.height * 0.008),
                          child: Text(
                            user.bio!,
                            style: TextStyle(
                              color: AppTheme.primaryText(context),
                              fontSize: size.width * 0.035,
                              height: 1.3,
                            ),
                          ),
                        ),

                      // Email link style
                      if (user.email.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: size.height * 0.008),
                          child: Row(
                            children: [
                              Icon(
                                Icons.link,
                                size: size.width * 0.035,
                                color: AppTheme.primaryAccent,
                              ),
                              SizedBox(width: size.width * 0.015),
                              Text(
                                user.email,
                                style: TextStyle(
                                  color: AppTheme.primaryAccent,
                                  fontSize: size.width * 0.032,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                SizedBox(height: size.height * 0.02),

                // Action Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          );
                        },
                        child: Container(
                          height: size.height * 0.045,
                          decoration: BoxDecoration(
                            color: AppTheme.darkDotInactive,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Edit profile',
                              style: TextStyle(
                                color: AppTheme.primaryText(context),
                                fontSize: size.width * 0.035,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: size.width * 0.02),
                    Expanded(
                      child: Container(
                        height: size.height * 0.045,
                        decoration: BoxDecoration(
                          color: AppTheme.darkDotInactive,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Share profile',
                            style: TextStyle(
                              color: AppTheme.primaryText(context),
                              fontSize: size.width * 0.035,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: size.width * 0.02),
                    Container(
                      height: size.height * 0.045,
                      width: size.height * 0.045,
                      decoration: BoxDecoration(
                        color: AppTheme.darkDotInactive,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person_add_outlined,
                        color: AppTheme.primaryText(context),
                        size: size.width * 0.05,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: size.height * 0.015),

                // Highlights Section
                _buildHighlightsSection(size),

                SizedBox(height: size.height * 0.02),

                // Tabs for Posts/Favorites
                _buildContentTabs(size, galleryProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightsSection(Size size) {
    return SizedBox(
      height: size.width * 0.26,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(vertical: size.height * 0.01),
        children: [
          _buildHighlightItem('New', Icons.add, size),
          _buildHighlightItem(
            'Favorites',
            Icons.favorite,
            size,
            hasContent: true,
          ),
          _buildHighlightItem('Travel', Icons.flight, size, hasContent: true),
          _buildHighlightItem('Food', Icons.restaurant, size, hasContent: true),
        ],
      ),
    );
  }

  Widget _buildHighlightItem(
    String label,
    IconData icon,
    Size size, {
    bool hasContent = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: size.width * 0.04),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size.width * 0.16,
            height: size.width * 0.16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: hasContent
                  ? LinearGradient(
                      colors: [
                        AppTheme.primaryAccent,
                        Colors.purple,
                        Colors.pink,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: hasContent ? null : AppTheme.darkDotInactive,
            ),
            child: Padding(
              padding: EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryBackground(context),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: hasContent
                        ? AppTheme.primaryAccent
                        : AppTheme.tertiaryText(context),
                    size: size.width * 0.055,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: size.height * 0.006),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.primaryText(context),
              fontSize: size.width * 0.026,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildContentTabs(Size size, GalleryProvider galleryProvider) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppTheme.primaryAccent,
            labelColor: AppTheme.primaryText(context),
            unselectedLabelColor: AppTheme.tertiaryText(context),
            tabs: [
              Tab(icon: Icon(Icons.grid_on, size: size.width * 0.06)),
              Tab(icon: Icon(Icons.favorite, size: size.width * 0.06)),
            ],
          ),
          SizedBox(
            height: size.height * 0.4,
            child: TabBarView(
              children: [
                _buildPostsGrid(size, galleryProvider),
                _buildFavoritesGrid(size, galleryProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsGrid(Size size, GalleryProvider galleryProvider) {
    final allImages = galleryProvider.allImages;

    if (allImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: size.width * 0.15,
              color: AppTheme.tertiaryText(context),
            ),
            SizedBox(height: size.height * 0.02),
            Text(
              'No posts yet',
              style: TextStyle(
                color: AppTheme.secondaryText(context),
                fontSize: size.width * 0.04,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(1),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: allImages.length > 9 ? 9 : allImages.length,
      itemBuilder: (context, index) {
        final image = allImages[index];
        return GestureDetector(
          onTap: () {
            // Navigate to image viewer
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageViewerScreen(
                  images: allImages,
                  initialIndex: index,
                  isFromBin: false,
                ),
              ),
            );
          },
          child: CachedNetworkImage(
            imageUrl: image.image.imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: AppTheme.darkDotInactive,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryAccent,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppTheme.darkDotInactive,
              child: Icon(
                Icons.broken_image,
                color: AppTheme.tertiaryText(context),
              ),
            ),
            maxHeightDiskCache: 400,
            maxWidthDiskCache: 400,
            memCacheHeight: 200,
            memCacheWidth: 200,
          ),
        );
      },
    );
  }

  Widget _buildFavoritesGrid(Size size, GalleryProvider galleryProvider) {
    final favoriteImages = galleryProvider.favouriteImages;

    if (favoriteImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: size.width * 0.15,
              color: AppTheme.tertiaryText(context),
            ),
            SizedBox(height: size.height * 0.02),
            Text(
              'No favorites yet',
              style: TextStyle(
                color: AppTheme.secondaryText(context),
                fontSize: size.width * 0.04,
              ),
            ),
            SizedBox(height: size.height * 0.01),
            Text(
              'Tap the heart on photos to save them here',
              style: TextStyle(
                color: AppTheme.tertiaryText(context),
                fontSize: size.width * 0.032,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(1),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: favoriteImages.length,
      itemBuilder: (context, index) {
        final image = favoriteImages[index];
        return GestureDetector(
          onTap: () {
            // Navigate to image viewer
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageViewerScreen(
                  images: favoriteImages,
                  initialIndex: index,
                  isFromBin: false,
                ),
              ),
            );
          },
          child: CachedNetworkImage(
            imageUrl: image.image.imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: AppTheme.darkDotInactive,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryAccent,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppTheme.darkDotInactive,
              child: Icon(
                Icons.broken_image,
                color: AppTheme.tertiaryText(context),
              ),
            ),
            maxHeightDiskCache: 400,
            maxWidthDiskCache: 400,
            memCacheHeight: 200,
            memCacheWidth: 200,
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String value, String label, Size size) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppTheme.primaryText(context),
            fontSize: size.width * 0.05,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: size.height * 0.005),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.secondaryText(context),
            fontSize: size.width * 0.032,
          ),
        ),
      ],
    );
  }

  void _showMenuOptions(BuildContext context, AuthProvider authProvider) {
    final size = MediaQuery.of(context).size;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkDotInactive,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(
          vertical: size.height * 0.02,
          horizontal: size.width * 0.05,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: size.width * 0.04,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/onboarding');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
