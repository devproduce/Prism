import 'package:flutter/material.dart';
import 'package:prism/models/review_models.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/constants.dart';
import 'package:prism/widgets/friendship_action_pill.dart';

/// Vertical "Found Contacts" block — matches web Review & Share (page.tsx Group B).
class ReviewFoundContactsSection extends StatelessWidget {
  final List<ReviewSuggestion> contacts;
  final FriendshipDisplayStatus Function(String userId, String username)
      statusFor;
  final void Function(ReviewSuggestion contact) onAddTap;

  const ReviewFoundContactsSection({
    super.key,
    required this.contacts,
    required this.statusFor,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Found Contacts (${contacts.length})',
            style: PrismTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: PrismColors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...contacts.map((contact) {
            final status = statusFor(contact.userId, contact.username);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FoundContactRow(
                contact: contact,
                status: status,
                onAddTap: status == FriendshipDisplayStatus.none
                    ? () => onAddTap(contact)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FoundContactRow extends StatelessWidget {
  final ReviewSuggestion contact;
  final FriendshipDisplayStatus status;
  final VoidCallback? onAddTap;

  const _FoundContactRow({
    required this.contact,
    required this.status,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final profilePicUrl = contact.profilePicId != null
        ? '${ApiConstants.baseUrl}/images/${contact.profilePicId}'
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PrismColors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PrismColors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: PrismColors.inputGray,
            backgroundImage:
                profilePicUrl != null ? NetworkImage(profilePicUrl) : null,
            child: profilePicUrl == null
                ? Text(
                    contact.displayName.isNotEmpty
                        ? contact.displayName[0].toUpperCase()
                        : '?',
                    style: PrismTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.displayName,
                  style: PrismTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'On Prism',
                  style: PrismTextStyles.bodySmall.copyWith(
                    color: PrismColors.secondaryText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          FriendshipActionPill(
            status: status,
            onAddTap: onAddTap,
            style: FriendshipActionStyle.compact,
          ),
        ],
      ),
    );
  }
}
