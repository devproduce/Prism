import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/screens/friends_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/utils/error_handler.dart';

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

        ErrorHandler.showErrorSnackbar(
          context,
          message: friendsProvider.error ?? 'Failed to update keep status',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsProvider = Provider.of<FriendsProvider>(context);
    final friends = friendsProvider.friends;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text('Keep Users', style: PrismTextStyles.h2),
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FriendsScreen()),
              );
            },
            icon: const Icon(
              Icons.person_add_rounded,
              color: PrismColors.prismYellow,
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
                'People in this list will always be kept in your gallery during Auto Clean.',
                style: PrismTextStyles.bodyMedium.copyWith(
                  color: PrismColors.secondaryText,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: friendsProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: PrismColors.prismYellow,
                      ),
                    )
                  : friends.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: PrismColors.surfaceGray,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: PrismColors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: const Icon(
                              Icons.people_outline_rounded,
                              size: 48,
                              color: PrismColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No friends yet',
                            style: PrismTextStyles.h3.copyWith(
                              color: PrismColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 24),
                          PrismButton(
                            text: 'Add Friends',
                            icon: Icons.add,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const FriendsScreen(),
                                ),
                              );
                            },
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

                        return PrismCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: PrismColors.surfaceGray,
                                backgroundImage:
                                    friend.profilePictureUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(
                                        friend.profilePictureUrl,
                                      )
                                    : null,
                                child: friend.profilePictureUrl.isEmpty
                                    ? Icon(
                                        Icons.person,
                                        color: PrismColors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friend.displayName,
                                      style: PrismTextStyles.bodyLarge,
                                    ),
                                    Text(
                                      '@${friend.username}',
                                      style: PrismTextStyles.bodySmall.copyWith(
                                        color: PrismColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isKept,
                                onChanged: (value) {
                                  HapticFeedback.selectionClick();
                                  _toggleKeepUser(friend.userId);
                                },
                                activeColor: PrismColors.prismYellow,
                                activeTrackColor: PrismColors.prismYellow
                                    .withValues(alpha: 0.3),
                                inactiveThumbColor: PrismColors.white
                                    .withValues(alpha: 0.54),
                                inactiveTrackColor: PrismColors.white
                                    .withValues(alpha: 0.1),
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
