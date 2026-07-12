import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:prism/widgets/empty_state_widget.dart';
import 'package:prism/widgets/shimmer_placeholder.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBlockedUsers();
    });
  }

  Future<void> _loadBlockedUsers() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendsProvider = Provider.of<FriendsProvider>(
      context,
      listen: false,
    );

    if (authProvider.currentUser != null) {
      await friendsProvider.fetchBlockedUsers(authProvider.currentUser!.userId);
    }
  }

  Future<void> _showBlockUserDialog() async {
    final controller = TextEditingController();

    try {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
          backgroundColor: PrismColors.surfaceGray,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: PrismColors.white.withValues(alpha: 0.1)),
          ),
          title: Text('Block User', style: PrismTextStyles.h3),
          content: TextField(
            controller: controller,
            style: PrismTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Enter username',
              hintStyle: PrismTextStyles.bodyMedium.copyWith(
                color: PrismColors.secondaryText,
              ),
              filled: true,
              fillColor: PrismColors.black.withValues(alpha: 0.26),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: PrismTextStyles.button.copyWith(
                  color: PrismColors.secondaryText,
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  _blockUser(controller.text.trim());
                  Navigator.pop(context);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: PrismColors.destructiveRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Block', style: PrismTextStyles.button),
            ),
          ],
        );
      },
    );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _blockUser(String username) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendsProvider = Provider.of<FriendsProvider>(
      context,
      listen: false,
    );

    if (authProvider.currentUser == null) return;

    if (mounted) {
      ErrorHandler.showInfoSnackbar(context, message: 'Blocking user...');
    }

    final success = await friendsProvider.blockUser(
      username,
      authProvider.currentUser!.userId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (success) {
        ErrorHandler.showSuccessSnackbar(context, message: 'Blocked $username');
      } else {
        ErrorHandler.showErrorSnackbar(
          context,
          message: friendsProvider.error ?? 'Failed to block user',
        );
      }
    }
  }

  Future<void> _unblockUser(String userId, String username) async {
    HapticFeedback.selectionClick();

    final confirmed = await ErrorHandler.showConfirmationDialog(
      context,
      title: 'Unblock User',
      message: 'Are you sure you want to unblock $username?',
      confirmText: 'Unblock',
    );

    if (confirmed == true) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final friendsProvider = Provider.of<FriendsProvider>(
        context,
        listen: false,
      );

      if (authProvider.currentUser == null) return;

      if (mounted) {
        ErrorHandler.showInfoSnackbar(context, message: 'Unblocking user...');
      }

      final success = await friendsProvider.unblockUser(
        userId,
        authProvider.currentUser!.userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (success) {
          ErrorHandler.showSuccessSnackbar(
            context,
            message: 'Unblocked $username',
          );
        } else {
          ErrorHandler.showErrorSnackbar(
            context,
            message: friendsProvider.error ?? 'Failed to unblock user',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsProvider = Provider.of<FriendsProvider>(context);
    final blockedUsers = friendsProvider.blockedUsers;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text('Blocked Users', style: PrismTextStyles.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: BackButton(
          color: PrismColors.white,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _showBlockUserDialog();
            },
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: PrismColors.destructiveRed,
              size: 28,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Blocked users cannot see your profile or send you messages.',
                style: PrismTextStyles.bodyMedium.copyWith(
                  color: PrismColors.secondaryText,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: friendsProvider.isLoading
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ShimmerLayouts.listItems(count: 5),
                    )
                  : blockedUsers.isEmpty
                  ? EmptyStateWidget.noBlockedUsers()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: blockedUsers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final user = blockedUsers[index];
                        return PrismCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: PrismColors.destructiveRed
                                    .withValues(alpha: 0.2),
                                backgroundImage:
                                    user.profilePictureUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(
                                        user.profilePictureUrl,
                                      )
                                    : null,
                                child: user.profilePictureUrl.isEmpty
                                    ? const Icon(
                                        Icons.block,
                                        color: PrismColors.destructiveRed,
                                        size: 20,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  user.displayName,
                                  style: PrismTextStyles.bodyLarge,
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _unblockUser(user.userId, user.displayName),
                                child: Text(
                                  'Unblock',
                                  style: PrismTextStyles.button.copyWith(
                                    color: PrismColors.prismYellow,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
