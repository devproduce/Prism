import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/glass_widgets.dart';
import 'package:prism/widgets/gradient_background.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/screens/friends_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
            backgroundColor: PrismColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsProvider = Provider.of<FriendsProvider>(context);
    final friends = friendsProvider.friends;

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
                        Text('Keep Users', style: PrismTextStyles.h2),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FriendsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.person_add_rounded,
                        color: PrismColors.electricBlue,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'People in this list will always be kept in your gallery during Auto Clean.',
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
                    : friends.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 64,
                              color: Colors.white24,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No friends yet',
                              style: PrismTextStyles.h3.copyWith(
                                color: Colors.white38,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GlassButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const FriendsScreen(),
                                  ),
                                );
                              },
                              text: 'Add Friends',
                              icon: Icons.add,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: friends.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          final isKept = _keepUserIds.contains(friend.userId);

                          return GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: PrismColors.glassLight,
                                  backgroundImage:
                                      friend.profilePictureUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          friend.profilePictureUrl,
                                        )
                                      : null,
                                  child: friend.profilePictureUrl.isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white60,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        friend.displayName,
                                        style: PrismTextStyles.bodyLarge,
                                      ),
                                      Text(
                                        '@${friend.username}',
                                        style: PrismTextStyles.bodySmall
                                            .copyWith(color: Colors.white54),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isKept,
                                  onChanged: (value) =>
                                      _toggleKeepUser(friend.userId),
                                  activeColor: PrismColors.electricBlue,
                                  activeTrackColor: PrismColors.electricBlue
                                      .withOpacity(0.3),
                                  inactiveThumbColor: Colors.white54,
                                  inactiveTrackColor: Colors.white.withOpacity(
                                    0.1,
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
