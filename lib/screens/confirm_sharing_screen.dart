import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/models/review_models.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/screens/home_screen.dart';
import 'package:prism/screens/sharing_recipient_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:prism/utils/media_url_utils.dart';
import 'package:prism/utils/responsive_helper.dart';
import 'package:prism/widgets/recipient_selector_sheet.dart';
import 'package:prism/widgets/review/review_bottom_bar.dart';
import 'package:prism/widgets/review/review_no_face_send_all.dart';
import 'package:prism/widgets/review/review_person_section.dart';
import 'package:prism/widgets/review/review_found_contacts_section.dart';
import 'package:prism/widgets/review/review_unknown_faces_section.dart';
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
  int _lastAppliedUnknownCount = -1;
  final Set<String> _expandedGroupIds = {};

  @override
  void initState() {
    super.initState();
    _loadBatchStatusIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReviewContext());
  }


  Future<void> _loadReviewContext() async {
    final userId = context.read<AuthProvider>().currentUser?.userId;
    if (userId == null) return;

    final friendsProvider = context.read<FriendsProvider>();
    await friendsProvider.syncFriendshipsIfStale(userId);

    await friendsProvider.loadRecommendations(userId);

    await friendsProvider.loadBatchUnknownFaces(userId);
    if (!mounted) return;
    _applyDiscoveryEnrichment();
  }

  void _applyDiscoveryEnrichment() {
    final userId = context.read<AuthProvider>().currentUser?.userId;
    final sharingProvider = context.read<SharingProvider>();
    final friendsProvider = context.read<FriendsProvider>();
    final batch = sharingProvider.batchStatus;

    if (userId == null || batch == null || !batch.isCompleted) return;

    final beforeUnknowns = batch.unknowns.length;
    sharingProvider.applyDiscoveryEnrichment(
      friendUserIds: friendsProvider.friends.map((friend) => friend.userId).toSet(),
      onPlatformUsers: friendsProvider.contactSyncResult?.onPlatform ?? const [],
    );

    final afterUnknowns = sharingProvider.batchStatus?.unknowns.length ?? beforeUnknowns;
    if (afterUnknowns != _lastAppliedUnknownCount) {
      _lastAppliedUnknownCount = afterUnknowns;
      if (mounted) {
        setState(() => _ensureDefaultExpanded(sharingProvider));
      }
    }
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

    final defaultGroup = sharingProvider.reviewLayout?.defaultExpandedGroup;
    if (defaultGroup == null) return;

    _expandedInitialized = true;
    _expandedGroupIds.add(defaultGroup.id);
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

        final recipients = sharingProvider.collectConfirmedRecipients();
        final photoCount = sharingProvider.sharedPhotoCount;
        sharingProvider.clearBatch();
        HapticFeedback.heavyImpact();

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SharingRecipientScreen(
              recipients: recipients,
              photoCount: photoCount,
            ),
          ),
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
    final layout = sharingProvider.reviewLayout;

    if (batchStatus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (batchStatus.isCompleted) _applyDiscoveryEnrichment();
        if (!_expandedInitialized) {
          setState(() => _ensureDefaultExpanded(sharingProvider));
        }
      });
    }

    final contentInset = _contentInset(context);
    final titleStyle = PrismTextStyles.h2.copyWith(
      fontSize: ResponsiveHelper.scaledFontSize(context, 24),
    );

    if (batchStatus == null || _isLoadingBatch) {
      return Scaffold(
        backgroundColor: PrismColors.voidBlack,
        appBar: AppBar(
          title: Text('Review & Share', style: titleStyle),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.horizontalPadding(context),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoadingBatch) ...[
                  const CircularProgressIndicator(color: PrismColors.prismYellow),
                  SizedBox(height: ResponsiveHelper.spacingM(context)),
                  Text(
                    'Loading batch...',
                    style: PrismTextStyles.bodyLarge.copyWith(
                      fontSize: ResponsiveHelper.scaledFontSize(context, 16),
                    ),
                  ),
                ] else
                  ShimmerLayouts.galleryGrid(
                    itemCount: ResponsiveHelper.isSmallScreen(context) ? 4 : 6,
                    crossAxisCount: ResponsiveHelper.galleryGridCount(context),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final userId = context.read<AuthProvider>().currentUser?.userId;
    final foundContacts = userId == null
        ? const <ReviewSuggestion>[]
        : friendsProvider.mergeBatchSuggestions(
            fromBatch: sharingProvider.batchContactSuggestions,
            batch: batchStatus,
            currentUserId: userId,
          );
    final sections = layout?.orderedSections ?? const <ReviewPersonGroup>[];
    final unknownFaces = batchStatus.unknowns;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exitReview();
      },
      child: Scaffold(
        backgroundColor: PrismColors.voidBlack,
        appBar: AppBar(
          title: Text('Review & Share', style: titleStyle),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: PrismColors.white,
              size: ResponsiveHelper.iconSizeM(context),
            ),
            onPressed: _exitReview,
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (foundContacts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: ReviewFoundContactsSection(
                            contacts: foundContacts,
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
                  if (unknownFaces.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: ReviewUnknownFacesSection(
                            unknowns: unknownFaces,
                          ),
                        ),
                      ),
                    ),
                  if (!(layout?.hasPhotos ?? false))
                    const SliverToBoxAdapter(child: _NoPhotosState())
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final group = sections[index];
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: ReviewPersonSection(
                                group: group,
                                isExpanded:
                                    _expandedGroupIds.contains(group.id),
                                onToggle: () => _toggleGroup(group.id),
                                onImageTap: _showRecipientSelector,
                                fixUrl: MediaUrlUtils.resolve,
                                headersForUrl: _headersForUrl,
                                recipientCountForImage:
                                    sharingProvider.recipientCountForImage,
                                expandedHeaderExtra: group.isNoFace
                                    ? const ReviewNoFaceSendAllTile()
                                    : null,
                              ),
                            ),
                          );
                        },
                        childCount: sections.length,
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
    final screenWidth = ResponsiveHelper.screenWidth(context);
    final basePadding = ResponsiveHelper.horizontalPadding(context);
    if (screenWidth <= ResponsiveHelper.tablet) return basePadding;
    return (screenWidth - 800).clamp(basePadding, double.infinity) / 2;
  }
}

class _NoPhotosState extends StatelessWidget {
  const _NoPhotosState();

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveHelper.isSmallScreen(context) ? 24.0 : 32.0;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: ResponsiveHelper.iconSizeXL(context),
              color: PrismColors.secondaryText,
            ),
            SizedBox(height: ResponsiveHelper.spacingS(context)),
            Text(
              'No photos in this batch',
              style: PrismTextStyles.bodyMedium.copyWith(
                color: PrismColors.secondaryText,
                fontSize: ResponsiveHelper.scaledFontSize(context, 14),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
