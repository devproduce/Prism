import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prism/utils/responsive_helper.dart';
import 'package:prism/utils/animations.dart';

class PrismTextField extends StatefulWidget {
  final String hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final bool readOnly;
  final bool enabled;

  const PrismTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.readOnly = false,
    this.enabled = true,
  });

  @override
  State<PrismTextField> createState() => _PrismTextFieldState();
}

class _PrismTextFieldState extends State<PrismTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void didUpdateWidget(PrismTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != null && oldWidget.errorText != widget.errorText) {
      _shakeController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = context.isSmallScreen ? 10.0 : 12.0;
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: AppAnimations.fast,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: PrismColors.prismYellow.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.obscureText,
              onChanged: widget.onChanged,
              onFieldSubmitted: widget.onSubmitted,
              keyboardType: widget.keyboardType,
              maxLines: widget.maxLines,
              readOnly: widget.readOnly,
              enabled: widget.enabled,
              validator: widget.validator,
              focusNode: _focusNode,
              style: GoogleFonts.inter(
                color: widget.enabled ? PrismColors.white : PrismColors.secondaryText,
                fontSize: context.isSmallScreen ? 14 : 16,
              ),
              cursorColor: PrismColors.prismYellow,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: GoogleFonts.inter(
                  color: PrismColors.secondaryText,
                  fontSize: context.isSmallScreen ? 12 : 14,
                ),
                filled: true,
                fillColor: PrismColors.inputGray,
                prefixIcon: widget.prefixIcon != null
                    ? Icon(widget.prefixIcon, color: PrismColors.secondaryText, size: 20)
                    : null,
                suffixIcon: widget.suffixIcon,
                contentPadding: EdgeInsets.symmetric(
                  vertical: context.isSmallScreen ? 12 : 16,
                  horizontal: context.isSmallScreen ? 16 : 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                  borderSide: const BorderSide(
                    color: PrismColors.prismYellow,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                  borderSide: const BorderSide(
                    color: PrismColors.destructiveRed,
                    width: 1,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                  borderSide: const BorderSide(
                    color: PrismColors.destructiveRed,
                    width: 1.5,
                  ),
                ),
                errorText: widget.errorText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
