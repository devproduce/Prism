import 'package:flutter/material.dart';
import 'package:prism/models/review_models.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/constants.dart';
import 'package:prism/widgets/friendship_action_pill.dart';
import 'package:prism/widgets/review/review_section_header.dart';

/// Horizontal strip of batch contacts who are not yet friends.
///
/// [suggestions] should already exclude existing friends (filter upstream).
class ReviewSuggestionsStrip extends StatelessWidget {
  final List<ReviewSuggestion> suggestions;
  final ScrollController scrollController;
  final VoidCallback onViewAll;
  final void Function(ReviewSuggestion suggestion) onAddTap;
  final FriendshipDisplayStatus Function(String userId, String username)
      statusFor;

  const ReviewSuggestionsStrip({
    super.key,
    required this.suggestions,
    required this.scrollController,
    required this.onViewAll,
    required this.onAddTap,
    required this.statusFor,
  });

  static const double _cardWidth = 112;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ReviewSectionHeader(
          title: 'SUGGESTIONS',
          actionLabel: 'VIEW ALL',
          onAction: onViewAll,
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              final status = statusFor(suggestion.userId, suggestion.username);

              return _SuggestionCard(
                suggestion: suggestion,
                status: status,
                onAddTap: status == FriendshipDisplayStatus.none
                    ? () => onAddTap(suggestion)
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final ReviewSuggestion suggestion;
  final FriendshipDisplayStatus status;
  final VoidCallback? onAddTap;

  const _SuggestionCard({
    required this.suggestion,
    required this.status,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final profilePicUrl = suggestion.profilePicId != null
        ? '${ApiConstants.baseUrl}/images/${suggestion.profilePicId}'
        : null;

    return Container(
      width: ReviewSuggestionsStrip._cardWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: PrismColors.surfaceGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PrismColors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: PrismColors.inputGray,
            backgroundImage:
                profilePicUrl != null ? NetworkImage(profilePicUrl) : null,
            child: profilePicUrl == null
                ? Text(
                    suggestion.displayName.isNotEmpty
                        ? suggestion.displayName[0].toUpperCase()
                        : '?',
                    style: PrismTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            suggestion.displayName,
            style: PrismTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          FriendshipActionPill(
            status: status,
            onAddTap: onAddTap,
            style: FriendshipActionStyle.pill,
          ),
        ],
      ),
    );
  }
}
