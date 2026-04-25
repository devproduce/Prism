import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/profile_provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/screens/edit_profile_screen.dart';
import 'package:prism/screens/image_viewer_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/screens/home_screen.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:prism/widgets/prism_media_preview.dart';
import 'package:prism/widgets/empty_state_widget.dart';
import 'package:prism/widgets/shimmer_placeholder.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:prism/utils/responsive_helper.dart';

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

    // Responsive values
    final screenWidth = MediaQuery.of(context).size.width;
    final avatarSize = (screenWidth * 0.22).clamp(70.0, 100.0);
    final horizontalPadding = screenWidth < 360 ? 12.0 : 20.0;
    final gridCrossAxisCount = ResponsiveHelper.galleryGridCount(context);
    final gridSpacing = screenWidth < 360 ? 2.0 : 4.0;

    final user = profileProvider.currentUser ?? authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: PrismColors.voidBlack,
        body: Center(child: ShimmerLayouts.profileHeader()),
      );
    }

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(user.username, style: PrismTextStyles.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: PrismColors.white),
            onPressed: () {
              HapticFeedback.selectionClick();
              _showMenuOptions(context, authProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              // Profile Header Section
              Padding(
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar and Stats Row
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: PrismColors.surfaceGray,
                            border: Border.all(
                              color: PrismColors.prismYellow.withValues(
                                alpha: 0.5,
                              ),
                              width: 2,
                            ),
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
                                      placeholder: (context, url) => Container(
                                        color: PrismColors.inputGray,
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            color: PrismColors.inputGray,
                                            child: const Icon(
                                              Icons.person,
                                              color: PrismColors.secondaryText,
                                            ),
                                          ),
                                    )
                                  : Container(
                                      color: PrismColors.inputGray,
                                      child: Icon(
                                        Icons.person_rounded,
                                        color: PrismColors.secondaryText,
                                        size: avatarSize * 0.45,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        SizedBox(width: horizontalPadding),
                        // Stats
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatColumn(
                                galleryProvider.allImages.length.toString(),
                                'Photos',
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  HomeScreen.homeScreenKey.currentState
                                      ?.switchToTab(0);
                                },
                              ),
                              Consumer<FriendsProvider>(
                                builder: (context, friendsProvider, child) {
                                  return _buildStatColumn(
                                    friendsProvider.friends.length.toString(),
                                    'Friends',
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      HomeScreen.homeScreenKey.currentState
                                          ?.switchToTab(3);
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: horizontalPadding),
                    // Name & Bio
                    Text(
                      '${user.firstName}${user.lastName != null ? ' ${user.lastName}' : ''}',
                      style: PrismTextStyles.h2.copyWith(fontSize: 20),
                    ),
                    if (user.pronouns != null && user.pronouns!.isNotEmpty)
                      Text(
                        user.pronouns!,
                        style: PrismTextStyles.bodySmall.copyWith(
                          color: PrismColors.secondaryText,
                        ),
                      ),
                    if (user.bio != null && user.bio!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          user.bio!,
                          style: PrismTextStyles.bodyMedium.copyWith(
                            color: PrismColors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: horizontalPadding - 4),
                decoration: BoxDecoration(
                  color: PrismColors.surfaceGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: PrismColors.inputGray,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: PrismColors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  indicatorColor: Colors.transparent, // Hide default line
                  labelColor: PrismColors.prismYellow,
                  unselectedLabelColor: PrismColors.secondaryText,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on_rounded), text: 'Photos'),
                    Tab(icon: Icon(Icons.favorite_rounded), text: 'Favorites'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // TabBarView
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPostsGrid(
                      galleryProvider,
                      gridCrossAxisCount,
                      gridSpacing,
                    ),
                    _buildFavoritesGrid(
                      galleryProvider,
                      gridCrossAxisCount,
                      gridSpacing,
                    ),
                  ],
                ),
              ),
            ],
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
          style: PrismTextStyles.bodySmall.copyWith(
            color: PrismColors.secondaryText,
          ),
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

  Widget _buildPostsGrid(
    GalleryProvider galleryProvider,
    int crossAxisCount,
    double spacing,
  ) {
    // Show shimmer loading if initial load
    if (galleryProvider.isLoading && galleryProvider.allImages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ShimmerLayouts.galleryGrid(
          itemCount: 9,
          crossAxisCount: crossAxisCount,
        ),
      );
    }

    final allImages = galleryProvider.allImages;
    if (allImages.isEmpty) {
      return EmptyStateWidget.noMedia();
    }

    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
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
                  heroTagPrefix: 'profile_post_',
                ),
              ),
            );
          },
          child: Hero(
            tag: 'profile_post_${image.image.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PrismMediaPreview(
                imageUrl: image.image.imageUrl,
                mediaType: image.image.mediaType,
                fit: BoxFit.cover,
                placeholderColor: PrismColors.surfaceGray,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesGrid(
    GalleryProvider galleryProvider,
    int crossAxisCount,
    double spacing,
  ) {
    final favoriteImages = galleryProvider.favouriteImages;
    if (favoriteImages.isEmpty) {
      return EmptyStateWidget.noFavorites();
    }

    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
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
                  heroTagPrefix: 'profile_favorite_',
                ),
              ),
            );
          },
          child: Hero(
            tag: 'profile_favorite_${image.image.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PrismMediaPreview(
              imageUrl: image.image.imageUrl,
              mediaType: image.image.mediaType,
              fit: BoxFit.cover,
              placeholderColor: PrismColors.surfaceGray,
            ),
          ),
          )
        );
        
      },
    );
  }

  void _showMenuOptions(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PrismCard(
        margin: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.settings_rounded,
                color: PrismColors.white,
              ),
              title: Text('Settings', style: PrismTextStyles.bodyMedium),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: PrismColors.secondaryText,
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            Divider(color: PrismColors.white.withValues(alpha: 0.1), height: 1),
            ListTile(
              leading: const Icon(
                Icons.person_outline_rounded,
                color: PrismColors.white,
              ),
              title: Text('Edit Profile', style: PrismTextStyles.bodyMedium),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: PrismColors.secondaryText,
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfileScreen(),
                  ),
                );
              },
            ),
            //Divider(color: PrismColors.white.withValues(alpha: 0.1), height: 1),
            
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    Navigator.pop(context); // Close bottom sheet first

    final confirmed = await ErrorHandler.showConfirmationDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      HapticFeedback.mediumImpact();
      try {
        await authProvider.logout(context);
        if (context.mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/onboarding', (route) => false);
        }
      } catch (e) {
        if (context.mounted) {
          ErrorHandler.showErrorSnackbar(
            context,
            message: 'Failed to logout. Please try again.',
          );
        }
      }
    }
  }
}
