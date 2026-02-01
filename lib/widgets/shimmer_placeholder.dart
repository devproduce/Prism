import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';

/// A shimmer loading placeholder widget for skeleton screens.
/// Use this to show loading states that match the layout being loaded.
class ShimmerPlaceholder extends StatefulWidget {
  /// The child widget to apply shimmer effect to
  final Widget child;

  /// Base color for the shimmer (default: surfaceGray)
  final Color? baseColor;

  /// Highlight color for the shimmer (default: inputGray)
  final Color? highlightColor;

  /// Duration of one shimmer cycle
  final Duration duration;

  /// Whether the shimmer is enabled
  final bool enabled;

  const ShimmerPlaceholder({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
    this.enabled = true,
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(ShimmerPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final baseColor = widget.baseColor ?? PrismColors.surfaceGray;
    final highlightColor = widget.highlightColor ?? PrismColors.inputGray;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

/// A simple shimmer box for placeholder content
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: PrismColors.surfaceGray,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A shimmer circle for avatar placeholders
class ShimmerCircle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? margin;

  const ShimmerCircle({super.key, required this.size, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: const BoxDecoration(
        color: PrismColors.surfaceGray,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Pre-built shimmer layouts for common UI patterns
class ShimmerLayouts {
  /// Creates a shimmer placeholder for a list tile
  static Widget listTile({double? width}) {
    return ShimmerPlaceholder(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const ShimmerCircle(size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: width ?? 120, height: 16, borderRadius: 4),
                  const SizedBox(height: 8),
                  ShimmerBox(
                    width: (width ?? 120) * 1.5,
                    height: 12,
                    borderRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a shimmer placeholder for a grid item
  static Widget gridItem({double aspectRatio = 1.0}) {
    return ShimmerPlaceholder(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: PrismColors.surfaceGray,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Creates a shimmer placeholder for a card
  static Widget card({double height = 120}) {
    return ShimmerPlaceholder(
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: PrismColors.surfaceGray,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  /// Creates a shimmer placeholder for a gallery grid
  static Widget galleryGrid({int itemCount = 6, int crossAxisCount = 3}) {
    return ShimmerPlaceholder(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: PrismColors.surfaceGray,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  /// Creates a shimmer placeholder for a profile header
  static Widget profileHeader() {
    return ShimmerPlaceholder(
      child: Column(
        children: [
          const SizedBox(height: 24),
          const ShimmerCircle(size: 100),
          const SizedBox(height: 16),
          const ShimmerBox(width: 160, height: 24, borderRadius: 4),
          const SizedBox(height: 8),
          const ShimmerBox(width: 120, height: 16, borderRadius: 4),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (index) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ShimmerBox(width: 40, height: 20, borderRadius: 4),
                    SizedBox(height: 4),
                    ShimmerBox(width: 60, height: 14, borderRadius: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Creates a shimmer placeholder for a notification item
  static Widget notificationItem() {
    return ShimmerPlaceholder(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const ShimmerCircle(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerBox(
                    width: double.infinity,
                    height: 14,
                    borderRadius: 4,
                  ),
                  const SizedBox(height: 6),
                  ShimmerBox(
                    width:
                        MediaQueryData.fromView(
                          WidgetsBinding
                              .instance
                              .platformDispatcher
                              .views
                              .first,
                        ).size.width *
                        0.5,
                    height: 12,
                    borderRadius: 4,
                  ),
                ],
              ),
            ),
            const ShimmerBox(width: 50, height: 12, borderRadius: 4),
          ],
        ),
      ),
    );
  }

  /// Creates multiple shimmer list items
  static Widget listItems({int count = 5}) {
    return Column(children: List.generate(count, (index) => listTile()));
  }
}
