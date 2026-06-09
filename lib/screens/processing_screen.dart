import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/screens/confirm_sharing_screen.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/utils/error_handler.dart';

class ProcessingScreen extends StatefulWidget {
  /// Optional batch ID when navigating from notification.
  /// If provided, the screen will load the batch status from the server.
  final String? batchId;

  const ProcessingScreen({super.key, this.batchId});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _hasNavigated = false;
  bool _isLoadingBatch = false;

  // Animation state for logs
  int _logStep = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Start log sequence
    _startLogSequence();

    // If batchId is provided (navigation from notification), load batch status
    if (widget.batchId != null) {
      _loadBatchStatusIfNeeded();
    }
  }

  /// Load batch status when navigating from notification.
  Future<void> _loadBatchStatusIfNeeded() async {
    if (widget.batchId == null) return;

    setState(() => _isLoadingBatch = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final sharingProvider = Provider.of<SharingProvider>(
        context,
        listen: false,
      );

      final userId = authProvider.currentUser?.userId;
      if (userId == null) {
        debugPrint('⚠️ [ProcessingScreen] User not authenticated');
        setState(() => _isLoadingBatch = false);
        return;
      }

      debugPrint(
        '🔄 [ProcessingScreen] Loading batch status for: ${widget.batchId}',
      );

      final success = await sharingProvider.loadBatchStatus(
        widget.batchId!,
        userId,
      );

      if (success && _shouldNavigateToConfirm(sharingProvider)) {
        // Batch is already complete, navigate to confirm screen
        _navigateToConfirm(sharingProvider);
      }
    } catch (e) {
      debugPrint('❌ [ProcessingScreen] Error loading batch status: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingBatch = false);
      }
    }
  }

  void _startLogSequence() {
    // Sequence timing to match a "real" feel
    const steps = [
      Duration(milliseconds: 500), // System initialized
      Duration(milliseconds: 1500), // Extracting embeddings
      Duration(milliseconds: 2000), // Matching faces
      Duration(milliseconds: 1000), // Scene classification
    ];

    // Better approach: recursive delays
    _runLogStep(0, steps);
  }

  void _runLogStep(int step, List<Duration> delays) {
    if (step >= delays.length) return;

    // Wait for the duration of the current step
    Future.delayed(delays[step], () {
      if (mounted) {
        setState(() => _logStep = step + 1);
        _runLogStep(step + 1, delays);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToConfirm(SharingProvider sharingProvider) {
    if (_hasNavigated) return;
    final batchId = sharingProvider.currentBatchId;
    if (batchId == null) return;
    if (sharingProvider.batchStatus?.batchId != batchId) return;
    if (sharingProvider.batchStatus?.isCompleted != true) return;

    _hasNavigated = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmSharingScreen(batchId: batchId),
      ),
    );
  }

  bool _shouldNavigateToConfirm(SharingProvider sharingProvider) {
    final batchId = sharingProvider.currentBatchId;
    if (batchId == null || _hasNavigated) return false;
    final status = sharingProvider.batchStatus;
    return status?.isCompleted == true && status?.batchId == batchId;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation during processing
        return false;
      },
      child: Scaffold(
        backgroundColor: PrismColors.voidBlack,
        body: SafeArea(
          child: Consumer<SharingProvider>(
            builder: (context, sharingProvider, _) {
              // Navigate to confirm screen when processing is complete
              if (_shouldNavigateToConfirm(sharingProvider)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _navigateToConfirm(sharingProvider);
                });
              }

              return Column(
                children: [
                  // Content
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    PrismColors.electricCyan,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Analyzing Content',
                                style: PrismTextStyles.h2,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            sharingProvider.batchProcessingSubtitle ??
                                'Prism AI is detecting faces and scenes...',
                            style: PrismTextStyles.bodyMedium.copyWith(
                              color: PrismColors.secondaryText,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 48),

                          // Terminal Log Box
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: PrismColors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: PrismColors.white.withValues(
                                  alpha: 0.05,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLogItem(
                                  label: 'System initialized',
                                  color: PrismColors.successGreen,
                                  icon: Icons.terminal,
                                  isVisible: _logStep >= 1,
                                  isCompleted: true,
                                ),
                                const SizedBox(height: 12),
                                _buildLogItem(
                                  label: 'Extracting embeddings...',
                                  color: PrismColors.electricCyan,
                                  icon: Icons.refresh,
                                  isVisible: _logStep >= 2,
                                  isLoading: _logStep == 2,
                                ),
                                const SizedBox(height: 12),
                                _buildLogItem(
                                  label: 'Matching faces...',
                                  color: PrismColors.secondaryText,
                                  isDot: true,
                                  isVisible: _logStep >= 3,
                                  isLoading: _logStep == 3,
                                ),
                                const SizedBox(height: 12),
                                _buildLogItem(
                                  label: 'Scene classification...',
                                  color: PrismColors.secondaryText,
                                  isDot: true,
                                  isVisible: _logStep >= 4,
                                  isLoading: _logStep == 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Controls
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [

                        Row(
                          children: [
                            Expanded(
                              child: PrismButton(
                                text: 'Cancel',
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  _showCancelDialog(context, sharingProvider);
                                },
                                type:
                                    PrismButtonType.secondary, // Outline approx
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: PrismButton(
                                text: 'Sharing...',
                                onPressed: null, // Disabled
                                type: PrismButtonType.primary,
                                isLoading: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLogItem({
    required String label,
    required Color color,
    IconData? icon,
    bool isDot = false,
    bool isVisible = false,
    bool isLoading = false,
    bool isCompleted = false,
  }) {
    if (!isVisible) {
      return const SizedBox(height: 24); // Placeholder height
    }

    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : isDot
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                  )
                : Icon(icon, color: color, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontFamily: 'Roboto Mono', // Monospace feel
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _showCancelDialog(
    BuildContext context,
    SharingProvider sharingProvider,
  ) async {
    HapticFeedback.selectionClick();

    final confirmed = await ErrorHandler.showConfirmationDialog(
      context,
      title: 'Stop Processing?',
      message: 'Are you sure you want to stop? Your upload will be cancelled.',
      confirmText: 'Stop',
      cancelText: 'Resume',
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      sharingProvider.cancel();
      Navigator.pop(context);
    }
  }
}
