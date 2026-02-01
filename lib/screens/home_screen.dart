import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/widgets/empty_state_widget.dart';
import 'package:prism/widgets/shimmer_placeholder.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/gallery_provider.dart';
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
import 'package:prism/utils/responsive_helper.dart';
import 'package:prism/providers/local_gallery_provider.dart';
import 'package:prism/widgets/album_card.dart';
import 'package:prism/widgets/see_all_albums_card.dart';
import 'package:prism/screens/local_album_view_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
  bool _isDeviceAlbumsExpanded = false;

  // Album selection state
  bool _isAlbumSelectionMode = false;
  int? _selectedAlbumIndex;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final galleryProvider = Provider.of<GalleryProvider>(
        context,
        listen: false,
      );
      final notificationsProvider = Provider.of<NotificationsProvider>(
        context,
        listen: false,
      );

      if (authProvider.currentUser != null) {
        galleryProvider.fetchGallery(userId: authProvider.currentUser!.userId);
        notificationsProvider.fetchNotifications(
          authProvider.currentUser!.userId,
        );

        // Check backend contacts in background (non-blocking)
        _checkContactsInBackground(authProvider);

        // Load local device albums
        final localGalleryProvider = Provider.of<LocalGalleryProvider>(
          context,
          listen: false,
        );
        localGalleryProvider.requestPermissionAndFetch();
      }
    });
  }

  Future<void> _checkContactsInBackground(AuthProvider authProvider) async {
    try {
      final hasBackendContacts = await authProvider.checkBackendContacts();

      // Only show sync dialog if user has no contacts synced
      if (mounted && !authProvider.contactsSynced && !hasBackendContacts) {
        // Optional: Show a bottom sheet or banner to sync contacts
        // For now, keeping it silent as contact sync can be done from settings
      }
    } catch (e) {
      // Silent fail - contact check is not critical
      debugPrint('Background contact check failed: $e');
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      blurAmount: 20,
      color: PrismColors.glassDark,
      borderColor: PrismColors.white.withValues(alpha: 0.05),
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
    return GestureDetector(
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
  }

  Widget _floatingShareButton() {
    final isSelected = _currentNavIndex == 2;
    return GestureDetector(
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
  }

  Widget _buildGalleryTab(
    GalleryProvider galleryProvider,
    AuthProvider authProvider,
  ) {
    // Responsive grid count
    final screenWidth = MediaQuery.of(context).size.width;
    final gridCrossAxisCount = ResponsiveHelper.galleryGridCount(context);
    final gridSpacing = screenWidth < 360 ? 2.0 : 4.0;

    if (galleryProvider.isLoading) {
      // Show shimmer loading grid
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveHelper.horizontalPadding(context),
        ),
        child: ShimmerLayouts.galleryGrid(
          itemCount: 9,
          crossAxisCount: gridCrossAxisCount,
        ),
      );
    }

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

    final images = galleryProvider.allImages;

    if (images.isEmpty) {
      return EmptyStateWidget.noMedia(onAddMedia: _handleDirectShare);
    }

    // Get images grouped by month
    final groupedImages = galleryProvider.getGroupedImagesByTab('All');

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
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              title: _isSelectionMode
                  ? Text(
                      '${_selectedImageIds.length} Selected',
                      style: PrismTextStyles.h3,
                    )
                  : Text('Your Prism', style: PrismTextStyles.h2),
              actions: _isSelectionMode
                  ? _selectionActions(authProvider, galleryProvider)
                  : _defaultActions(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Prism Cloud Section (First priority)
            if (images.isEmpty)
              // Empty Prism Cloud State
              SliverToBoxAdapter(child: _buildPrismCloudEmptyState()),

            if (images.isNotEmpty)
              // Prism Cloud header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_rounded,
                        color: PrismColors.prismYellow,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Prism Cloud',
                        style: PrismTextStyles.h3.copyWith(
                          color: PrismColors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${images.length} items',
                        style: PrismTextStyles.bodySmall.copyWith(
                          color: PrismColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Month-grouped images
            if (images.isNotEmpty)
              ...groupedImages.entries.map((entry) {
                return SliverMainAxisGroup(
                  slivers: [
                    // Month header
                    

                    // Images grid for this month
                    SliverMasonryGrid.count(
                      crossAxisCount: gridCrossAxisCount,
                      mainAxisSpacing: gridSpacing,
                      crossAxisSpacing: gridSpacing,
                      childCount: entry.value.length,
                      itemBuilder: (context, index) {
                        final image = entry.value[index];
                        final isSelected = _selectedImageIds.contains(
                          image.image.id,
                        );

                        return GestureDetector(
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            _toggleSelectionMode(image.image.id);
                          },
                          onTap: () {
                            if (_isSelectionMode) {
                              HapticFeedback.selectionClick();
                              _toggleSelectionMode(image.image.id);
                            } else {
                              // Open Viewer with Hero animation
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ImageViewerScreen(
                                    images: entry.value,
                                    initialIndex: index,
                                    isFromBin: false,
                                    onShare: (file) async {
                                      // Add to sharing provider and navigate to share screen
                                      final sharingProvider =
                                          Provider.of<SharingProvider>(
                                            context,
                                            listen: false,
                                          );
                                      sharingProvider.reset();
                                      sharingProvider.addImages([file]);

                                      // Navigate to share upload screen
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
                          child:
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    8,
                                  ), // Smaller radius for tighter grid
                                  border: isSelected
                                      ? Border.all(
                                          color: PrismColors.prismYellow,
                                          width: 3,
                                        )
                                      : null,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Stack(
                                    fit: StackFit.passthrough,
                                    children: [
                                      Hero(
                                        tag: 'image_${image.image.id}',
                                        child: PrismMediaPreview(
                                          imageUrl: image.image.imageUrl,
                                          mediaType: image.image.mediaType,
                                          fit: BoxFit.cover,
                                          placeholderColor:
                                              PrismColors.surfaceGray,
                                        ),
                                      ),
                                      if (isSelected)
                                        Positioned.fill(
                                          child: Container(
                                            color: PrismColors.prismYellow
                                                .withValues(alpha: 0.3),
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
                              ).animate().fadeIn(
                                duration: 300.ms,
                                delay: (30 * (index % 10)).ms,
                              ),
                        );
                      },
                    ),
                  ],
                );
              }),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildDeviceAlbumsSection()),

            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ), // Bottom padding for nav bar
          ],
        ),
      ),
    );
  }

  /// Build empty state for Prism Cloud
  Widget _buildPrismCloudEmptyState() {
    return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PrismColors.surfaceGray.withValues(alpha: 0.5),
                PrismColors.surfaceGray.withValues(alpha: 0.3),
              ],
            ),
            border: Border.all(color: PrismColors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: 64,
                color: PrismColors.prismYellow.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'Prism Cloud',
                style: PrismTextStyles.h3.copyWith(color: PrismColors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Share memories to store in Prism Cloud',
                style: PrismTextStyles.bodyMedium.copyWith(
                  color: PrismColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _handleDirectShare(),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add Memories'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PrismColors.prismYellow,
                  foregroundColor: PrismColors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 400.ms,
        );
  }

  /// Build the Device Albums section with 2-column grid
  Widget _buildDeviceAlbumsSection() {
    return Consumer<LocalGalleryProvider>(
      builder: (context, localGalleryProvider, child) {
        // Responsive calculations
        final screenWidth = MediaQuery.of(context).size.width;
        final horizontalPadding = ResponsiveHelper.horizontalPadding(context);

        // Calculate grid parameters based on screen width
        int crossAxisCount;
        double cardWidth;
        if (screenWidth < 360) {
          crossAxisCount = 2;
          cardWidth = (screenWidth - (horizontalPadding * 2) - 12) / 2;
        } else if (screenWidth < 600) {
          crossAxisCount = 2;
          cardWidth = (screenWidth - (horizontalPadding * 2) - 12) / 2;
        } else {
          crossAxisCount = 3;
          cardWidth = (screenWidth - (horizontalPadding * 2) - 24) / 3;
        }

        final cardHeight = cardWidth * 1.15; // Slightly taller aspect ratio

        if (localGalleryProvider.isLoading &&
            localGalleryProvider.albums.isEmpty) {
          // Show shimmer loading
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.photo_library_rounded,
                    color: PrismColors.secondaryText,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Device Albums',
                    style: PrismTextStyles.h3.copyWith(
                      color: PrismColors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: cardWidth / cardHeight,
                ),
                itemCount: 4,
                itemBuilder: (context, index) => Container(
                  decoration: BoxDecoration(
                    color: PrismColors.surfaceGray,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          );
        }

        if (!localGalleryProvider.hasPermission) {
          // Show permission request
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.photo_library_rounded,
                    color: PrismColors.secondaryText,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Device Albums',
                    style: PrismTextStyles.h3.copyWith(
                      color: PrismColors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => localGalleryProvider.requestPermissionAndFetch(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PrismColors.surfaceGray,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: PrismColors.prismYellow.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_open_rounded,
                        color: PrismColors.prismYellow,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap to allow access to your photos',
                          style: PrismTextStyles.bodyMedium.copyWith(
                            color: PrismColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        if (localGalleryProvider.albums.isEmpty) {
          return const SizedBox.shrink();
        }

        // Determine visible albums
        final totalAlbums = localGalleryProvider.albums.length;
        final maxInitialAlbums = 6;
        final shouldShowSeeAll = totalAlbums > maxInitialAlbums;

        List<Widget> albumCards = [];

        // Calculate number of albums to show
        final albumsToShow = _isDeviceAlbumsExpanded || !shouldShowSeeAll
            ? totalAlbums
            : maxInitialAlbums;

        // Build album cards
        for (int i = 0; i < albumsToShow; i++) {
          final albumInfo = localGalleryProvider.albums[i];
          final isSelected = _isAlbumSelectionMode && _selectedAlbumIndex == i;
          albumCards.add(
            AlbumCard(
              title: albumInfo.name,
              assetCount: albumInfo.assetCount,
              thumbnail: albumInfo.thumbnail,
              width: cardWidth,
              height: cardHeight,
              isSelected: isSelected,
              selectionMode: _isAlbumSelectionMode,
              onTap: () {
                if (_isAlbumSelectionMode) {
                  // Toggle selection
                  setState(() {
                    if (_selectedAlbumIndex == i) {
                      _selectedAlbumIndex = null;
                      _isAlbumSelectionMode = false;
                    } else {
                      _selectedAlbumIndex = i;
                    }
                  });
                } else {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocalAlbumViewScreen(
                        album: albumInfo.album,
                        albumName: albumInfo.name,
                        assetCount: albumInfo.assetCount,
                      ),
                    ),
                  );
                }
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _isAlbumSelectionMode = true;
                  _selectedAlbumIndex = i;
                });
                // Show share dialog
                _showAlbumShareDialog(albumInfo);
              },
            ),
          );
        }

        // Add "See All" / "Show Less" card if needed
        if (shouldShowSeeAll && !_isAlbumSelectionMode) {
          albumCards.add(
            SeeAllAlbumsCard(
              isExpanded: _isDeviceAlbumsExpanded,
              remainingCount: _isDeviceAlbumsExpanded
                  ? 0
                  : totalAlbums - maxInitialAlbums,
              width: cardWidth,
              height: cardHeight,
              onTap: () {
                setState(() {
                  _isDeviceAlbumsExpanded = !_isDeviceAlbumsExpanded;
                });
              },
            ),
          );
        }

        // Show albums in grid
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.photo_library_rounded,
                  color: PrismColors.prismYellow,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Device Albums',
                  style: PrismTextStyles.h3.copyWith(color: PrismColors.white),
                ),
                const Spacer(),
                Text(
                  '$totalAlbums albums',
                  style: PrismTextStyles.bodySmall.copyWith(
                    color: PrismColors.secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: 300.ms,
              curve: Curves.easeInOut,
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: cardWidth / cardHeight,
                children: albumCards,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms);
      },
    );
  }

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
