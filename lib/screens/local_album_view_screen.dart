import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:prism/screens/local_image_viewer_screen.dart';
import 'package:prism/screens/share_upload_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:prism/widgets/glass_widgets.dart';

/// Screen to view assets within a local album.
/// Features: Grid view, selection mode, Prism sharing, tap-to-open viewer
class LocalAlbumViewScreen extends StatefulWidget {
  final AssetPathEntity album;
  final String albumName;
  final int assetCount;

  const LocalAlbumViewScreen({
    super.key,
    required this.album,
    required this.albumName,
    required this.assetCount,
  });

  @override
  State<LocalAlbumViewScreen> createState() => _LocalAlbumViewScreenState();
}

class _LocalAlbumViewScreenState extends State<LocalAlbumViewScreen> {
  final List<AssetEntity> _assets = [];
  final Set<int> _selectedIndices = {};
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _hasMore = true;
  bool _isSelectionMode = false;
  int _currentPage = 0;
  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _loadAssets();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 500 &&
        !_isLoading &&
        _hasMore) {
      _loadAssets();
    }
  }

  Future<void> _loadAssets() async {
    if (_isLoading && _currentPage > 0) return;

    setState(() => _isLoading = true);

    try {
      final assets = await widget.album.getAssetListPaged(
        page: _currentPage,
        size: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _assets.addAll(assets);
        _currentPage++;
        _hasMore = assets.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error loading assets: $e');
    }
  }

  void _toggleSelection(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _startSelectionMode(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedIndices.add(index);
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
  }

  void _selectAll() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndices.clear();
      for (int i = 0; i < _assets.length; i++) {
        _selectedIndices.add(i);
      }
    });
  }

  Future<void> _shareSelectedViaPrism() async {
    if (_selectedIndices.isEmpty) return;

    HapticFeedback.mediumImpact();

    // Get file paths for selected assets
    final filePaths = <String>[];

    for (final index in _selectedIndices) {
      final asset = _assets[index];
      final file = await asset.file;
      if (file != null) {
        filePaths.add(file.path);
      }
    }

    if (filePaths.isEmpty) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: 'Could not access selected files',
        );
      }
      return;
    }

    if (mounted) {
      _cancelSelection();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShareUploadScreen(sharedFilePaths: filePaths),
        ),
      );
    }
  }

  void _openAsset(int index) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LocalImageViewerScreen(assets: _assets, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App Bar
          SliverAppBar(
            backgroundColor: PrismColors.voidBlack,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            expandedHeight: _isSelectionMode ? 60 : 100,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: PrismColors.white,
              ),
              onPressed: () {
                if (_isSelectionMode) {
                  _cancelSelection();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: _isSelectionMode
                ? Text(
                    '${_selectedIndices.length} Selected',
                    style: PrismTextStyles.h3.copyWith(
                      color: PrismColors.white,
                    ),
                  )
                : null,
            flexibleSpace: _isSelectionMode
                ? null
                : FlexibleSpaceBar(
                    title: Text(
                      widget.albumName,
                      style: PrismTextStyles.h3.copyWith(
                        color: PrismColors.white,
                      ),
                    ),
                    titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                  ),
            actions: _isSelectionMode
                ? [
                    // Select All
                    TextButton(
                      onPressed: _selectAll,
                      child: Text(
                        'Select All',
                        style: PrismTextStyles.bodyMedium.copyWith(
                          color: PrismColors.prismYellow,
                        ),
                      ),
                    ),
                    // Share
                    IconButton(
                      icon: const Icon(
                        Icons.share_rounded,
                        color: PrismColors.prismYellow,
                      ),
                      onPressed: _selectedIndices.isNotEmpty
                          ? _shareSelectedViaPrism
                          : null,
                    ),
                    const SizedBox(width: 8),
                  ]
                : [
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          borderRadius: 20,
                          child: Text(
                            '${widget.assetCount} items',
                            style: PrismTextStyles.bodySmall.copyWith(
                              color: PrismColors.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
          ),

          // Grid of assets
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childCount: _assets.length,
              itemBuilder: (context, index) {
                final asset = _assets[index];
                final isSelected = _selectedIndices.contains(index);
                return _AssetTile(
                  asset: asset,
                  index: index,
                  isSelected: isSelected,
                  selectionMode: _isSelectionMode,
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelection(index);
                    } else {
                      _openAsset(index);
                    }
                  },
                  onLongPress: () {
                    if (!_isSelectionMode) {
                      _startSelectionMode(index);
                    }
                  },
                );
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(
                    color: PrismColors.prismYellow,
                  ),
                ),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

/// Individual asset tile with thumbnail loading and selection state
class _AssetTile extends StatefulWidget {
  final AssetEntity asset;
  final int index;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _AssetTile({
    required this.asset,
    required this.index,
    required this.isSelected,
    required this.selectionMode,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<_AssetTile> createState() => _AssetTileState();
}

class _AssetTileState extends State<_AssetTile> {
  Uint8List? _thumbnail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final thumb = await widget.asset.thumbnailDataWithSize(
        const ThumbnailSize(300, 300),
        quality: 80,
      );
      if (mounted) {
        setState(() {
          _thumbnail = thumb;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child:
          AnimatedContainer(
            duration: 150.ms,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: widget.isSelected
                  ? Border.all(color: PrismColors.prismYellow, width: 3)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.isSelected ? 5 : 8),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  // Thumbnail or placeholder
                  if (_thumbnail != null)
                    Hero(
                      tag: 'local_${widget.asset.id}',
                      child: Image.memory(_thumbnail!, fit: BoxFit.cover),
                    )
                  else if (_isLoading)
                    Container(
                      height: 120,
                      color: PrismColors.surfaceGray,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PrismColors.secondaryText,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 120,
                      color: PrismColors.surfaceGray,
                      child: const Icon(
                        Icons.broken_image_rounded,
                        color: PrismColors.secondaryText,
                      ),
                    ),

                  // Selection checkmark
                  if (widget.selectionMode)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: AnimatedContainer(
                        duration: 150.ms,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isSelected
                              ? PrismColors.prismYellow
                              : PrismColors.black.withValues(alpha: 0.5),
                          border: Border.all(
                            color: widget.isSelected
                                ? PrismColors.prismYellow
                                : PrismColors.white.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: widget.isSelected
                              ? PrismColors.black
                              : Colors.transparent,
                        ),
                      ),
                    ),

                  // Video indicator
                  if (widget.asset.type == AssetType.video)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: PrismColors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              color: PrismColors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatDuration(widget.asset.duration),
                              style: PrismTextStyles.bodySmall.copyWith(
                                color: PrismColors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ).animate().fadeIn(
            duration: 200.ms,
            delay: (20 * (widget.index % 12)).ms,
          ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
