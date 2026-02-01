import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/utils/video_thumbnail_helper.dart';

class PrismMediaPreview extends StatefulWidget {
  final String imageUrl;
  final String mediaType;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Color? placeholderColor;
  final Map<String, String>? httpHeaders; // Added headers

  const PrismMediaPreview({
    super.key,
    required this.imageUrl,
    required this.mediaType,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholderColor,
    this.httpHeaders,
  });

  @override
  State<PrismMediaPreview> createState() => _PrismMediaPreviewState();
}

class _PrismMediaPreviewState extends State<PrismMediaPreview> {
  String? _localThumbnailPath;
  bool _isLoadingThumbnail = false;

  bool get _isVideo {
    if (widget.mediaType.startsWith('video')) return true;
    final uri = Uri.tryParse(widget.imageUrl);
    if (uri == null) return false;
    final ext = uri.path.split('.').last.toLowerCase();
    return [
      'mp4',
      'mov',
      'avi',
      'mkv',
      'webm',
      '3gp',
      'flv',
      'f4v',
      'mpg',
      'mpeg',
      'm4v',
    ].contains(ext);
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    if (!mounted) return;
    setState(() => _isLoadingThumbnail = true);

    try {
      final thumbnailPath = await VideoThumbnailHelper.getThumbnail(
        widget.imageUrl,
        headers: widget.httpHeaders, // Pass headers
      );
      if (mounted) {
        setState(() {
          _localThumbnailPath = thumbnailPath;
          _isLoadingThumbnail = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading thumbnail: $e');
      if (mounted) {
        setState(() => _isLoadingThumbnail = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo) {
      return _buildVideoThumbnail();
    } else {
      return _buildImagePreview();
    }
  }

  Widget _buildVideoThumbnail() {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (_localThumbnailPath != null)
          Image.file(
            File(_localThumbnailPath!),
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          )
        else
          _buildPlaceholder(isLoading: _isLoadingThumbnail),

        // Play Icon Overlay
        Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      httpHeaders: widget.httpHeaders, // Pass headers
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      // Memory optimization - helps avoid platform decoder issues
      // Only set cache dimensions if width/height are finite (not infinity or NaN)
      memCacheWidth: (widget.width != null && widget.width!.isFinite)
          ? widget.width!.toInt()
          : null,
      memCacheHeight: (widget.height != null && widget.height!.isFinite)
          ? widget.height!.toInt()
          : null,
      maxWidthDiskCache: 1000,
      maxHeightDiskCache: 1000,
      // Error listener to catch decoding errors
      errorListener: (error) {
        debugPrint('CachedNetworkImage error listener: $error');
        if (error.toString().contains('ImageDecoder')) {
          debugPrint(
            'ImageDecoder error detected - likely unsupported format (AVIF on Android <12, corrupted data, etc.)',
          );
        }
      },
      placeholder: (context, url) => _buildPlaceholder(isLoading: true),
      errorWidget: (context, url, error) {
        debugPrint('Error loading image: $url');
        debugPrint('Error details: $error');
        return Container(
          width: widget.width,
          height: widget.height,
          color: widget.placeholderColor ?? PrismColors.surfaceGray,
          child: const Center(
            child: Icon(
              Icons.broken_image_rounded,
              color: PrismColors.destructiveRed,
              size: 24,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder({bool isLoading = false}) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.placeholderColor ?? PrismColors.surfaceGray,
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PrismColors.prismYellow,
                ),
              )
            : const Icon(Icons.movie_creation_outlined, color: Colors.white24),
      ),
    );
  }
}
