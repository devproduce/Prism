import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/widgets/prism_card.dart';
import 'package:prism/widgets/prism_button.dart';
import 'package:prism/api/engagement_api.dart';
import 'package:prism/utils/error_handler.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _engagementApi = EngagementApi();

  String? _selectedFeedbackType;
  String? _selectedCategory;
  bool _isSubmitting = false;
  bool _submitted = false;

  final List<Map<String, dynamic>> _feedbackTypes = [
    {
      'value': 'bug_report',
      'label': 'Bug Report',
      'icon': Icons.bug_report_outlined,
      'color': Colors.red,
      'description': 'Report a technical issue',
    },
    {
      'value': 'feature_request',
      'label': 'Feature Request',
      'icon': Icons.lightbulb_outline_rounded,
      'color': PrismColors.purple,
      'description': 'Suggest a new feature',
    },
    {
      'value': 'general',
      'label': 'General Feedback',
      'icon': Icons.chat_bubble_outline_rounded,
      'color': PrismColors.electricBlue,
      'description': 'Share your thoughts',
    },
    {
      'value': 'complaint',
      'label': 'Complaint',
      'icon': Icons.sentiment_dissatisfied_outlined,
      'color': Colors.orange,
      'description': 'Report a concern',
    },
    {
      'value': 'praise',
      'label': 'Praise',
      'icon': Icons.favorite_outline_rounded,
      'color': PrismColors.successGreen,
      'description': 'Share what you love',
    },
  ];

  final List<Map<String, String>> _categories = [
    {'value': 'ui', 'label': 'UI/Design'},
    {'value': 'performance', 'label': 'Performance'},
    {'value': 'feature', 'label': 'Feature'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFeedbackType == null) {
      ErrorHandler.showErrorSnackbar(
        context,
        message: 'Please select a feedback type',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _engagementApi.submitFeedback(
        userId: user.userId,
        email: user.email,
        feedbackType: _selectedFeedbackType!,
        category: _selectedCategory,
        message: _messageController.text.trim(),
        source: 'dashboard',
      );

      HapticFeedback.mediumImpact();

      setState(() {
        _submitted = true;
        _isSubmitting = false;
      });

      // Show success for 2 seconds then go back
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          message: 'Failed to submit feedback. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalPadding = screenWidth < 360 ? 16.0 : 20.0;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        title: Text(
          'Write to Us',
          style: PrismTextStyles.h2.copyWith(fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PrismColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _submitted ? _buildSuccessView() : _buildFeedbackForm(
        horizontalPadding,
        isSmallScreen,
        screenWidth,
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PrismColors.successGreen.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 60,
                color: PrismColors.successGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Thank You!',
              style: PrismTextStyles.h1.copyWith(fontSize: 32),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your voice matters to us. We\'ll review your feedback and use it to make Prism even better! ✨',
              style: PrismTextStyles.bodyLarge.copyWith(
                color: PrismColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackForm(
    double horizontalPadding,
    bool isSmallScreen,
    double screenWidth,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(horizontalPadding),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Message
            PrismCard(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: PrismColors.prismYellow,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'We\'d Love to Hear From You!',
                        style: PrismTextStyles.h2.copyWith(
                          fontSize: (screenWidth * 0.055).clamp(16.0, 24.0),
                        ),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your feedback helps us make Prism better for everyone',
                      style: PrismTextStyles.bodyMedium.copyWith(
                        color: PrismColors.secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: isSmallScreen ? 16 : 24),

            // Feedback Type Section
            Text(
              'What type of feedback?',
              style: PrismTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...(_feedbackTypes.map((type) => _buildFeedbackTypeCard(
              type,
              screenWidth,
            ))),

            SizedBox(height: isSmallScreen ? 16 : 24),

            // Category Section (Optional)
            Text(
              'Category (Optional)',
              style: PrismTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            PrismCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Select a category',
                    hintStyle: TextStyle(color: PrismColors.secondaryText),
                  ),
                  dropdownColor: PrismColors.surfaceGray,
                  style: PrismTextStyles.bodyLarge,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: PrismColors.white,
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category['value'],
                      child: Text(category['label']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategory = value);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
            ),

            SizedBox(height: isSmallScreen ? 16 : 24),

            // Message Section
            Text(
              'Your Message *',
              style: PrismTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            PrismCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _messageController,
                      maxLines: isSmallScreen ? 6 : 8,
                      maxLength: 1000,
                      style: PrismTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Share your thoughts with us...',
                        hintStyle: PrismTextStyles.bodyLarge.copyWith(
                          color: PrismColors.secondaryText,
                        ),
                        counterStyle: PrismTextStyles.bodySmall.copyWith(
                          color: PrismColors.secondaryText,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your message';
                        }
                        if (value.trim().length < 10) {
                          return 'Message must be at least 10 characters';
                        }
                        return null;
                      },
                      onChanged: (value) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: isSmallScreen ? 20 : 32),

            // Submit Button
            PrismButton(
              text: 'Submit Feedback',
              type: PrismButtonType.primary,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submitFeedback,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackTypeCard(Map<String, dynamic> type, double screenWidth) {
    final isSelected = _selectedFeedbackType == type['value'];
    final isCompact = screenWidth < 360;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() => _selectedFeedbackType = type['value']);
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: PrismColors.surfaceGray,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? type['color']
                  : PrismColors.white.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 8 : 10),
                decoration: BoxDecoration(
                  color: type['color'].withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  type['icon'],
                  color: type['color'],
                  size: isCompact ? 20 : 24,
                ),
              ),
              SizedBox(width: isCompact ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type['label'],
                      style: PrismTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isCompact ? 15 : 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type['description'],
                      style: PrismTextStyles.bodySmall.copyWith(
                        color: PrismColors.secondaryText,
                        fontSize: isCompact ? 12 : 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: type['color'],
                  size: isCompact ? 20 : 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
