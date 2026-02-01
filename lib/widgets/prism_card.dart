import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/utils/responsive_helper.dart';
import 'package:prism/utils/animations.dart';

class PrismCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool enableAnimation;

  const PrismCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.enableAnimation = true,
  });

  @override
  State<PrismCard> createState() => _PrismCardState();
}

class _PrismCardState extends State<PrismCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = context.isSmallScreen ? 16.0 : 20.0;
    final padding = widget.padding ?? 
        EdgeInsets.all(context.isSmallScreen ? 12.0 : 16.0);

    Widget content = Container(
      margin: widget.margin,
      padding: padding,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? PrismColors.surfaceGray,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: widget.child,
    );

    if (widget.onTap != null && widget.enableAnimation) {
      return GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          _controller.forward();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _controller.reverse();
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
          _controller.reverse();
        },
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: content,
        ),
      );
    } else if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: content,
      );
    }

    return content;
  }
}
