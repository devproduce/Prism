import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

/// Special card for "See All Albums" / "Show Less" toggle
class SeeAllAlbumsCard extends StatelessWidget {
  final bool isExpanded;
  final int remainingCount;
  final VoidCallback onTap;
  final double width;
  final double height;

  const SeeAllAlbumsCard({
    super.key,
    required this.isExpanded,
    required this.remainingCount,
    required this.onTap,
    this.width = 140,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child:
          Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      PrismColors.prismYellow.withValues(alpha: 0.15),
                      PrismColors.prismYellow.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: PrismColors.prismYellow.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PrismColors.prismYellow.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.grid_view_rounded,
                      color: PrismColors.prismYellow,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: 200.ms,
                      child: Text(
                        isExpanded ? 'Show Less' : 'See All Albums',
                        key: ValueKey(isExpanded),
                        style: PrismTextStyles.bodyMedium.copyWith(
                          color: PrismColors.prismYellow,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (!isExpanded && remainingCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '+ $remainingCount more',
                        style: PrismTextStyles.bodySmall.copyWith(
                          color: PrismColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1, 1),
                duration: 300.ms,
              ),
    );
  }
}
