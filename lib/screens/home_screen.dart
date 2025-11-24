import 'package:flutter/material.dart';
import 'package:prism/utils/theme.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/providers/notifications_provider.dart';
import 'package:prism/models/gallery_image_model.dart';
import 'package:provider/provider.dart';
import 'package:prism/screens/onboarding_screen.dart';
import 'package:prism/screens/image_viewer_screen.dart';
import 'package:prism/screens/profile_screen.dart';
import 'package:prism/screens/friends_screen.dart';
import 'package:prism/screens/notifications_screen.dart';
import 'package:prism/screens/share_upload_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;
  int _currentNavIndex = 0;
  final List<String> _tabs = ['All', 'Favourites', 'Archived', 'Bin'];

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<String> _selectedImageIds = {};

  void _enterSelectionMode(String imageId) {
    setState(() {
      _isSelectionMode = true;
      _selectedImageIds.add(imageId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedImageIds.clear();
    });
  }

  void _toggleImageSelection(String imageId) {
    setState(() {
      if (_selectedImageIds.contains(imageId)) {
        _selectedImageIds.remove(imageId);
        if (_selectedImageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedImageIds.add(imageId);
      }
    });
  }

  void _selectAllInSection(List<GalleryImage> images) {
    setState(() {
      final imageIds = images.map((img) => img.image.id).toSet();
      if (imageIds.every((id) => _selectedImageIds.contains(id))) {
        // All selected, so deselect all
        _selectedImageIds.removeAll(imageIds);
        if (_selectedImageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        // Some or none selected, so select all
        _selectedImageIds.addAll(imageIds);
        _isSelectionMode = true;
      }
    });
  }

  bool _isAllSelectedInSection(List<GalleryImage> images) {
    final imageIds = images.map((img) => img.image.id).toSet();
    return imageIds.isNotEmpty &&
        imageIds.every((id) => _selectedImageIds.contains(id));
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index;
      });
    });

    // Fetch gallery and notifications on load
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
        // Fetch notifications
        notificationsProvider.fetchNotifications(
          authProvider.currentUser!.userId,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildNotificationIcon(Size size) {
    final notificationsProvider = Provider.of<NotificationsProvider>(context);
    final unreadCount = notificationsProvider.unreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_outlined,
            color: AppTheme.primaryText(context),
            size: size.width * 0.065,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: EdgeInsets.all(size.width * 0.01),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryBackground(context),
                  width: 1.5,
                ),
              ),
              constraints: BoxConstraints(
                minWidth: size.width * 0.045,
                minHeight: size.width * 0.045,
              ),
              child: Center(
                child: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size.width * 0.026,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryAccent),
      ),
    );

    try {
      // Clear image cache to free memory
      await DefaultCacheManager().emptyCache();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final galleryProvider = Provider.of<GalleryProvider>(
        context,
        listen: false,
      );

      // Clear gallery cache
      if (authProvider.currentUser != null) {
        await galleryProvider.clearCache(authProvider.currentUser!.userId);
      }

      // Logout user
      await authProvider.logout();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context);
    final galleryProvider = Provider.of<GalleryProvider>(context);

    return WillPopScope(
      onWillPop: () async {
        if (_isSelectionMode) {
          _exitSelectionMode();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppTheme.primaryBackground(context),
        body: IndexedStack(
          index: _currentNavIndex,
          children: [
            // Gallery Tab (index 0)
            SafeArea(
              child: Column(
                children: [
                  // Custom App Bar or Selection App Bar
                  _isSelectionMode
                      ? _buildSelectionAppBar(
                          size,
                          authProvider,
                          galleryProvider,
                        )
                      : _buildNormalAppBar(size),

                  // Tab Bar
                  Center(
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: Colors.transparent,
                      dividerColor: Colors.transparent,
                      labelPadding: EdgeInsets.symmetric(
                        horizontal: size.width * 0.06,
                      ),
                      tabs: _tabs.asMap().entries.map((entry) {
                        return _buildTab(entry.value, entry.key);
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: size.height * 0.02),

                  // Gallery Content
                  Expanded(
                    child: _buildTabContent(
                      galleryProvider,
                      authProvider,
                      size,
                    ),
                  ),
                ],
              ),
            ),
            // Share Tab (index 1)
            const ShareUploadScreen(),
            // Friends Tab (index 2)
            const FriendsScreen(),
            // Profile Tab (index 3)
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(size),
      ),
    );
  }

  Widget _buildNormalAppBar(Size size) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.04,
        vertical: size.height * 0.015,
      ),
      child: Row(
        children: [
          Text(
            'Pictures',
            style: TextStyle(
              color: AppTheme.primaryText(context),
              fontSize: size.width * 0.055,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.search,
              color: AppTheme.primaryText(context),
              size: size.width * 0.065,
            ),
            onPressed: () {},
          ),
          _buildNotificationIcon(size),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: AppTheme.primaryText(context),
              size: size.width * 0.065,
            ),
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionAppBar(
    Size size,
    AuthProvider authProvider,
    GalleryProvider galleryProvider,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.04,
        vertical: size.height * 0.015,
      ),
      color: AppTheme.primaryBackground(context),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.close,
              color: AppTheme.primaryText(context),
              size: size.width * 0.065,
            ),
            onPressed: _exitSelectionMode,
          ),
          Text(
            '${_selectedImageIds.length} selected',
            style: TextStyle(
              color: AppTheme.primaryText(context),
              fontSize: size.width * 0.045,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              color: AppTheme.primaryText(context),
              size: size.width * 0.065,
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/share');
            },
          ),
          IconButton(
            icon: Icon(
              Icons.favorite_border,
              color: AppTheme.primaryText(context),
              size: size.width * 0.065,
            ),
            onPressed: () =>
                _handleBulkFavourite(authProvider, galleryProvider),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: AppTheme.primaryText(context),
              size: size.width * 0.065,
            ),
            onPressed: () => _handleBulkDelete(authProvider, galleryProvider),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red,
              size: size.width * 0.065,
            ),
            onPressed: () => _handleBulkDelete(authProvider, galleryProvider),
          ),
        ],
      ),
    );
  }

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
          SnackBar(
            content: Text(
              '${_selectedImageIds.length} images added to favourites',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to favourites: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleBulkArchive(
    AuthProvider authProvider,
    GalleryProvider galleryProvider,
  ) async {
    if (authProvider.currentUser == null) return;

    try {
      await galleryProvider.batchUpdateStatus(
        userId: authProvider.currentUser!.userId,
        imageIds: _selectedImageIds.toList(),
        field: 'archive',
        value: true,
      );

      _exitSelectionMode();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedImageIds.length} images archived'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to archive: $e'),
            backgroundColor: Colors.red,
          ),
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
        backgroundColor: AppTheme.darkBackground,
        title: Text(
          'Move to Bin?',
          style: TextStyle(color: AppTheme.darkPrimaryText),
        ),
        content: Text(
          'Move ${_selectedImageIds.length} images to the bin?',
          style: TextStyle(color: AppTheme.darkSecondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.darkSecondaryText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Move to Bin',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && authProvider.currentUser != null) {
      try {
        await galleryProvider.batchUpdateStatus(
          userId: authProvider.currentUser!.userId,
          imageIds: _selectedImageIds.toList(),
          field: 'bin',
          value: true,
        );

        _exitSelectionMode();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_selectedImageIds.length} images moved to bin'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to move to bin: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildBottomNavigationBar(Size size) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: size.height * 0.01),
      decoration: BoxDecoration(
        color: AppTheme.primaryBackground(context),
        border: Border(
          top: BorderSide(
            color: AppTheme.tertiaryText(context).withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            index: 0,
            size: size,
          ),
          _buildNavItem(
            icon: Icons.share_outlined,
            label: 'Share',
            index: 1,
            size: size,
          ),
          _buildNavItem(
            icon: Icons.people_outline,
            label: 'Friends',
            index: 2,
            size: size,
          ),
          _buildNavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            index: 3,
            size: size,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required Size size,
  }) {
    final isSelected = _currentNavIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentNavIndex = index;
        });

        // Navigate to share screen when Share tab is tapped
        if (index == 1) {
          Navigator.pushNamed(context, '/share');
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.04,
          vertical: size.height * 0.01,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primaryAccent
                  : AppTheme.tertiaryText(context),
              size: size.width * 0.065,
            ),
            SizedBox(height: size.height * 0.004),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.primaryAccent
                    : AppTheme.tertiaryText(context),
                fontSize: size.width * 0.028,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(
    GalleryProvider galleryProvider,
    AuthProvider authProvider,
    Size size,
  ) {
    if (galleryProvider.isLoading && !galleryProvider.isLoadingFromCache) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryAccent),
      );
    }

    // Show error if exists
    if (galleryProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: size.width * 0.15,
            ),
            SizedBox(height: size.height * 0.02),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.1),
              child: Text(
                galleryProvider.error!,
                style: TextStyle(
                  color: AppTheme.secondaryText(context),
                  fontSize: size.width * 0.04,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: size.height * 0.02),
            ElevatedButton(
              onPressed: () {
                if (authProvider.currentUser != null) {
                  galleryProvider.refresh(authProvider.currentUser!.userId);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final currentTab = _tabs[_selectedTab];
    final groupedImages = galleryProvider.getGroupedImagesByTab(currentTab);

    debugPrint(
      'Building tab content for $currentTab: ${groupedImages.length} groups, ${galleryProvider.images.length} total images',
    );

    if (groupedImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: AppTheme.darkTertiaryText,
              size: size.width * 0.2,
            ),
            SizedBox(height: size.height * 0.02),
            Text(
              'No images in $currentTab',
              style: TextStyle(
                color: AppTheme.darkSecondaryText,
                fontSize: size.width * 0.045,
              ),
            ),
            SizedBox(height: size.height * 0.01),
            Text(
              'Total images: ${galleryProvider.images.length}',
              style: TextStyle(
                color: AppTheme.darkTertiaryText,
                fontSize: size.width * 0.03,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (authProvider.currentUser != null) {
          await galleryProvider.refresh(authProvider.currentUser!.userId);
        }
      },
      color: AppTheme.primaryAccent,
      backgroundColor: AppTheme.darkBackground,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
        itemCount: groupedImages.length,
        itemBuilder: (context, index) {
          final monthKey = groupedImages.keys.elementAt(index);
          final images = groupedImages[monthKey]!;

          return _buildMonthSection(context, monthKey, images, size);
        },
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _selectedTab == index;
    final size = MediaQuery.of(context).size;

    return Tab(
      height: 44,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getTabIcon(title),
            color: isSelected
                ? AppTheme.primaryText(context)
                : AppTheme.tertiaryText(context),
            size: size.width * 0.055,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: isSelected
                  ? AppTheme.primaryText(context)
                  : AppTheme.tertiaryText(context),
              fontSize: size.width * 0.028,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTabIcon(String title) {
    switch (title) {
      case 'All':
        return Icons.grid_view;
      case 'Favourites':
        return Icons.favorite_border;
      case 'Archived':
        return Icons.archive_outlined;
      case 'Bin':
        return Icons.delete_outline;
      default:
        return Icons.photo;
    }
  }

  Widget _buildMonthSection(
    BuildContext context,
    String month,
    List<GalleryImage> images,
    Size size,
  ) {
    final allSelected = _isAllSelectedInSection(images);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: size.height * 0.015),
          child: Row(
            children: [
              Text(
                month,
                style: TextStyle(
                  color: AppTheme.secondaryText(context),
                  fontSize: size.width * 0.035,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (_isSelectionMode)
                TextButton.icon(
                  onPressed: () => _selectAllInSection(images),
                  icon: Icon(
                    allSelected
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: AppTheme.primaryAccent,
                    size: 18,
                  ),
                  label: Text(
                    allSelected ? 'Deselect All' : 'Select All',
                    style: TextStyle(
                      color: AppTheme.primaryAccent,
                      fontSize: size.width * 0.03,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.02,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: size.width * 0.01,
            mainAxisSpacing: size.width * 0.01,
            childAspectRatio: 1,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final image = images[index];

            // Show +count overlay on last item if there are many images
            final isLastItem = index == images.length - 1;
            final hasMoreImages = images.length > 9 && isLastItem && index >= 8;
            final remainingCount = images.length - 9;

            final isSelected = _selectedImageIds.contains(image.image.id);

            return GestureDetector(
              onTap: () {
                if (_isSelectionMode) {
                  _toggleImageSelection(image.image.id);
                } else {
                  // Open image viewer with hero animation
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageViewerScreen(
                        images: images,
                        initialIndex: index,
                        isFromBin: _tabs[_selectedTab] == 'Bin',
                      ),
                    ),
                  );
                }
              },
              onLongPress: () {
                if (!_isSelectionMode) {
                  _enterSelectionMode(image.image.id);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Hero(
                      tag: 'image_${image.image.id}',
                      child: CachedNetworkImage(
                        imageUrl: image.image.imageUrl,
                        fit: BoxFit.cover,
                        maxHeightDiskCache: 400,
                        maxWidthDiskCache: 400,
                        memCacheHeight: 200,
                        memCacheWidth: 200,
                        placeholder: (context, url) => Container(
                          color: AppTheme.dotInactive(context),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryAccent,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppTheme.dotInactive(context),
                          child: Icon(
                            Icons.broken_image,
                            color: AppTheme.tertiaryText(context),
                            size: size.width * 0.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Selection overlay
                  if (_isSelectionMode)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isSelected
                            ? AppTheme.primaryAccent.withOpacity(0.3)
                            : Colors.black.withOpacity(0.3),
                        border: isSelected
                            ? Border.all(
                                color: AppTheme.primaryAccent,
                                width: 3,
                              )
                            : null,
                      ),
                    ),
                  // Checkbox
                  if (_isSelectionMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppTheme.primaryAccent
                              : Colors.white.withOpacity(0.7),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryAccent
                                : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  if (hasMoreImages && !_isSelectionMode)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.black.withOpacity(0.6),
                      ),
                      child: Center(
                        child: Text(
                          '+$remainingCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size.width * 0.08,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        SizedBox(height: size.height * 0.02),
      ],
    );
  }
}
