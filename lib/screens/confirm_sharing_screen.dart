import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/models/review_models.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/screens/home_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:prism/utils/media_url_utils.dart';
import 'package:prism/widgets/recipient_selector_sheet.dart';
import 'package:prism/widgets/review/review_bottom_bar.dart';
import 'package:prism/widgets/review/review_no_face_send_all.dart';
import 'package:prism/widgets/review/review_person_section.dart';
import 'package:prism/widgets/review/review_suggestions_strip.dart';
import 'package:prism/widgets/shimmer_placeholder.dart';

class ConfirmSharingScreen extends StatefulWidget {
  final String? batchId;

  const ConfirmSharingScreen({super.key, this.batchId});

  @override
  State<ConfirmSharingScreen> createState() => _ConfirmSharingScreenState();
}

class _ConfirmSharingScreenState extends State<ConfirmSharingScreen> {
  bool _isSharing = false;
  bool _isLoadingBatch = false;
  bool _expandedInitialized = false;
  final ScrollController _suggestionsScrollController = ScrollController();
  final Set<String> _expandedGroupIds = {};

  @override
  void initState() {
    super.initState();
    _loadBatchStatusIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReviewContext());
  }

  @override
  void dispose() {
    _suggestionsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadReviewContext() async {
    final userId = context.read<AuthProvider>().currentUser?.userId;
    if (userId == null) return;

    final friendsProvider = context.read<FriendsProvider>();
    await friendsProvider.syncFriendshipsIfStale(userId);
    await friendsProvider.loadRecommendations(userId);
  }

  Future<void> _loadBatchStatusIfNeeded() async {
    final sharingProvider = context.read<SharingProvider>();
    final authProvider = context.read<AuthProvider>();

    if (widget.batchId == null ||
        (sharingProvider.batchStatus != null &&
            sharingProvider.batchStatus!.batchId == widget.batchId)) {
      return;
    }

    if (authProvider.currentUser == null) {
      _showError('User not authenticated');
      return;
    }

    setState(() => _isLoadingBatch = true);
    final success = await sharingProvider.loadBatchStatus(
      widget.batchId!,
      authProvider.currentUser!.userId,
    );

    if (!success && mounted) {
      _showError(sharingProvider.error ?? 'Failed to load batch');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(key: HomeScreen.homeScreenKey),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _isLoadingBatch = false;
        _ensureDefaultExpanded(sharingProvider);
      });
    }
  }

  void _ensureDefaultExpanded(SharingProvider sharingProvider) {
    if (_expandedInitialized) return;

    final topGroup = sharingProvider.friendPhotoGroups.firstOrNull;
    if (topGroup == null) return;

    _expandedInitialized = true;
    _expandedGroupIds.add(topGroup.id);
  }

  Future<void> _exitReview() async {
    await context.read<SharingProvider>().cancel();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleShare() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSharing = true);

    final sharingProvider = context.read<SharingProvider>();
    final galleryProvider = context.read<GalleryProvider>();
    final authProvider = context.read<AuthProvider>();

    try {
      final success = await sharingProvider.confirmShare();
      if (success && mounted) {
        final userId = authProvider.currentUser?.userId;
        if (userId != null) {
          galleryProvider.refreshAfterShare(userId);
        }
        sharingProvider.clearBatch();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: PrismColors.black),
                const SizedBox(width: 8),
                Text(
                  'Memories Shared Successfully!',
                  style: PrismTextStyles.bodyMedium.copyWith(
                    color: PrismColors.black,
                  ),
                ),
              ],
            ),
            backgroundColor: PrismColors.prismYellow,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        HapticFeedback.heavyImpact();

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => HomeScreen(key: HomeScreen.homeScreenKey),
          ),
          (route) => false,
        );
      } else if (mounted) {
        _showError(sharingProvider.error ?? 'Sharing failed');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _showError(String message) {
    ErrorHandler.showErrorSnackbar(context, message: message);
  }

  void _showRecipientSelector(String imageId) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RecipientSelectorSheet(imageId: imageId),
    );
  }

  void _scrollSuggestionsToEnd() {
    if (!_suggestionsScrollController.hasClients) return;
    _suggestionsScrollController.animateTo(
      _suggestionsScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _toggleGroup(String groupId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expandedGroupIds.contains(groupId)) {
        _expandedGroupIds.remove(groupId);
      } else {
        _expandedGroupIds.add(groupId);
      }
    });
  }

  Future<void> _handleAddSuggestion(ReviewSuggestion suggestion) async {
    final userId = context.read<AuthProvider>().currentUser?.userId;
    if (userId == null) return;

    final friendsProvider = context.read<FriendsProvider>();
    final success = await friendsProvider.sendFriendRequest(
      userId,
      suggestion.username,
    );

    if (!mounted) return;
    if (!success) {
      _showError(friendsProvider.error ?? 'Failed to send request');
    }
  }

  Map<String, String>? _headersForUrl(String? url) {
    return MediaUrlUtils.authHeaders(
      url,
      context.read<AuthProvider>().token,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sharingProvider = context.watch<SharingProvider>();
    final friendsProvider = context.watch<FriendsProvider>();
    final batchStatus = sharingProvider.batchStatus;

    if (batchStatus != null && !_expandedInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _expandedInitialized) return;
        setState(() => _ensureDefaultExpanded(sharingProvider));
      });
    }

    final contentInset = _contentInset(context);

    if (batchStatus == null || _isLoadingBatch) {
      return Scaffold(
        backgroundColor: PrismColors.voidBlack,
        appBar: AppBar(
          title: Text('Review & Share', style: PrismTextStyles.h2),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoadingBatch) ...[
                const CircularProgressIndicator(color: PrismColors.prismYellow),
                const SizedBox(height: 16),
                Text('Loading batch...', style: PrismTextStyles.bodyLarge),
              ] else
                ShimmerLayouts.galleryGrid(itemCount: 6, crossAxisCount: 2),
            ],
          ),
        ),
      );
    }

    final friendGroups = sharingProvider.friendPhotoGroups;
    final noFaceGroup = sharingProvider.noFaceGroup;
    final suggestions = friendsProvider.visibleBatchSuggestions(
      sharingProvider.batchContactSuggestions,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exitReview();
      },
      child: Scaffold(
        backgroundColor: PrismColors.voidBlack,
        appBar: AppBar(
          title: Text('Review & Share', style: PrismTextStyles.h2),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: PrismColors.white),
            onPressed: _exitReview,
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (suggestions.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: ReviewSuggestionsStrip(
                            suggestions: suggestions,
                            scrollController: _suggestionsScrollController,
                            onViewAll: _scrollSuggestionsToEnd,
                            onAddTap: _handleAddSuggestion,
                            statusFor: (userId, username) =>
                                friendsProvider.friendshipDisplayStatusFor(
                              userId: userId,
                              username: username,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (friendGroups.isEmpty && noFaceGroup == null)
                    const SliverToBoxAdapter(
                      child: _EmptyReviewState(),
                    ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: _ReviewGroupTile(
                            group: friendGroups[index],
                            isExpanded:
                                _expandedGroupIds.contains(friendGroups[index].id),
                            onToggle: () => _toggleGroup(friendGroups[index].id),
                            onImageTap: _showRecipientSelector,
                            headersForUrl: _headersForUrl,
                            recipientCountForImage:
                                sharingProvider.recipientCountForImage,
                          ),
                        ),
                      ),
                      childCount: friendGroups.length,
                    ),
                  ),
                  if (noFaceGroup != null)
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: _ReviewGroupTile(
                            group: noFaceGroup,
                            isExpanded:
                                _expandedGroupIds.contains(noFaceGroup.id),
                            onToggle: () => _toggleGroup(noFaceGroup.id),
                            onImageTap: _showRecipientSelector,
                            headersForUrl: _headersForUrl,
                            recipientCountForImage:
                                sharingProvider.recipientCountForImage,
                            expandedHeaderExtra: const ReviewNoFaceSendAllTile(),
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
            ReviewBottomBar(
              contentInset: contentInset,
              onCancel: _exitReview,
              onShare: sharingProvider.hasValidShareRecipients
                  ? _handleShare
                  : null,
              isSharing: _isSharing,
              showNoRecipientsWarning: !sharingProvider.hasValidShareRecipients,
            ),
          ],
        ),
      ),
    );
  }

  double _contentInset(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth <= 900) return 16;
    return (screenWidth - 800).clamp(16.0, double.infinity) / 2;
  }
}

class _ReviewGroupTile extends StatelessWidget {
  final ReviewPersonGroup group;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(String imageId) onImageTap;
  final Map<String, String>? Function(String? url) headersForUrl;
  final int Function(String imageId) recipientCountForImage;
  final Widget? expandedHeaderExtra;

  const _ReviewGroupTile({
    required this.group,
    required this.isExpanded,
    required this.onToggle,
    required this.onImageTap,
    required this.headersForUrl,
    required this.recipientCountForImage,
    this.expandedHeaderExtra,
  });

  @override
  Widget build(BuildContext context) {
    return ReviewPersonSection(
      group: group,
      isExpanded: isExpanded,
      onToggle: onToggle,
      onImageTap: onImageTap,
      fixUrl: MediaUrlUtils.resolve,
      headersForUrl: headersForUrl,
      recipientCountForImage: recipientCountForImage,
      expandedHeaderExtra: expandedHeaderExtra,
    );
  }
}

class _EmptyReviewState extends StatelessWidget {
  const _EmptyReviewState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: PrismColors.secondaryText,
            ),
            SizedBox(height: 12),
            Text(
              'No friends detected in these photos',
              style: PrismTextStyles.bodyMedium.copyWith(
                color: PrismColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
