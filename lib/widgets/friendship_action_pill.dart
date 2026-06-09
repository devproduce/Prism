import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

enum FriendshipActionStyle { compact, pill }

/// Shared Add / Sent / Friend affordance for Friends and Review screens.
class FriendshipActionPill extends StatelessWidget {
  final FriendshipDisplayStatus status;
  final VoidCallback? onAddTap;
  final FriendshipActionStyle style;

  const FriendshipActionPill({
    super.key,
    required this.status,
    this.onAddTap,
    this.style = FriendshipActionStyle.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (style == FriendshipActionStyle.pill) {
      return _PillVariant(status: status, onAddTap: onAddTap);
    }
    return _CompactVariant(status: status, onAddTap: onAddTap);
  }
}

class _CompactVariant extends StatelessWidget {
  final FriendshipDisplayStatus status;
  final VoidCallback? onAddTap;

  const _CompactVariant({required this.status, this.onAddTap});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case FriendshipDisplayStatus.friend:
        return SizedBox(
          width: 44,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_rounded,
                color: PrismColors.successGreen,
                size: 22,
              ),
              Text(
                'Friend',
                style: PrismTextStyles.bodySmall.copyWith(
                  color: PrismColors.successGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      case FriendshipDisplayStatus.pendingSent:
        return SizedBox(
          width: 44,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: PrismColors.electricCyan,
                size: 22,
              ),
              Text(
                'Sent',
                style: PrismTextStyles.bodySmall.copyWith(
                  color: PrismColors.electricCyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      case FriendshipDisplayStatus.none:
        return SizedBox(
          width: 44,
          child: InkWell(
            onTap: onAddTap,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person_add_rounded,
                  color: PrismColors.prismYellow,
                  size: 22,
                ),
                Text(
                  'Add',
                  style: PrismTextStyles.bodySmall.copyWith(
                    color: PrismColors.prismYellow,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}

class _PillVariant extends StatelessWidget {
  final FriendshipDisplayStatus status;
  final VoidCallback? onAddTap;

  const _PillVariant({required this.status, this.onAddTap});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case FriendshipDisplayStatus.friend:
        return _StatusPill(
          label: 'Friend',
          backgroundColor: PrismColors.successGreen.withValues(alpha: 0.15),
          foregroundColor: PrismColors.successGreen,
        );
      case FriendshipDisplayStatus.pendingSent:
        return _StatusPill(
          label: 'Sent',
          backgroundColor: PrismColors.electricCyan.withValues(alpha: 0.15),
          foregroundColor: PrismColors.electricCyan,
        );
      case FriendshipDisplayStatus.none:
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onAddTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onAddTap!();
                  },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: PrismColors.prismYellow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Add',
                style: PrismTextStyles.bodySmall.copyWith(
                  color: PrismColors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _StatusPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: PrismTextStyles.bodySmall.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
