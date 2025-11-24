import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/screens/confirm_sharing_screen.dart';
import 'package:prism/utils/theme.dart';

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
    final size = MediaQuery.of(context).size;
    final isDark = theme.brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation during processing
        return false;
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Consumer<SharingProvider>(
            builder: (context, sharingProvider, _) {
              // Navigate to confirm screen when processing is complete
              if (sharingProvider.batchStatus?.isCompleted == true &&
                  !_hasNavigated) {
                debugPrint(
                  '✅ [ProcessingScreen] Processing complete, navigating to confirm screen',
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _navigateToConfirm();
                });
              }

              // Show error if processing failed
              if (sharingProvider.error != null && !_hasNavigated) {
                debugPrint(
                  '❌ [ProcessingScreen] Error detected: ${sharingProvider.error}',
                );
              }

              return Column(
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.all(size.width * 0.05),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            _showCancelDialog(context, sharingProvider);
                          },
                          child: Icon(
                            Icons.arrow_back,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(width: size.width * 0.04),
                        Text(
                          'Prism',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error banner if present
                  if (sharingProvider.error != null)
                    Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: size.width * 0.05,
                        vertical: size.height * 0.01,
                      ),
                      padding: EdgeInsets.all(size.width * 0.04),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: size.width * 0.06,
                          ),
                          SizedBox(width: size.width * 0.03),
                          Expanded(
                            child: Text(
                              sharingProvider.error!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.red,
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
                          RotationTransition(
                            turns: _animationController,
                            child: Container(
                              width: size.width * 0.25,
                              height: size.width * 0.25,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryAccent,
                                    AppTheme.primaryAccent.withOpacity(0.3),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: size.width * 0.2,
                                  height: size.width * 0.2,
                                  decoration: BoxDecoration(
                                    color: theme.scaffoldBackgroundColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: size.height * 0.05),

                          // Status text
                          Text(
                            'Analyzing your content',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),

                          SizedBox(height: size.height * 0.015),

                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: size.width * 0.1,
                            ),
                            child: Text(
                              'Prism\'s AI is performing Triple-Filtered Relevance analysis.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          SizedBox(height: size.height * 0.06),

                          // Analysis steps
                          _buildAnalysisStep(
                            context,
                            'Face Recognition',
                            sharingProvider.batchStatus?.isCompleted == true
                                ? 'Done'
                                : 'In Progress',
                            sharingProvider.batchStatus?.isCompleted == true,
                            size,
                            theme,
                            isDark,
                          ),

                          SizedBox(height: size.height * 0.02),

                          _buildAnalysisStep(
                            context,
                            'Object/Scene Analysis',
                            sharingProvider.batchStatus?.isCompleted == true
                                ? 'Done'
                                : 'In Progress',
                            sharingProvider.batchStatus?.isCompleted == true,
                            size,
                            theme,
                            isDark,
                          ),

                          SizedBox(height: size.height * 0.02),

                          _buildAnalysisStep(
                            context,
                            'Video Content Analysis',
                            sharingProvider.batchStatus?.isCompleted == true
                                ? 'Done'
                                : 'Pending',
                            sharingProvider.batchStatus?.isCompleted == true,
                            size,
                            theme,
                            isDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Stop button
                  Padding(
                    padding: EdgeInsets.all(size.width * 0.05),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            _showCancelDialog(context, sharingProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: size.height * 0.02,
                          ),
                        ),
                        child: Text(
                          'Stop Processing',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: size.width * 0.04,
                          ),
                        ),
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
          TextButton(
            onPressed: () {
              debugPrint('⏹️ [ProcessingScreen] User cancelled processing');
              sharingProvider.cancel();
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pop(context); // Close processing screen
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisStep(
    BuildContext context,
    String title,
    String status,
    bool isCompleted,
    Size size,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      width: size.width * 0.8,
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            status,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isCompleted
                  ? AppTheme.primaryAccent
                  : theme.colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
