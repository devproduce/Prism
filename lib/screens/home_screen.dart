import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/widgets/empty_state_widget.dart';
import 'package:prism/widgets/shimmer_placeholder.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/providers/profile_provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:prism/screens/share_upload_screen.dart';
import 'package:prism/screens/processing_screen.dart';
import 'package:prism/screens/friends_screen.dart';
import 'package:prism/screens/profile_screen.dart';
import 'package:prism/screens/collections_screen.dart';
import 'package:prism/screens/image_viewer_screen.dart';
import 'package:prism/screens/notification_screen.dart';
import 'package:prism/widgets/prism_media_preview.dart';
import 'package:prism/widgets/pin_dialog.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:prism/providers/local_gallery_provider.dart';
import 'package:prism/widgets/album_card.dart';
import 'package:prism/screens/local_album_view_screen.dart';
import 'package:prism/screens/all_albums_screen.dart';
import 'package:prism/widgets/section_header.dart';
import 'package:prism/widgets/see_all_albums_card.dart';

class HomeScreen extends StatefulWidget {
  final int? initialNavIndex;

  const HomeScreen({super.key, this.initialNavIndex});

  static final GlobalKey<_HomeScreenState> homeScreenKey =
      GlobalKey<_HomeScreenState>();

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  bool _isSelectionMode = false;
  final Set<String> _selectedImageIds = {};
  final ImagePicker _picker = ImagePicker(); // Added picker

  // Tutorial keys
  final GlobalKey _uploadKey = GlobalKey();
  final GlobalKey _friendsKey = GlobalKey();
  bool _checkedTutorial = false;

  // Album selection state
  bool _isAlbumSelectionMode = false;
  int? _selectedAlbumIndex;
  final ScrollController _prismCloudScrollController = ScrollController();

  // Method to switch tabs from external screens
  void switchToTab(int index) {
    if (mounted) {
      setState(() {
        _currentNavIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    ShowcaseView.register(
      blurValue: 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.initialNavIndex != null) {
        switchToTab(widget.initialNavIndex!);
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final galleryProvider = Provider.of<GalleryProvider>(
        context,
        listen: false,
      );
      final notificationsProvider = Provider.of<NotificationsProvider>(
        context,
        listen: false,
      );
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );

      if (authProvider.currentUser != null) {
        // Seed ProfileProvider with the authenticated user's data immediately
        // so the profile screen is populated right away (before any network fetch).
        if (profileProvider.currentUser == null) {
          profileProvider.initializeWithUser(authProvider.currentUser!);
        }

        galleryProvider.fetchGallery(userId: authProvider.currentUser!.userId);
        notificationsProvider.setUserContext(
          profilePicId: authProvider.currentUser!.profilePicId,
        );
        notificationsProvider.fetchNotifications(
          authProvider.currentUser!.userId,
        );

        // Load local device albums
        final localGalleryProvider = Provider.of<LocalGalleryProvider>(
          context,
          listen: false,
        );
        localGalleryProvider.requestPermissionAndFetch();
      }

      if (!_checkedTutorial && mounted) {
        _checkedTutorial = true;
        final prefs = await SharedPreferences.getInstance();
        final seen = prefs.getBool('hasSeenTutorial') ?? false;
        if (!seen && mounted) {
          ShowcaseView.get().startShowCase([
            _uploadKey,
            _friendsKey,
          ]);
          await prefs.setBool('hasSeenTutorial', true);
        }
      }
    });
  }

  @override
  void dispose() {
    _prismCloudScrollController.dispose();
    super.dispose();
  }

  void _scrollPrismCloudToEnd() {
    if (_prismCloudScrollController.hasClients) {
      _prismCloudScrollController.animateTo(
        _prismCloudScrollController.position.maxScrollExtent,
        duration: 800.ms,
        curve: Curves.easeOutQuart,
      );
    }
  }

  void _toggleSelectionMode(String imageId) {
    setState(() {
      if (_selectedImageIds.contains(imageId)) {
        _selectedImageIds.remove(imageId);
        if (_selectedImageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedImageIds.add(imageId);
        _isSelectionMode = true;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedImageIds.clear();
    });
  }

  // New method to handle direct upload flow
  Future<void> _handleDirectShare() async {
    if (_isSelectionMode) _exitSelectionMode();

    try {
      final List<XFile> media = await _picker.pickMultipleMedia();
      if (media.isEmpty) return;

      if (!mounted) return;

      final files = media.map((xfile) => File(xfile.path)).toList();
      final sharingProvider = Provider.of<SharingProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.currentUser?.userId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please login to share')));
        return;
      }

      // Reset provider state first
      sharingProvider.reset();
      sharingProvider.addImages(files);

      // Start upload immediately
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting upload... 🚀'),
          backgroundColor: PrismColors.prismYellow,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Trigger upload in background but navigate immediately to processing
      // We don't await the result here because ProcessingScreen handles the "in progress" state
      sharingProvider.uploadImages(authProvider.currentUser!.userId);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProcessingScreen()),
      );
    } catch (e) {
      debugPrint('Error picking media: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final galleryProvider = Provider.of<GalleryProvider>(context);

    // data for the screens - ShareUploadScreen added back
    final List<Widget> screens = [
      _buildGalleryTab(galleryProvider, authProvider),
      const CollectionsScreen(),
      const ShareUploadScreen(), // Index 2
      const FriendsScreen(), // Index 3
      const ProfileScreen(), // Index 4
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: PrismColors.voidBlack, // Strict Void Black
      body: Stack(
        children: [
          // 1. Background Layer (Minimalist - No Orbs)
          Positioned.fill(child: Container(color: PrismColors.voidBlack)),

          // 2. Main Content
          SafeArea(
            bottom: false, // Let content go behind nav bar
            child: IndexedStack(index: _currentNavIndex, children: screens),
          ),

          // 3. Custom Bottom Navigation
          Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: _buildGlassNavBar(),
              )
              .animate()
              .fadeIn(duration: 600.ms, delay: 200.ms)
              .moveY(begin: 20, end: 0),
        ],
      ),
    );
  }

  Widget _buildGlassNavBar() {
    return GlassCard(
      borderRadius: 40,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      blurAmount: 25,
      color: PrismColors.glassDark,
      borderColor: PrismColors.white.withValues(alpha: 0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(0, Icons.grid_view_rounded, 'Gallery'),
          _navItem(1, Icons.collections_bookmark_rounded, 'Collections'),
          _floatingShareButton(),
          _navItem(3, Icons.people_alt_rounded, 'Friends'),
          _navItem(4, Icons.person_rounded, 'Profile'),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _currentNavIndex == index;
    Widget child = GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (_isSelectionMode) _exitSelectionMode();
        setState(() => _currentNavIndex = index);
      },
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? PrismColors.prismYellow.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child:
            Icon(
                  icon,
                  color: isSelected
                      ? PrismColors
                            .prismYellow // Active: Yellow
                      : PrismColors.secondaryText, // Inactive: Gray
                  size: 24,
                )
                .animate(target: isSelected ? 1 : 0)
                .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
      ),
    );

    if (index == 3) {
      return Showcase(
        key: _friendsKey,
        title: 'Friends',
        description: 'Find and add friends here to start sharing securely.',
        targetShapeBorder: const CircleBorder(),
        tooltipBackgroundColor: PrismColors.glassDark,
        textColor: Colors.white,
        child: child,
      );
    }
    return child;
  }

  Widget _floatingShareButton() {
    final isSelected = _currentNavIndex == 2;
    Widget child = GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (_isSelectionMode) _exitSelectionMode();

        // Reset sharing provider when switching to share tab
        final sharingProvider = Provider.of<SharingProvider>(
          context,
          listen: false,
        );
        sharingProvider.reset();

        setState(() => _currentNavIndex = 2);
      },
      child:
          Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? PrismColors.white
                      : PrismColors.prismYellow, // White when active
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isSelected
                                  ? PrismColors.white
                                  : PrismColors.prismYellow)
                              .withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: PrismColors.black,
                  size: 32,
                ),
              )
              .animate(target: isSelected ? 1 : 0) // Animate selection
              .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05)),
    );

    return Showcase(
      key: _uploadKey,
      title: 'Upload Moments',
      description: 'Tap here to capture or upload a new photo to share!',
      targetShapeBorder: const CircleBorder(),
      tooltipBackgroundColor: PrismColors.glassDark,
      textColor: Colors.white,
      child: child,
    );
  }

  Widget _buildGalleryTab(
    GalleryProvider galleryProvider,
    AuthProvider authProvider,
  ) {
    // Global loading check removed to allow local albums to show instantly

    if (galleryProvider.error != null) {
      return EmptyStateWidget.error(
        message: galleryProvider.error,
        onRetry: () {
          if (authProvider.currentUser != null) {
            galleryProvider.fetchGallery(
              userId: authProvider.currentUser!.userId,
            );
          }
        },
      );
    }

    // Full screen empty state removed to show dashboard always

    // Get images for Prism Cloud (Featured)
    final allImages = galleryProvider.allImages;
    final featuredImages = allImages.take(10).toList(); // Top 10 latest

    return RefreshIndicator(
      color: PrismColors.prismYellow,
      backgroundColor: PrismColors.surfaceGray,
      onRefresh: () async {
        if (authProvider.currentUser != null) {
          await galleryProvider.clearCacheAndRefresh(
            authProvider.currentUser!.userId,
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Header with Greeting
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              toolbarHeight: 70,
              title: _isSelectionMode
                  ? Text(
                      '${_selectedImageIds.length} Selected',
                      style: PrismTextStyles.h3,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Your Prism',
                          style: PrismTextStyles.h2.copyWith(
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '${allImages.length} memories stored',
                          style: PrismTextStyles.bodySmall.copyWith(
                            color: PrismColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
              actions: _isSelectionMode
                  ? _selectionActions(authProvider, galleryProvider)
                  : _defaultActions(),
            ),

            //const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // 2. Featured / Prism Cloud Section (Horizontal)
            if (galleryProvider.isLoading)
              SliverToBoxAdapter(
                child: Container(
                  height: 220,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, __) => ShimmerLayouts.rect(
                      width: 140,
                      height: 220,
                      borderRadius: 20,
                    ),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Your Memories',
                  //subtitle: 'Safely in the cloud',
                  actionLabel: 'View All',
                  actionIcon: Icons.arrow_forward_rounded,
                  onActionTap: featuredImages.length >= 2
                      ? _scrollPrismCloudToEnd
                      : null,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: ListView.separated(
                    controller: _prismCloudScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    itemCount: featuredImages.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Action Card: Upload
                        return GestureDetector(
                          onTap: _handleDirectShare,
                          child: Container(
                            width: 140,
                            decoration: BoxDecoration(
                              color: PrismColors.surfaceGray.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: PrismColors.prismYellow.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: PrismColors.prismYellow.withOpacity(
                                      0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: PrismColors.prismYellow,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "New Upload",
                                  style: PrismTextStyles.bodyMedium.copyWith(
                                    color: PrismColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final image = featuredImages[index - 1];
                      final isSelected = _selectedImageIds.contains(
                        image.image.id,
                      );

                      return GestureDetector(
                        onTap: () {
                          if (_isSelectionMode) {
                            HapticFeedback.selectionClick();
                            _toggleSelectionMode(image.image.id);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImageViewerScreen(
                                  images: featuredImages,
                                  initialIndex: index - 1,
                                  isFromBin: false,
                                  heroTagPrefix: 'home_image_',
                                  onShare: (file) async {
                                    final sharingProvider =
                                        Provider.of<SharingProvider>(
                                          context,
                                          listen: false,
                                        );
                                    sharingProvider.reset();
                                    sharingProvider.addImages([file]);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ShareUploadScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }
                        },
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          _toggleSelectionMode(image.image.id);
                        },
                        child: Container(
                          width: 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? Border.all(
                                    color: PrismColors.prismYellow,
                                    width: 3,
                                  )
                                : null,
                            boxShadow: [
                              if (!isSelected)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              isSelected ? 17 : 20,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Hero(
                                  tag: 'home_image_${image.image.id}',
                                  child: PrismMediaPreview(
                                    imageUrl: image.image.imageUrl,
                                    mediaType: image.image.mediaType,
                                    fit: BoxFit.cover,
                                    placeholderColor: PrismColors.surfaceGray,
                                  ),
                                ),
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.6),
                                        ],
                                        stops: const [0.7, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Positioned.fill(
                                    child: Container(
                                      color: PrismColors.prismYellow.withValues(
                                        alpha: 0.3,
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          color: PrismColors.black,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(duration: 300.ms),
                      );
                    },
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // 3. Device Albums Section (Grid)
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Device Albums',
                subtitle: 'On this phone',
              ),
            ),

            _buildDeviceAlbumsSectionSliver(),

            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ), // Bottom padding for nav bar
          ],
        ),
      ),
    );
  }

  // Refactored to return a SliverGrid directly for better scroll performance
  Widget _buildDeviceAlbumsSectionSliver() {
    return Consumer<LocalGalleryProvider>(
      builder: (context, localGalleryProvider, child) {
        // Responsive calculations
        final screenWidth = MediaQuery.of(context).size.width;

        int crossAxisCount;
        if (screenWidth < 600) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 3;
        }

        if (localGalleryProvider.isLoading &&
            localGalleryProvider.albums.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!localGalleryProvider.isPermissionChecked) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        if (!localGalleryProvider.hasPermission) {
          return SliverToBoxAdapter(
            child: _buildPermissionRequest(localGalleryProvider),
          );
        }

        if (localGalleryProvider.albums.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final albums = localGalleryProvider.albums;

        // Logic for View More
        // Show max 3 albums + 1 View More IF total > 4
        // If total <= 4, show all.
        final bool showViewMore = albums.length > 4;
        final int displayCount = showViewMore ? 4 : albums.length;

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              if (showViewMore && index == 3) {
                // View More Card
                // Get covers from next 4 albums (index 3, 4, 5, 6 if exist)
                List<AssetEntity> nextCovers = [];
                for (int i = 3; i < 7 && i < albums.length; i++) {
                  if (albums[i].coverAsset != null) {
                    nextCovers.add(albums[i].coverAsset!);
                  }
                }

                return SeeAllAlbumsCard(
                  covers: nextCovers,
                  albumCount: albums.length,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AllAlbumsScreen(),
                      ),
                    );
                  },
                );
              }

              final album = albums[index];
              final isSelected =
                  _isAlbumSelectionMode && _selectedAlbumIndex == index;

              return AlbumCard(
                title: album.name,
                assetCount: album.assetCount,
                coverAsset: album.coverAsset,
                width: double.infinity,
                height: double.infinity,
                isSelected: isSelected,
                selectionMode: _isAlbumSelectionMode,
                onTap: () {
                  if (_isAlbumSelectionMode) {
                    setState(() {
                      if (_selectedAlbumIndex == index) {
                        _selectedAlbumIndex = null;
                        _isAlbumSelectionMode = false;
                      } else {
                        _selectedAlbumIndex = index;
                      }
                    });
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LocalAlbumViewScreen(
                          album: album.album,
                          albumName: album.name,
                          assetCount: album.assetCount,
                        ),
                      ),
                    );
                  }
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _isAlbumSelectionMode = true;
                    _selectedAlbumIndex = index;
                  });
                  // Share dialog logic
                  _showAlbumShareDialog(album);
                },
              );
            }, childCount: displayCount),
          ),
        );
      },
    );
  }

  Widget _buildPermissionRequest(LocalGalleryProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PrismColors.surfaceGray,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PrismColors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.photo_library_rounded,
            color: PrismColors.secondaryText,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            "Access Your Photos",
            style: PrismTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Allow access to your device's gallery to view and share your photos directly from Prism.",
            style: PrismTextStyles.bodySmall.copyWith(
              color: PrismColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              final success = await provider.requestPermissionAndFetch(
                force: true,
              );
              if (!success && mounted) {
                // If failed again, it might be permanently denied. Show option to open settings?
                // For now just show a snackbar or the user can click again (which re-requests)
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: PrismColors.prismYellow,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: PrismColors.prismYellow.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: PrismColors.black,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Allow Access",
                    style: PrismTextStyles.button.copyWith(
                      color: PrismColors.black,
                      fontWeight: FontWeight.bold,
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

  // Removed old _buildDeviceAlbumsSection as it is replaced by _buildDeviceAlbumsSectionSliver

  /// Show dialog for sharing an album with 15 image limit
  void _showAlbumShareDialog(AlbumInfo albumInfo) {
    final count = albumInfo.assetCount;
    const maxAllowed = 15;

    if (count > maxAllowed) {
      // Album has too many images
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: PrismColors.surfaceGray,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Album Too Large',
            style: PrismTextStyles.h3.copyWith(color: PrismColors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This album has $count images.',
                style: PrismTextStyles.bodyMedium.copyWith(
                  color: PrismColors.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Maximum $maxAllowed images can be shared at once.',
                style: PrismTextStyles.bodyMedium.copyWith(
                  color: PrismColors.secondaryText,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Open the album to select specific images to share.',
                style: PrismTextStyles.bodySmall.copyWith(
                  color: PrismColors.prismYellow,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _isAlbumSelectionMode = false;
                  _selectedAlbumIndex = null;
                });
              },
              child: Text(
                'Cancel',
                style: PrismTextStyles.bodyMedium.copyWith(
                  color: PrismColors.secondaryText,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _isAlbumSelectionMode = false;
                  _selectedAlbumIndex = null;
                });
                // Navigate to album
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocalAlbumViewScreen(
                      album: albumInfo.album,
                      albumName: albumInfo.name,
                      assetCount: albumInfo.assetCount,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PrismColors.prismYellow,
                foregroundColor: PrismColors.black,
              ),
              child: const Text('Open Album'),
            ),
          ],
        ),
      );
    } else {
      // Album is within limit - show share confirmation
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: PrismColors.surfaceGray,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Share Album',
            style: PrismTextStyles.h3.copyWith(color: PrismColors.white),
          ),
          content: Text(
            'Share all $count images from "${albumInfo.name}" via Prism?',
            style: PrismTextStyles.bodyMedium.copyWith(
              color: PrismColors.secondaryText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _isAlbumSelectionMode = false;
                  _selectedAlbumIndex = null;
                });
              },
              child: Text(
                'Cancel',
                style: PrismTextStyles.bodyMedium.copyWith(
                  color: PrismColors.secondaryText,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _shareAlbumViaPrism(albumInfo);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PrismColors.prismYellow,
                foregroundColor: PrismColors.black,
              ),
              child: const Text('Share'),
            ),
          ],
        ),
      );
    }
  }

  /// Share album via Prism (extract file paths and navigate to ShareUploadScreen)
  Future<void> _shareAlbumViaPrism(AlbumInfo albumInfo) async {
    setState(() {
      _isAlbumSelectionMode = false;
      _selectedAlbumIndex = null;
    });

    // Show loading
    if (mounted) {
      ErrorHandler.showInfoSnackbar(context, message: 'Preparing album...');
    }

    try {
      // Get all assets from album
      final assets = await albumInfo.album.getAssetListRange(
        start: 0,
        end: albumInfo.assetCount,
      );

      // Extract file paths
      final filePaths = <String>[];
      for (final asset in assets) {
        final file = await asset.file;
        if (file != null) {
          filePaths.add(file.path);
        }
      }

      if (filePaths.isEmpty) {
        if (mounted) {
          ErrorHandler.showErrorSnackbar(
            context,
            message: 'Could not access album files',
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShareUploadScreen(sharedFilePaths: filePaths),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: 'Failed to prepare album: $e',
        );
      }
    }
  }

  List<Widget> _defaultActions() {
    return [
      Consumer<NotificationsProvider>(
        builder: (context, provider, child) {
          return IconButton(
            icon: Badge(
              isLabelVisible: provider.unreadCount > 0,
              label: Text('${provider.unreadCount}'),
              backgroundColor: PrismColors.prismYellow,
              textColor: PrismColors.black,
              child: const Icon(
                Icons.notifications_none_rounded,
                color: PrismColors.white,
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          );
        },
      ),
    ];
  }

  List<Widget> _selectionActions(
    AuthProvider authProvider,
    GalleryProvider galleryProvider,
  ) {
    return [
      IconButton(
        icon: const Icon(Icons.share_rounded, color: PrismColors.white),
        onPressed: () => _handleBulkShare(authProvider),
      ),
      IconButton(
        icon: const Icon(
          Icons.favorite_border_rounded,
          color: PrismColors.white,
        ),
        onPressed: () => _handleBulkFavourite(authProvider, galleryProvider),
      ),
      IconButton(
        icon: const Icon(Icons.archive_outlined, color: PrismColors.white),
        onPressed: () => _handleBulkArchive(authProvider, galleryProvider),
      ),
      IconButton(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: PrismColors.destructiveRed,
        ),
        onPressed: () => _handleBulkDelete(authProvider, galleryProvider),
      ),
      IconButton(
        icon: const Icon(Icons.close_rounded, color: PrismColors.white),
        onPressed: _exitSelectionMode,
      ),
    ];
  }

  // Bulk Actions
  Future<void> _handleBulkFavourite(
    AuthProvider authProvider,
    GalleryProvider galleryProvider,
  ) async {
    if (authProvider.currentUser == null) return;
    try {
      await galleryProvider.batchUpdateStatus(
        userId: authProvider.currentUser!.userId,
        imageIds: _selectedImageIds.toList(),
        field: 'favourite',
        value: true,
      );
      _exitSelectionMode();
      if (mounted) {
        ErrorHandler.showSuccessSnackbar(
          context,
          message: 'Added to favourites! 💖',
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: ErrorHandler.getErrorMessage(e),
        );
      }
    }
  }

  Future<void> _handleBulkShare(AuthProvider authProvider) async {
    final sharingProvider = Provider.of<SharingProvider>(
      context,
      listen: false,
    );
    final galleryProvider = Provider.of<GalleryProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: PrismColors.prismYellow),
      ),
    );

    try {
      final selectedImages = galleryProvider.allImages
          .where((img) => _selectedImageIds.contains(img.image.id))
          .toList();

      List<File> files = [];
      for (var img in selectedImages) {
        final file = await DefaultCacheManager().getSingleFile(
          img.image.imageUrl,
        );
        files.add(file);
      }

      // Reset state and upload
      sharingProvider.reset();
      sharingProvider.setSelectedImages(files);
      sharingProvider.uploadImages(authProvider.currentUser!.userId);

      if (mounted) {
        Navigator.pop(context);
        _exitSelectionMode();
        // Go straight to processing
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProcessingScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ErrorHandler.showErrorSnackbar(
          context,
          message: ErrorHandler.getErrorMessage(e),
        );
      }
    }
  }

  Future<void> _handleBulkDelete(
    AuthProvider authProvider,
    GalleryProvider galleryProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PrismColors.surfaceGray,
        title: Text('Move to Bin?', style: PrismTextStyles.h3),
        content: Text(
          'Are you surely you want to move these ${_selectedImageIds.length} items to the bin?',
          style: PrismTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: PrismColors.white.withValues(alpha: 0.6)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: PrismColors.destructiveRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && authProvider.currentUser != null) {
      await galleryProvider.batchUpdateStatus(
        userId: authProvider.currentUser!.userId,
        imageIds: _selectedImageIds.toList(),
        field: 'bin',
        value: true,
      );
      _exitSelectionMode();
    }
  }

  Future<void> _handleBulkArchive(
    AuthProvider authProvider,
    GalleryProvider galleryProvider,
  ) async {
    if (authProvider.currentUser == null) return;

    bool shouldProceed = false;

    if (authProvider.hasArchivePin) {
      // Pin Set
      shouldProceed = true;
    } else {
      // Pin Not Set, Prompt Setup
      final success = await showDialog<bool>(
        context: context,
        builder: (context) => PinDialog(
          isSettingPin: true,
          onConfirm: (pin) {
            authProvider.setArchivePin(pin);
            return true;
          },
        ),
      );
      if (success == true) {
        shouldProceed = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN set! Archiving items...'),
              backgroundColor: PrismColors.successGreen,
            ),
          );
        }
      }
    }

    if (shouldProceed) {
      try {
        await galleryProvider.batchUpdateStatus(
          userId: authProvider.currentUser!.userId,
          imageIds: _selectedImageIds.toList(),
          field: 'archive',
          value: true,
        );
        _exitSelectionMode();
        if (mounted) {
          ErrorHandler.showSuccessSnackbar(
            context,
            message: 'Moved to Archive 📦',
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showErrorSnackbar(
            context,
            message: ErrorHandler.getErrorMessage(e),
          );
        }
      }
    }
  }
}
