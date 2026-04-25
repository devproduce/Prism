// ... imports fixed at top
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/screens/home_screen.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:prism/widgets/prism_media_preview.dart';
import 'package:prism/widgets/recipient_selector_sheet.dart';
import 'package:prism/utils/constants.dart';
import 'package:prism/utils/error_handler.dart';
import 'package:prism/widgets/shimmer_placeholder.dart';
import 'package:prism/models/sharing_models.dart';

class ConfirmSharingScreen extends StatefulWidget {
  final String? batchId; // Batch ID passed from notification

  const ConfirmSharingScreen({super.key, this.batchId});

  @override
  State<ConfirmSharingScreen> createState() => _ConfirmSharingScreenState();
}

class _ConfirmSharingScreenState extends State<ConfirmSharingScreen> {
  bool _isSharing = false;
  bool _isLoadingBatch = false;

  @override
  void initState() {
    super.initState();
    _loadBatchStatusIfNeeded();
  }

  Future<void> _loadBatchStatusIfNeeded() async {
    final sharingProvider = Provider.of<SharingProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // If batch status is null but we have a batch ID, reload from backend
    if (sharingProvider.batchStatus == null && widget.batchId != null) {
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
        // Navigate back to home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen(key: HomeScreen.homeScreenKey)),
        );
      }

      if (mounted) setState(() => _isLoadingBatch = false);
    }
  }

  Future<void> _handleShare() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSharing = true);
    final sharingProvider = Provider.of<SharingProvider>(
      context,
      listen: false,
    );
    final galleryProvider = Provider.of<GalleryProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final success = await sharingProvider.confirmShare();
      if (success && mounted) {
        // Refresh gallery to sync newly shared images to local album
        if (authProvider.currentUser != null) {
          galleryProvider.refreshAfterShare(authProvider.currentUser!.userId);
        }

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
          MaterialPageRoute(builder: (context) => HomeScreen(key: HomeScreen.homeScreenKey)),
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

  void _showRecipientSelector(BuildContext context, String imageId) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RecipientSelectorSheet(imageId: imageId),
    );
  }

  // Helper to fix image URLs
  String? _fixUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    final cleanUrl = url.startsWith('/') ? url.substring(1) : url;
    return '${ApiConstants.baseUrl}/$cleanUrl';
  }

  @override
  Widget build(BuildContext context) {
    final sharingProvider = Provider.of<SharingProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final batchStatus = sharingProvider.batchStatus;
    // Responsive Layout
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isTablet = screenWidth > 600;
    final gridColumns = isDesktop ? 4 : (isTablet ? 3 : 2);

    if (batchStatus == null || _isLoadingBatch) {
      return Scaffold(
        backgroundColor: PrismColors.voidBlack,
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

    final images = batchStatus.images;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text('Review & Share', style: PrismTextStyles.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PrismColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Recipients Section Header
                SliverToBoxAdapter(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.people_alt,
                            color: PrismColors.prismYellow,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sharing with ${batchStatus.recipients.length} ${batchStatus.recipients.length == 1 ? "Friend" : "Friends"}',
                            style: PrismTextStyles.h3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Recipients List
                SliverToBoxAdapter(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: PrismColors.surfaceGray,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: PrismColors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: batchStatus.recipients.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.person_off_outlined,
                                        size: 48,
                                        color: PrismColors.secondaryText,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No friends detected',
                                        style: PrismTextStyles.bodyMedium
                                            .copyWith(
                                              color: PrismColors.secondaryText,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: batchStatus.recipients.map((
                                  recipient,
                                ) {
                                  return _buildRecipientChip(
                                    recipient,
                                    authProvider,
                                  );
                                }).toList(),
                              ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // Grid Divider
                SliverToBoxAdapter(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text('Media', style: PrismTextStyles.h3),
                          const Spacer(),
                          Text(
                            'Tap to edit recipients',
                            style: PrismTextStyles.bodySmall.copyWith(
                              color: PrismColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Media Grid
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop
                        ? (screenWidth - 800) / 2
                        : 16, // Center grid on desktop if < 800 width, else padding
                  ),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: gridColumns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childCount: images.length,
                    itemBuilder: (context, index) {
                      final image = images[index];
                      final hasCustomRecipients = sharingProvider
                          .imageRecipientMap
                          .containsKey(image.id);

                      // Debug logging
                      debugPrint('🖼️ Image ${index + 1}:');
                      debugPrint('   ID: ${image.id}');
                      debugPrint('   URL: ${image.url}');
                      debugPrint('   Thumb URL: ${image.thumbUrl}');

                      // Fix URL
                      final imageUrl = _fixUrl(image.url ?? image.thumbUrl);

                      debugPrint('   Final URL: $imageUrl');

                      // Don't send auth headers for S3 signed URLs (they already have auth in URL params)
                      // Only send auth for direct API image URLs
                      final isSignedUrl =
                          imageUrl?.contains('X-Amz-Signature') ?? false;
                      final headers = isSignedUrl
                          ? null
                          : {'Authorization': 'Bearer ${authProvider.token}'};

                      return GestureDetector(
                        onTap: () => _showRecipientSelector(context, image.id),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: imageUrl != null
                                  ? PrismMediaPreview(
                                      imageUrl: imageUrl,
                                      mediaType: image.mediaType,
                                      height:
                                          200, // Fixed height or adjust for masonry
                                      fit: BoxFit.cover,
                                      placeholderColor: PrismColors.surfaceGray,
                                      httpHeaders: headers,
                                    )
                                  : Container(
                                      height: 200,
                                      color: PrismColors.surfaceGray,
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image_rounded,
                                          color: PrismColors.destructiveRed,
                                          size: 48,
                                        ),
                                      ),
                                    ),
                            ),

                            // Custom Recipients Indicator
                            if (hasCustomRecipients)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: PrismColors.prismYellow,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    size: 16,
                                    color: PrismColors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom padding for scroll area
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),

          // Privacy/Info Note (fixed above action bar)
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PrismColors.electricCyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: PrismColors.electricCyan.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.privacy_tip_outlined,
                      color: PrismColors.electricCyan,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Prism has auto-selected recipients based on who is in the photos.',
                        style: PrismTextStyles.bodySmall.copyWith(
                          color: PrismColors.electricCyan,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: PrismColors.surfaceGray,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                top: BorderSide(
                  color: PrismColors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    // Show message if no valid recipients
                    if (sharingProvider.imageRecipientMap.values
                        .expand((recipients) => recipients)
                        .where(
                          (r) =>
                              !{'archive', 'favourite', 'bin'}.contains(r) &&
                              r != authProvider.currentUser?.userId,
                        )
                        .isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Select at least one friend to share with',
                          style: PrismTextStyles.bodySmall.copyWith(
                            color: PrismColors.destructiveRed,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    // Buttons Row
                    Row(
                      children: [
                        // Cancel Button
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              // Cancel and clean up
                              sharingProvider.cancel();
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => HomeScreen(key: HomeScreen.homeScreenKey),
                                ),
                                (route) => false,
                              );
                            },
                            icon: const Icon(
                              Icons.close,
                              color: PrismColors.secondaryText,
                            ),
                            label: Text(
                              'Cancel',
                              style: PrismTextStyles.button.copyWith(
                                color: PrismColors.secondaryText,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Share Button
                        Expanded(
                          flex: 2,
                          child: Builder(
                            builder: (context) {
                              // Calculate actual recipient count (excluding current user)
                              final currentUserId =
                                  authProvider.currentUser?.userId;
                              final specialFlags = {
                                'archive',
                                'favourite',
                                'bin',
                              };

                              // Collect all unique recipient IDs from imageRecipientMap
                              final Set<String> allRecipientIds = {};
                              for (var recipients
                                  in sharingProvider.imageRecipientMap.values) {
                                for (var recipient in recipients) {
                                  // Skip special flags and current user
                                  if (!specialFlags.contains(recipient) &&
                                      recipient != currentUserId) {
                                    allRecipientIds.add(recipient);
                                  }
                                }
                              }

                              final hasValidRecipients =
                                  allRecipientIds.isNotEmpty;

                              return PrismButton(
                                text: 'Share Memories',
                                isLoading: _isSharing,
                                icon: Icons.send_rounded,
                                onPressed: hasValidRecipients
                                    ? _handleShare
                                    : null,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientChip(
    DetectedRecipient recipient,
    AuthProvider authProvider,
  ) {
    // Fix profile pic URL
    final profilePicUrl = recipient.profilePicId != null
        ? _fixUrl('images/${recipient.profilePicId}')
        : null;

    // Don't send auth headers for S3 signed URLs
    final isSignedUrl = profilePicUrl?.contains('X-Amz-Signature') ?? false;
    final headers = isSignedUrl
        ? null
        : {'Authorization': 'Bearer ${authProvider.token}'};

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PrismColors.inputGray,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: PrismColors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Profile Picture
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PrismColors.surfaceGray,
            ),
            clipBehavior: Clip.antiAlias,
            child: profilePicUrl != null
                ? Image.network(
                    profilePicUrl,
                    fit: BoxFit.cover,
                    headers: headers,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.person,
                        color: PrismColors.secondaryText,
                        size: 20,
                      );
                    },
                  )
                : Icon(
                    Icons.person,
                    color: PrismColors.secondaryText,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 8),
          // Username
          Text(
            recipient.username,
            style: PrismTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          // Photo count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: PrismColors.prismYellow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${recipient.count}',
              style: PrismTextStyles.bodySmall.copyWith(
                color: PrismColors.black,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
