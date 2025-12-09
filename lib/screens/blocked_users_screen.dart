import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/widgets/gradient_background.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';

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

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PrismColors.darkCard,
          title: Text('Block User', style: PrismTextStyles.h3),
          content: TextField(
            controller: controller,
            style: PrismTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Enter username',
              hintStyle: PrismTextStyles.bodyMedium.copyWith(
                color: Colors.white54,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white60),
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
                backgroundColor: PrismColors.errorRed,
              ),
              child: const Text('Block'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _blockUser(String username) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendsProvider = Provider.of<FriendsProvider>(
      context,
      listen: false,
    );

    if (authProvider.currentUser == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blocking user...'),
          backgroundColor: PrismColors.primaryBlue,
        ),
      );
    }

    final success = await friendsProvider.blockUser(
      username,
      authProvider.currentUser!.userId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Blocked $username'),
            backgroundColor: PrismColors.successGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendsProvider.error ?? 'Failed to block user'),
            backgroundColor: PrismColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _unblockUser(String userId, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PrismColors.darkCard,
        title: Text('Unblock User', style: PrismTextStyles.h3),
        content: Text(
          'Are you sure you want to unblock $username?',
          style: PrismTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: PrismColors.primaryBlue,
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final friendsProvider = Provider.of<FriendsProvider>(
        context,
        listen: false,
      );

      if (authProvider.currentUser == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unblocking user...'),
            backgroundColor: PrismColors.primaryBlue,
          ),
        );
      }

      final success = await friendsProvider.unblockUser(
        userId,
        authProvider.currentUser!.userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unblocked $username'),
              backgroundColor: PrismColors.successGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(friendsProvider.error ?? 'Failed to unblock user'),
              backgroundColor: PrismColors.errorRed,
            ),
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
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Text('Blocked Users', style: PrismTextStyles.h2),
                      ],
                    ),
                    IconButton(
                      onPressed: _showBlockUserDialog,
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: PrismColors.errorRed,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Blocked users cannot see your profile or send you messages.',
                  style: PrismTextStyles.bodyMedium.copyWith(
                    color: Colors.white60,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: friendsProvider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: PrismColors.primaryBlue,
                        ),
                      )
                    : blockedUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.block_flipped,
                              size: 64,
                              color: Colors.white24,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No blocked users',
                              style: PrismTextStyles.h3.copyWith(
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: blockedUsers.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final user = blockedUsers[index];
                          return GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: PrismColors.errorRed
                                      .withOpacity(0.2),
                                  backgroundImage:
                                      user.profilePictureUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          user.profilePictureUrl,
                                        )
                                      : null,
                                  child: user.profilePictureUrl.isEmpty
                                      ? const Icon(
                                          Icons.block,
                                          color: PrismColors.errorRed,
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
                                  onPressed: () => _unblockUser(
                                    user.userId,
                                    user.displayName,
                                  ),
                                  child: Text(
                                    'Unblock',
                                    style: PrismTextStyles.button.copyWith(
                                      color: PrismColors.primaryBlue,
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
      ),
    );
  }
}
