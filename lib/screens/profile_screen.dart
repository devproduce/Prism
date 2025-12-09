import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/profile_provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/widgets/gradient_background.dart';
import 'package:prism/screens/edit_profile_screen.dart';
import 'package:prism/screens/image_viewer_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/screens/home_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final galleryProvider = Provider.of<GalleryProvider>(context);

    final user = profileProvider.currentUser ?? authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(color: PrismColors.primaryBlue),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(user.username, style: PrismTextStyles.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.menu_rounded, color: PrismColors.primaryBlue),
            onPressed: () => _showMenuOptions(context, authProvider),
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                // Profile Header Section
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar and Stats Row
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: PrismColors.prismSignatureDark,
                              boxShadow: [
                                BoxShadow(
                                  color: PrismColors.glassBlueGlow,
                                  blurRadius: 20,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(3.0),
                              child: ClipOval(
                                child:
                                    user.profilePictureUrl != null &&
                                        user.profilePictureUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: user.profilePictureUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              color:
                                                  PrismColors.glassFrostedWhite,
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              color:
                                                  PrismColors.glassFrostedWhite,
                                              child: const Icon(
                                                Icons.person,
                                                color: Colors.white,
                                              ),
                                            ),
                                      )
                                    : Container(
                                        color: PrismColors.glassFrostedWhite,
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
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
                                  galleryProvider.allImages.length.toString(),
                                  'Photos',
                                  onTap: () => HomeScreen
                                      .homeScreenKey
                                      .currentState
                                      ?.switchToTab(0),
                                ),
                                Consumer<FriendsProvider>(
                                  builder: (context, friendsProvider, child) {
                                    return _buildStatColumn(
                                      friendsProvider.friends.length.toString(),
                                      'Friends',
                                      onTap: () => HomeScreen
                                          .homeScreenKey
                                          .currentState
                                          ?.switchToTab(3),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Name & Bio
                      Text(
                        '${user.firstName}${user.lastName != null ? ' ${user.lastName}' : ''}',
                        style: PrismTextStyles.h2.copyWith(fontSize: 20),
                      ),
                      if (user.pronouns != null && user.pronouns!.isNotEmpty)
                        Text(
                          user.pronouns!,
                          style: PrismTextStyles.bodySmall.copyWith(
                            color: PrismColors.textSecondary,
                          ),
                        ),
                      if (user.bio != null && user.bio!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            user.bio!,
                            style: PrismTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  color: PrismColors.darkCard.withOpacity(0.8),
                  child: TabBar(
                    indicatorColor: PrismColors.primaryBlue,
                    labelColor: PrismColors.primaryBlue,
                    unselectedLabelColor: Colors.white54,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(icon: Icon(Icons.grid_on_rounded), text: 'Photos'),
                      Tab(
                        icon: Icon(Icons.favorite_rounded),
                        text: 'Favorites',
                      ),
                    ],
                  ),
                ),
                // TabBarView
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPostsGrid(galleryProvider),
                      _buildFavoritesGrid(galleryProvider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, {VoidCallback? onTap}) {
    final column = Column(
      children: [
        Text(value, style: PrismTextStyles.h3.copyWith(fontSize: 18)),
        Text(
          label,
          style: PrismTextStyles.bodySmall.copyWith(color: Colors.white60),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: column,
        ),
      );
    }
    return column;
  }

  Widget _buildPostsGrid(GalleryProvider galleryProvider) {
    // Show loading indicator if initial load
    if (galleryProvider.isLoading && galleryProvider.allImages.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: PrismColors.purple),
      );
    }

    final allImages = galleryProvider.allImages;
    if (allImages.isEmpty)
      return _emptyState('No photos yet', Icons.photo_library_outlined);

    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      itemCount: allImages.length,
      itemBuilder: (context, index) {
        final image = allImages[index];
        return GestureDetector(
          onTap: () {
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
          child: Hero(
            tag: 'profile_post_${image.image.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: image.image.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: PrismColors.glassFrostedWhite),
                errorWidget: (context, url, error) => Container(
                  color: PrismColors.glassFrostedWhite,
                  child: Icon(Icons.broken_image, color: Colors.white24),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesGrid(GalleryProvider galleryProvider) {
    final favoriteImages = galleryProvider.favouriteImages;
    if (favoriteImages.isEmpty)
      return _emptyState('No favorites yet', Icons.favorite_border_rounded);

    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      itemCount: favoriteImages.length,
      itemBuilder: (context, index) {
        final image = favoriteImages[index];
        return GestureDetector(
          onTap: () {
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: image.image.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(color: PrismColors.glassFrostedWhite),
              errorWidget: (context, url, error) =>
                  Container(color: PrismColors.glassFrostedWhite),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            message,
            style: PrismTextStyles.bodyMedium.copyWith(color: Colors.white38),
          ),
        ],
      ),
    );
  }

  void _showMenuOptions(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GlassCard(
        borderRadius: 24,
        margin: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.settings_rounded,
                color: Colors.white70,
              ),
              title: Text('Settings', style: PrismTextStyles.bodyMedium),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: Colors.white24,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            Divider(color: Colors.white10, height: 1),
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: PrismColors.errorRed,
              ),
              title: Text(
                'Logout',
                style: PrismTextStyles.bodyMedium.copyWith(
                  color: PrismColors.errorRed,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await authProvider.logout(context);
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/onboarding', (route) => false);
                }
              },
            ),
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
  double get minExtent => _tabBar.preferredSize.height + 1; // Add 1 to avoid overlap issues
  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: PrismColors.darkBase.withOpacity(
        0.95,
      ), // Needs opacity to block content scrolling behind
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
