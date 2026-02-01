import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/widgets/shimmer_placeholder.dart';
import 'package:prism/utils/animations.dart';
import 'dart:io';

/// Animated image loader with smooth transitions and shimmer placeholder
/// Handles both network images and local files with consistent loading animations
class AnimatedImageLoader extends StatelessWidget {
  final String? imageUrl;
  final File? imageFile;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;
  final Duration fadeDuration;
  final bool showShimmer;

  const AnimatedImageLoader({
    super.key,
    this.imageUrl,
    this.imageFile,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
    this.fadeDuration = const Duration(milliseconds: 300),
    this.showShimmer = true,
  }) : assert(
         imageUrl != null || imageFile != null,
         'Either imageUrl or imageFile must be provided',
       );

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;

    // Handle local file
    if (imageFile != null) {
      return ClipRRect(
        borderRadius: radius,
        child: _LocalImageWithAnimation(
          file: imageFile!,
          width: width,
          height: height,
          fit: fit,
          fadeDuration: fadeDuration,
          showShimmer: showShimmer,
          errorWidget: errorWidget,
        ),
      );
    }

    // Handle network image
    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: fadeDuration,
        fadeOutDuration: AppAnimations.fast,
        placeholder: showShimmer
            ? (context, url) => SizedBox(
                width: width,
                height: height,
                child: ShimmerPlaceholder(
                  child: Container(color: Colors.grey[900]),
                ),
              )
            : null,
        errorWidget: (context, url, error) =>
            errorWidget ?? _DefaultErrorWidget(width: width, height: height),
      ),
    );
  }
}

/// Local image with fade-in animation
class _LocalImageWithAnimation extends StatefulWidget {
  final File file;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Duration fadeDuration;
  final bool showShimmer;
  final Widget? errorWidget;

  const _LocalImageWithAnimation({
    required this.file,
    this.width,
    this.height,
    required this.fit,
    required this.fadeDuration,
    required this.showShimmer,
    this.errorWidget,
  });

  @override
  State<_LocalImageWithAnimation> createState() =>
      _LocalImageWithAnimationState();
}

class _LocalImageWithAnimationState extends State<_LocalImageWithAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.fadeDuration,
    );
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      if (!await widget.file.exists()) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
        return;
      }

      // Add small delay to show shimmer briefly for UX consistency
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        setState(() => _isLoading = false);
        _controller.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget ??
          _DefaultErrorWidget(width: widget.width, height: widget.height);
    }

    if (_isLoading && widget.showShimmer) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: ShimmerPlaceholder(child: Container(color: Colors.grey[900])),
      );
    }

    return FadeTransition(
      opacity: _opacityAnimation,
      child: Image.file(
        widget.file,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          return widget.errorWidget ??
              _DefaultErrorWidget(width: widget.width, height: widget.height);
        },
      ),
    );
  }
}

/// Default error widget for failed image loads
class _DefaultErrorWidget extends StatelessWidget {
  final double? width;
  final double? height;

  const _DefaultErrorWidget({this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48),
      ),
    );
  }
}

/// Hero image transition wrapper for seamless image viewing
class HeroImageLoader extends StatelessWidget {
  final String heroTag;
  final String? imageUrl;
  final File? imageFile;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const HeroImageLoader({
    super.key,
    required this.heroTag,
    this.imageUrl,
    this.imageFile,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedImageLoader(
          imageUrl: imageUrl,
          imageFile: imageFile,
          width: width,
          height: height,
          fit: fit,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
