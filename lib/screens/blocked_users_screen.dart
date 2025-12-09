import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/utils/theme.dart';
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
          title: const Text('Block User'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter username',
              filled: true,
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  _blockUser(controller.text.trim());
                  Navigator.pop(context);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
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

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Blocking $username...'),
            ],
          ),
          duration: const Duration(seconds: 30),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // Call backend - assuming username is actually the friend_id
    final success = await friendsProvider.blockUser(
      username,
      authProvider.currentUser!.userId,
    );

    // Remove loading snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Blocked $username'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendsProvider.error ?? 'Failed to block user'),
            duration: const Duration(seconds: 2),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _unblockUser(String userId, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User'),
        content: Text('Are you sure you want to unblock $username?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text('Unblocking $username...'),
              ],
            ),
            duration: const Duration(seconds: 30),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      final success = await friendsProvider.unblockUser(
        userId,
        authProvider.currentUser!.userId,
      );

      // Remove loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unblocked $username'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(friendsProvider.error ?? 'Failed to unblock user'),
              duration: const Duration(seconds: 2),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final friendsProvider = Provider.of<FriendsProvider>(context);
    final blockedUsers = friendsProvider.blockedUsers;

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground(context),
      appBar: AppBar(
        title: const Text('Blocked Users'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.icon(
              onPressed: _showBlockUserDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Block User'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Blocked users cannot see your profile or send you messages.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: friendsProvider.isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
                  )
                : blockedUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.block_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No blocked users',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: blockedUsers.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final user = blockedUsers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.errorContainer,
                          backgroundImage: user.profilePictureUrl.isNotEmpty
                              ? CachedNetworkImageProvider(
                                  user.profilePictureUrl,
                                )
                              : null,
                          child: user.profilePictureUrl.isEmpty
                              ? Icon(
                                  Icons.block,
                                  color: theme.colorScheme.error,
                                )
                              : null,
                        ),
                        title: Text(
                          user.displayName,
                          style: theme.textTheme.titleMedium,
                        ),
                        trailing: OutlinedButton(
                          onPressed: () =>
                              _unblockUser(user.userId, user.displayName),
                          child: const Text('Unblock'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
