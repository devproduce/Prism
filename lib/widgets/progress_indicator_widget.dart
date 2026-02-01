import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/utils/animations.dart';

/// Custom progress indicator with smooth animations
class PrismProgressIndicator extends StatefulWidget {
  final double value; // 0.0 to 1.0
  final Color? color;
  final Color? backgroundColor;
  final double height;
  final BorderRadius? borderRadius;
  final bool showPercentage;
  final TextStyle? percentageStyle;

  const PrismProgressIndicator({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 8,
    this.borderRadius,
    this.showPercentage = false,
    this.percentageStyle,
  });

  @override
  State<PrismProgressIndicator> createState() => _PrismProgressIndicatorState();
}

class _PrismProgressIndicatorState extends State<PrismProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.medium,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(PrismProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
          child: SizedBox(
            height: widget.height,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _animation.value,
                  backgroundColor: widget.backgroundColor ?? Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.color ?? PrismColors.prismYellow,
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.showPercentage)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Text(
                  '${(_animation.value * 100).toInt()}%',
                  style:
                      widget.percentageStyle ??
                      const TextStyle(fontSize: 12, color: Colors.white70),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Circular progress indicator with percentage
class CircularProgressWithPercentage extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final double strokeWidth;
  final bool showPercentage;
  final TextStyle? percentageStyle;

  const CircularProgressWithPercentage({
    super.key,
    required this.value,
    this.size = 60,
    this.color,
    this.backgroundColor,
    this.strokeWidth = 4,
    this.showPercentage = true,
    this.percentageStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: strokeWidth,
              backgroundColor: backgroundColor ?? Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? PrismColors.prismYellow,
              ),
            ),
          ),
          if (showPercentage)
            Text(
              '${(value * 100).toInt()}%',
              style:
                  percentageStyle ??
                  TextStyle(
                    fontSize: size * 0.25,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
        ],
      ),
    );
  }
}

/// Step progress indicator for multi-step processes
class StepProgressIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final Color? activeColor;
  final Color? inactiveColor;
  final double stepSize;
  final double spacing;

  const StepProgressIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.activeColor,
    this.inactiveColor,
    this.stepSize = 40,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index < currentStep;
        final isCurrent = index == currentStep;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: AnimatedContainer(
            duration: AppAnimations.medium,
            curve: Curves.easeInOut,
            width: isCurrent ? stepSize * 1.2 : stepSize,
            height: isCurrent ? stepSize * 1.2 : stepSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive || isCurrent
                  ? (activeColor ?? PrismColors.prismYellow)
                  : (inactiveColor ?? Colors.grey[800]),
              border: isCurrent
                  ? Border.all(
                      color: activeColor ?? PrismColors.prismYellow,
                      width: 2,
                    )
                  : null,
            ),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: AppAnimations.fast,
                style: TextStyle(
                  color: isActive || isCurrent ? Colors.black : Colors.white54,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  fontSize: isCurrent ? 16 : 14,
                ),
                child: Text('${index + 1}'),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Loading spinner with custom styling
class PrismLoadingSpinner extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const PrismLoadingSpinner({
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? PrismColors.prismYellow,
        ),
      ),
    );
  }
}

/// Pulsing dot indicator for loading states
class PulsingDots extends StatefulWidget {
  final int dotCount;
  final double dotSize;
  final Color? color;
  final Duration duration;

  const PulsingDots({
    super.key,
    this.dotCount = 3,
    this.dotSize = 8,
    this.color,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<PulsingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.dotCount, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * (1 / widget.dotCount);
            final value = (_controller.value - delay) % 1.0;
            final scale = 0.5 + (0.5 * (1 - (value - 0.5).abs() * 2));

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color ?? PrismColors.prismYellow,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
