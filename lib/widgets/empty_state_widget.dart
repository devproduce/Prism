import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_button.dart';

/// A professional empty state widget for displaying when lists/grids are empty.
/// Provides consistent styling and optional action buttons across the app.
class EmptyStateWidget extends StatelessWidget {
  /// The icon to display
  final IconData icon;

  /// Main title text
  final String title;

  /// Descriptive message
  final String message;

  /// Optional action button text
  final String? actionText;

  /// Optional action callback
  final VoidCallback? onAction;

  /// Optional secondary action text
  final String? secondaryActionText;

  /// Optional secondary action callback
  final VoidCallback? onSecondaryAction;

  /// Icon color (defaults to secondaryText)
  final Color? iconColor;

  /// Icon size (defaults to 64)
  final double iconSize;

  /// Whether to use compact layout
  final bool compact;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.secondaryActionText,
    this.onSecondaryAction,
    this.iconColor,
    this.iconSize = 64,
    this.compact = false,
  });

  /// Creates an empty state for no images/media
  factory EmptyStateWidget.noMedia({VoidCallback? onAddMedia}) {
    return EmptyStateWidget(
      icon: Icons.photo_library_outlined,
      title: 'No Media Yet',
      message: 'Your photos and videos will appear here once you add them.',
      actionText: onAddMedia != null ? 'Add Media' : null,
      onAction: onAddMedia,
    );
  }

  /// Creates an empty state for no friends
  factory EmptyStateWidget.noFriends({VoidCallback? onFindFriends}) {
    return EmptyStateWidget(
      icon: Icons.people_outline_rounded,
      title: 'No Friends Yet',
      message: 'Start connecting with people to share memories together.',
      actionText: onFindFriends != null ? 'Find Friends' : null,
      onAction: onFindFriends,
    );
  }

  /// Creates an empty state for no notifications
  factory EmptyStateWidget.noNotifications() {
    return const EmptyStateWidget(
      icon: Icons.notifications_off_outlined,
      title: 'No Notifications',
      message: 'When you have new activity, you\'ll see it here.',
    );
  }

  /// Creates an empty state for no collections
  factory EmptyStateWidget.noCollections({VoidCallback? onCreateCollection}) {
    return EmptyStateWidget(
      icon: Icons.folder_outlined,
      title: 'No Collections',
      message: 'Organize your media into collections for easy access.',
      actionText: onCreateCollection != null ? 'Create Collection' : null,
      onAction: onCreateCollection,
    );
  }

  /// Creates an empty state for no search results
  factory EmptyStateWidget.noSearchResults({
    String? searchQuery,
    VoidCallback? onClearSearch,
  }) {
    return EmptyStateWidget(
      icon: Icons.search_off_rounded,
      title: 'No Results Found',
      message: searchQuery != null
          ? 'No results found for "$searchQuery". Try a different search term.'
          : 'No results match your search. Try adjusting your query.',
      actionText: onClearSearch != null ? 'Clear Search' : null,
      onAction: onClearSearch,
    );
  }

  /// Creates an empty state for blocked users
  factory EmptyStateWidget.noBlockedUsers() {
    return const EmptyStateWidget(
      icon: Icons.block_rounded,
      title: 'No Blocked Users',
      message: 'Users you block will appear here.',
    );
  }

  /// Creates an empty state for favorites
  factory EmptyStateWidget.noFavorites() {
    return const EmptyStateWidget(
      icon: Icons.favorite_border_rounded,
      title: 'No Favorites Yet',
      message: 'Tap the heart icon on any photo to add it to your favorites.',
    );
  }

  /// Creates an empty state for shared media
  factory EmptyStateWidget.noSharedMedia({VoidCallback? onShare}) {
    return EmptyStateWidget(
      icon: Icons.share_outlined,
      title: 'Nothing Shared Yet',
      message: 'Media shared between you and this friend will appear here.',
      actionText: onShare != null ? 'Share Something' : null,
      onAction: onShare,
    );
  }

  /// Creates an error state
  factory EmptyStateWidget.error({String? message, VoidCallback? onRetry}) {
    return EmptyStateWidget(
      icon: Icons.error_outline_rounded,
      title: 'Something Went Wrong',
      message: message ?? 'An error occurred. Please try again.',
      actionText: onRetry != null ? 'Try Again' : null,
      onAction: onRetry,
      iconColor: PrismColors.destructiveRed,
    );
  }

  /// Creates an offline state
  factory EmptyStateWidget.offline({VoidCallback? onRetry}) {
    return EmptyStateWidget(
      icon: Icons.wifi_off_rounded,
      title: 'No Connection',
      message: 'Check your internet connection and try again.',
      actionText: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
      iconColor: PrismColors.secondaryText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final verticalSpacing = compact ? 12.0 : 16.0;
    final horizontalPadding = compact ? 16.0 : 32.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container
            Container(
              padding: EdgeInsets.all(compact ? 12 : 16),
              decoration: BoxDecoration(
                color: (iconColor ?? PrismColors.secondaryText).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(compact ? 16 : 24),
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? PrismColors.secondaryText,
              ),
            ),

            SizedBox(height: verticalSpacing * 1.5),

            // Title
            Text(
              title,
              style: compact
                  ? PrismTextStyles.h3.copyWith(color: PrismColors.white)
                  : PrismTextStyles.h2.copyWith(color: PrismColors.white),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: verticalSpacing * 0.5),

            // Message
            Text(
              message,
              style: PrismTextStyles.bodyMedium.copyWith(
                color: PrismColors.secondaryText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            // Primary action button
            if (actionText != null && onAction != null) ...[
              SizedBox(height: verticalSpacing * 1.5),
              compact
                  ? TextButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(actionText!),
                      style: TextButton.styleFrom(
                        foregroundColor: PrismColors.prismYellow,
                      ),
                    )
                  : PrismButton(
                      text: actionText!,
                      onPressed: onAction!,
                      type: PrismButtonType.primary,
                    ),
            ],

            // Secondary action button
            if (secondaryActionText != null && onSecondaryAction != null) ...[
              SizedBox(height: verticalSpacing * 0.5),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(
                  secondaryActionText!,
                  style: PrismTextStyles.bodyMedium.copyWith(
                    color: PrismColors.secondaryText,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
