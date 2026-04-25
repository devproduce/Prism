import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:prism/screens/share_upload_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/error_handler.dart';

import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

/// A simplified image viewer for local device images.
/// Uses a separate stateful widget for each page to ensure smooth animations.
class LocalImageViewerScreen extends StatefulWidget {
  final List<AssetEntity> assets;
  final int initialIndex;

  const LocalImageViewerScreen({
    super.key,
    required this.assets,
    this.initialIndex = 0,
  });

  @override
  State<LocalImageViewerScreen> createState() => _LocalImageViewerScreenState();
}

class _LocalImageViewerScreenState extends State<LocalImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  int _rotationQuarter = 0; // 0, 1, 2, 3 for 0°, 90°, 180°, 270°

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _rotationQuarter = 0;
    });
  }

  void _rotate() {
    final asset = widget.assets[_currentIndex];
    if (asset.type == AssetType.video) {
      ErrorHandler.showInfoSnackbar(context, message: 'Cannot rotate videos');
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _rotationQuarter = (_rotationQuarter + 1) % 4;
    });
  }

  Future<void> _shareViaPrism() async {
    HapticFeedback.mediumImpact();

    final asset = widget.assets[_currentIndex];
    final file = await asset.file;

    if (file == null) {
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: 'Could not access file',
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShareUploadScreen(sharedFilePaths: [file.path]),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.assets[_currentIndex];
    final isVideo = asset.type == AssetType.video;

    return Scaffold(
      backgroundColor: PrismColors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PrismColors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: PrismColors.white,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Share button (Prism share)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PrismColors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share_rounded, color: PrismColors.white),
            ),
            onPressed: _shareViaPrism,
          ),
          // Rotate button (only for images)
          if (!isVideo)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PrismColors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rotate_right_rounded,
                  color: PrismColors.white,
                ),
              ),
              onPressed: _rotate,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Image/Video viewer
          PageView.builder(
            physics: const BouncingScrollPhysics(),
            controller: _pageController,
            itemCount: widget.assets.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final isCurrentPage = index == _currentIndex;
              return LocalAssetPage(
                asset: widget.assets[index],
                // Only apply rotation to the current page
                rotationQuarter: isCurrentPage ? _rotationQuarter : 0,
              );
            },
          ),

          // Image counter at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: PrismColors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.assets.length}',
                    style: PrismTextStyles.bodyMedium.copyWith(
                      color: PrismColors.white,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
            ),
          ),
        ],
      ),
    );
  }
}

/// A stateful widget for each asset page to ensure smooth animations.
/// Uses AutomaticKeepAliveClientMixin to preserve state during swipes.
class LocalAssetPage extends StatefulWidget {
  final AssetEntity asset;
  final int rotationQuarter;

  const LocalAssetPage({
    super.key,
    required this.asset,
    required this.rotationQuarter,
  });

  @override
  State<LocalAssetPage> createState() => _LocalAssetPageState();
}

class _LocalAssetPageState extends State<LocalAssetPage>
    with AutomaticKeepAliveClientMixin {
  late Future<Uint8List?> _imageFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Use a high-quality thumbnail for photos
    _imageFuture = widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(2000, 2000),
      quality: 90,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final isVideo = widget.asset.type == AssetType.video;

    if (isVideo) {
      return _LocalVideoPlayer(asset: widget.asset);
    }

    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data != null) {
          final imageWidget = Hero(
            tag: 'local_${widget.asset.id}',
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          );

          // For photos, support zoom and rotation
          return Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: RotatedBox(
                quarterTurns: widget.rotationQuarter,
                child: imageWidget,
              ),
            ),
          );
        }

        // Loading state
        return const Center(
          child: CircularProgressIndicator(
            color: PrismColors.prismYellow,
            strokeWidth: 2,
          ),
        );
      },
    );
  }
}

class _LocalVideoPlayer extends StatefulWidget {
  final AssetEntity asset;

  const _LocalVideoPlayer({required this.asset});

  @override
  State<_LocalVideoPlayer> createState() => _LocalVideoPlayerState();
}

class _LocalVideoPlayerState extends State<_LocalVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final file = await widget.asset.file;
      if (file == null) {
        if (mounted) setState(() => _error = 'Could not load video file');
        return;
      }

      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: PrismColors.prismYellow,
          handleColor: PrismColors.prismYellow,
          backgroundColor: Colors.grey.withOpacity(0.5),
          bufferedColor: Colors.white.withOpacity(0.5),
        ),
        placeholder: const Center(
          child: CircularProgressIndicator(color: PrismColors.prismYellow),
        ),
        autoInitialize: true,
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) setState(() => _error = 'Failed to play video');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: PrismColors.errorRed,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: PrismTextStyles.bodyMedium.copyWith(
                color: PrismColors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: PrismColors.prismYellow),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
