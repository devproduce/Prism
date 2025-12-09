import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:prism/screens/share_upload_screen.dart';
import 'package:prism/screens/friends_screen.dart';
import 'package:prism/screens/profile_screen.dart';
import 'package:prism/screens/collections_screen.dart';
import 'package:prism/screens/image_viewer_screen.dart';
import 'package:prism/screens/notification_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final galleryProvider = Provider.of<GalleryProvider>(context);

    // data for the screens
    final List<Widget> screens = [
      _buildGalleryTab(galleryProvider, authProvider),
      const CollectionsScreen(), // Needs update later
      const ShareUploadScreen(), // Needs update later
      const FriendsScreen(), // Needs update later
      const ProfileScreen(), // Needs update later
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: PrismColors.darkBase, // Fallback
      body: Stack(
        children: [
          // 1. Background Layer
          _buildBackground(),

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

  Widget _buildBackground() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(gradient: PrismColors.royalNightFade),
        ),
        // Abstract Orbs
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PrismColors.primaryBlue.withOpacity(0.15),
              boxShadow: [
                BoxShadow(
                  color: PrismColors.glassBlueGlow,
                  blurRadius: 100,
                  spreadRadius: 50,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          right: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PrismColors.accentBlue.withOpacity(0.12),
              boxShadow: [
                BoxShadow(
                  color: PrismColors.accentBlue.withOpacity(0.15),
                  blurRadius: 80,
                  spreadRadius: 40,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassNavBar() {
    return GlassCard(
      borderRadius: 40,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      blurAmount: 20,
      color: PrismColors.glassDark,
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
        if (_isSelectionMode) _exitSelectionMode();
        setState(() => _currentNavIndex = index);
      },
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? PrismColors.purple.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                  icon,
                  color: isSelected ? PrismColors.electricBlue : Colors.white60,
                  size: 24,
                )
                .animate(target: isSelected ? 1 : 0)
                .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: PrismColors.neoPink,
                ),
              ).animate().fadeIn(),
          ],
        ),
      ),
    );
  }

  Widget _floatingShareButton() {
    final isSelected = _currentNavIndex == 2;
    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) _exitSelectionMode();
        setState(() => _currentNavIndex = 2);
      },
      child:
          Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: PrismColors.prismSignature,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: PrismColors.purple.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(Icons.add_rounded, color: Colors.white, size: 32),
              )
              .animate(target: isSelected ? 1 : 0)
              .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
    );
  }

  Widget _buildGalleryTab(
    GalleryProvider galleryProvider,
    AuthProvider authProvider,
  ) {
    if (galleryProvider.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: PrismColors.purple),
      );
    }

    if (galleryProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: PrismColors.errorRed,
            ),
            const SizedBox(height: 16),
            Text(galleryProvider.error!, style: PrismTextStyles.bodyMedium),
            const SizedBox(height: 16),
            GlassButton(
              text: 'Retry',
              onPressed: () {
                if (authProvider.currentUser != null) {
                  galleryProvider.fetchGallery(
                    userId: authProvider.currentUser!.userId,
                  );
                }
              },
              width: 120,
              height: 48,
            ),
          ],
        ),
      );
    }

    final images = galleryProvider.allImages;

    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_search_rounded,
              size: 64,
              color: PrismColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text('No memories yet.', style: PrismTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              'Upload your first photo to get started!',
              style: PrismTextStyles.bodyMedium.copyWith(
                color: PrismColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Get images grouped by month
    final groupedImages = galleryProvider.getGroupedImagesByTab('All');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomScrollView(
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

          // Month-grouped images
          ...groupedImages.entries.map((entry) {
            return SliverMainAxisGroup(
              slivers: [
                // Month header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                    child: Text(
                      entry.key,
                      style: PrismTextStyles.h3.copyWith(
                        color: PrismColors.electricBlue,
                      ),
                    ),
                  ),
                ),

                // Images grid for this month
                SliverMasonryGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childCount: entry.value.length,
                  itemBuilder: (context, index) {
                    final image = entry.value[index];
                    final isSelected = _selectedImageIds.contains(
                      image.image.id,
                    );

                    return GestureDetector(
                      onLongPress: () => _toggleSelectionMode(image.image.id),
                      onTap: () {
                        if (_isSelectionMode) {
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
                                onShare: (file) {
                                  final sharingProvider =
                                      Provider.of<SharingProvider>(
                                        context,
                                        listen: false,
                                      );
                                  sharingProvider.setSelectedImages([file]);
                                  Navigator.pop(context);
                                  setState(() => _currentNavIndex = 2);
                                },
                              ),
                            ),
                          );
                        }
                      },
                      child:
                          AnimatedContainer(
                                duration: 200.ms,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: isSelected
                                      ? Border.all(
                                          color: PrismColors.electricBlue,
                                          width: 3,
                                        )
                                      : Border.all(
                                          color: Colors.white.withOpacity(0.1),
                                          width: 1,
                                        ),
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
                                  borderRadius: BorderRadius.circular(18),
                                  child: Stack(
                                    fit: StackFit.passthrough,
                                    children: [
                                      Hero(
                                        tag: 'image_${image.image.id}',
                                        child: CachedNetworkImage(
                                          imageUrl: image.image.imageUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                                height: 150,
                                                color: PrismColors
                                                    .glassFrostedWhite,
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              ),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                                height: 150,
                                                color: PrismColors
                                                    .glassFrostedWhite,
                                                child: const Icon(
                                                  Icons.broken_image_rounded,
                                                  color: Colors.white38,
                                                ),
                                              ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Positioned.fill(
                                          child: Container(
                                            color: PrismColors.electricBlue
                                                .withOpacity(0.3),
                                            child: const Center(
                                              child: Icon(
                                                Icons.check_circle_rounded,
                                                color: Colors.white,
                                                size: 40,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                              .animate()
                              .fadeIn(
                                duration: 400.ms,
                                delay: (50 * (index % 10)).ms,
                              )
                              .slideY(begin: 0.1, end: 0),
                    );
                  },
                ),
              ],
            );
          }).toList(),

          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ), // Bottom padding for nav bar
        ],
      ),
    );
  }

  List<Widget> _defaultActions() {
    return [
      Consumer<NotificationsProvider>(
        builder: (context, provider, child) {
          return IconButton(
            icon: Badge(
              isLabelVisible: provider.unreadCount > 0,
              label: Text('${provider.unreadCount}'),
              backgroundColor: PrismColors.neoPink,
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
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
        icon: const Icon(Icons.share_rounded, color: Colors.white),
        onPressed: () => _handleBulkShare(authProvider),
      ),
      IconButton(
        icon: const Icon(Icons.favorite_border_rounded, color: Colors.white),
        onPressed: () => _handleBulkFavourite(authProvider, galleryProvider),
      ),
      IconButton(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: PrismColors.errorRed,
        ),
        onPressed: () => _handleBulkDelete(authProvider, galleryProvider),
      ),
      IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to favourites! 💖'),
            backgroundColor: PrismColors.neoPink,
          ),
        );
      }
    } catch (e) {
      // Error handling
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
      builder: (context) =>
          Center(child: CircularProgressIndicator(color: PrismColors.purple)),
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

      sharingProvider.setSelectedImages(files);

      if (mounted) {
        Navigator.pop(context);
        _exitSelectionMode();
        setState(() => _currentNavIndex = 2);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        // error feedback
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
        backgroundColor: PrismColors.darkCard,
        title: Text('Move to Bin?', style: PrismTextStyles.h3),
        content: Text(
          'Are you surely you want to move these ${_selectedImageIds.length} items to the bin?',
          style: PrismTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: PrismColors.errorRed,
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
}
