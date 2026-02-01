import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prism/utils/responsive_helper.dart';
import 'package:prism/utils/animations.dart';

enum PrismButtonType { primary, secondary, destructive }

class PrismButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final PrismButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double? height;

  const PrismButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = PrismButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
  });

  @override
  State<PrismButton> createState() => _PrismButtonState();
}

class _PrismButtonState extends State<PrismButton>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case PrismButtonType.primary:
        return PrismColors.prismYellow;
      case PrismButtonType.secondary:
        return PrismColors.inputGray;
      case PrismButtonType.destructive:
        return PrismColors.destructiveRed;
    }
  }

  Color _getTextColor() {
    switch (widget.type) {
      case PrismButtonType.primary:
        return PrismColors.black;
      case PrismButtonType.secondary:
        return PrismColors.white;
      case PrismButtonType.destructive:
        return PrismColors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive button height
    final buttonHeight = widget.height ?? ResponsiveHelper.buttonHeight(context);
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null && !widget.isLoading) {
          setState(() => _isPressed = true);
          _controller.forward();
        }
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedOpacity(
          opacity: (widget.onPressed == null || widget.isLoading) ? 0.6 : 1.0,
          duration: AppAnimations.fast,
          child: SizedBox(
            width: widget.width,
            height: buttonHeight,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _getBackgroundColor(),
                foregroundColor: _getTextColor(),
                elevation: 0,
                shape: const StadiumBorder(),
                padding: EdgeInsets.symmetric(
                  horizontal: context.isSmallScreen ? 20 : 24,
                ),
                disabledBackgroundColor: _getBackgroundColor().withOpacity(0.5),
              ),
              child: AnimatedSwitcher(
                duration: AppAnimations.medium,
                child: widget.isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: _getTextColor(),
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              widget.text,
                              style: GoogleFonts.inter(
                                fontSize: context.isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w600,
                                color: _getTextColor(),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
