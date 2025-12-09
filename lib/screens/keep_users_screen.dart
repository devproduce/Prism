import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/utils/theme.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/screens/friends_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/widgets/gradient_scaffold.dart';

class KeepUsersScreen extends StatefulWidget {
  const KeepUsersScreen({super.key});

  @override
  State<KeepUsersScreen> createState() => _KeepUsersScreenState();
}

class _KeepUsersScreenState extends State<KeepUsersScreen> {
  final Set<String> _keepUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendsProvider = Provider.of<FriendsProvider>(
      context,
      listen: false,
    );

    if (authProvider.currentUser != null) {
      await friendsProvider.fetchFriends(authProvider.currentUser!.userId);

      // Load keep status from friends
      if (mounted) {
        setState(() {
          _keepUserIds.clear();
          for (var friend in friendsProvider.friends) {
            // If keep is not null, add to keep list
            if (friend.keep != null && friend.keep!.isNotEmpty) {
              _keepUserIds.add(friend.userId);
            }
          }
        });
      }
    }
  }

  Future<void> _toggleKeepUser(String userId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendsProvider = Provider.of<FriendsProvider>(
      context,
      listen: false,
    );

    if (authProvider.currentUser == null) return;

    final isCurrentlyKept = _keepUserIds.contains(userId);

    // Optimistic update
    setState(() {
      if (isCurrentlyKept) {
        _keepUserIds.remove(userId);
      } else {
        _keepUserIds.add(userId);
      }
    });

    // Call backend
    final success = await friendsProvider.toggleKeepUser(
      userId,
      authProvider.currentUser!.userId,
      isCurrentlyKept,
    );

    if (!success) {
      // Revert if failed
      if (mounted) {
        setState(() {
          if (isCurrentlyKept) {
            _keepUserIds.add(userId);
          } else {
            _keepUserIds.remove(userId);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendsProvider.error ?? 'Failed to update keep status',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final friendsProvider = Provider.of<FriendsProvider>(context);
    final friends = friendsProvider.friends;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Keep Users'),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FriendsScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Friends'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'People in this list will always be kept in your gallery during Auto Clean.',
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
                : friends.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No friends yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FriendsScreen(),
                              ),
                            );
                          },
                          child: const Text('Add Friends'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: friends.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final isKept = _keepUserIds.contains(friend.userId);

                      return SwitchListTile(
                        value: isKept,
                        onChanged: (value) => _toggleKeepUser(friend.userId),
                        title: Text(
                          friend.displayName,
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: Text('@${friend.username}'),
                        secondary: CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          backgroundImage: friend.profilePictureUrl.isNotEmpty
                              ? CachedNetworkImageProvider(
                                  friend.profilePictureUrl,
                                )
                              : null,
                          child: friend.profilePictureUrl.isEmpty
                              ? Icon(
                                  Icons.person,
                                  color: theme.colorScheme.onSurfaceVariant,
                                )
                              : null,
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
