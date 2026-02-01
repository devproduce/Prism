import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';

/// 3x3 Grid overlay for multi-view face capture
/// Shows which angles have been captured and provides visual guidance
class FaceScanGrid extends StatelessWidget {
  final List<int> capturedIndices;
  final int? currentGridIndex;
  final String message;

  const FaceScanGrid({
    super.key,
    required this.capturedIndices,
    this.currentGridIndex,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Message at top
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: PrismColors.surfaceGray.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: PrismColors.prismYellow.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: PrismColors.prismYellow,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),

          // 3x3 Grid
          AspectRatio(
            aspectRatio: 1,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                final isCaptured = capturedIndices.contains(index);
                final isCurrent = currentGridIndex == index;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isCaptured
                        ? PrismColors.successGreen.withOpacity(0.3)
                        : Colors.transparent,
                    border: Border.all(
                      color: isCurrent
                          ? PrismColors.prismYellow
                          : isCaptured
                          ? PrismColors.successGreen.withOpacity(0.5)
                          : Colors.white.withOpacity(0.2),
                      width: isCurrent ? 3 : 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isCaptured
                        ? Icon(
                            Icons.check_circle,
                            color: PrismColors.successGreen,
                            size: 24,
                          )
                        : isCurrent
                        ? Icon(
                            Icons.camera_alt,
                            color: PrismColors.prismYellow,
                            size: 24,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Progress indicator
          Text(
            '${capturedIndices.length}/9 angles captured',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
