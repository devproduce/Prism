import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/screens/confirm_sharing_screen.dart';
import 'package:prism/utils/theme.dart';
import 'package:prism/widgets/gradient_scaffold.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToConfirm() {
    if (_hasNavigated) return;
    _hasNavigated = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ConfirmSharingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation during processing
        return false;
      },
      child: GradientScaffold(
        body: SafeArea(
          child: Consumer<SharingProvider>(
            builder: (context, sharingProvider, _) {
              // Navigate to confirm screen when processing is complete
              if (sharingProvider.batchStatus?.isCompleted == true &&
                  !_hasNavigated) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _navigateToConfirm();
                });
              }

              return Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              _showCancelDialog(context, sharingProvider),
                          icon: const Icon(Icons.close),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Processing',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),

                  // Error banner if present
                  if (sharingProvider.error != null)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              sharingProvider.error!,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Content
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Loading animation
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 8,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.colorScheme.primaryContainer,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 8,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.colorScheme.primary,
                                    ),
                                    // Indeterminate for now, could be progress based
                                  ),
                                ),
                                Icon(
                                  Icons.auto_awesome,
                                  size: 48,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Status text
                          Text(
                            'Analyzing your content',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 16),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Prism\'s AI is performing Triple-Filtered Relevance analysis.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Analysis steps
                          _buildAnalysisStep(
                            context,
                            'Face Recognition',
                            sharingProvider.batchStatus?.isCompleted == true,
                          ),
                          _buildAnalysisStep(
                            context,
                            'Object/Scene Analysis',
                            sharingProvider.batchStatus?.isCompleted == true,
                          ),
                          _buildAnalysisStep(
                            context,
                            'Video Content Analysis',
                            sharingProvider.batchStatus?.isCompleted == true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Stop button
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () =>
                            _showCancelDialog(context, sharingProvider),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                        child: const Text('Stop Processing'),
                      ),
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

  void _showCancelDialog(
    BuildContext context,
    SharingProvider sharingProvider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop Processing?'),
        content: const Text(
          'Are you sure you want to stop the processing? Your images will not be shared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Continue Processing'),
          ),
          FilledButton(
            onPressed: () {
              sharingProvider.cancel();
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pop(context); // Close processing screen
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisStep(
    BuildContext context,
    String title,
    bool isCompleted,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isCompleted
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
