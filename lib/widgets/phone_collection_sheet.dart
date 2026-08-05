import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/utils/phone_parser.dart';
import 'package:prism/widgets/prism_button.dart';

enum PhoneCollectionMode { confirm, enter }

enum PhoneCollectionResultType { confirmed, saved, skipped }

class PhoneCollectionResult {
  final PhoneCollectionResultType type;
  final String? countryCode;
  final String? phoneNumber;

  const PhoneCollectionResult._({
    required this.type,
    this.countryCode,
    this.phoneNumber,
  });

  factory PhoneCollectionResult.confirmed({
    required String countryCode,
    required String phoneNumber,
  }) => PhoneCollectionResult._(
    type: PhoneCollectionResultType.confirmed,
    countryCode: countryCode,
    phoneNumber: phoneNumber,
  );

  factory PhoneCollectionResult.saved({
    required String countryCode,
    required String phoneNumber,
  }) => PhoneCollectionResult._(
    type: PhoneCollectionResultType.saved,
    countryCode: countryCode,
    phoneNumber: phoneNumber,
  );

  factory PhoneCollectionResult.skipped() => const PhoneCollectionResult._(
    type: PhoneCollectionResultType.skipped,
  );

  bool get didProvidePhone =>
      type == PhoneCollectionResultType.confirmed ||
      type == PhoneCollectionResultType.saved;
}

/// Shows the phone collection bottom sheet.
///
/// Returns [PhoneCollectionResult], or `null` when the sheet is dismissed
/// without an explicit action (treated as skipped by callers).
Future<PhoneCollectionResult?> showPhoneCollectionSheet({
  required BuildContext context,
  PhoneCollectionMode initialMode = PhoneCollectionMode.enter,
  String? initialCountryCode,
  String? initialPhoneNumber,
  bool allowSkip = true,
  String? title,
  String? subtitle,
  String? primaryLabel,
}) {
  return showModalBottomSheet<PhoneCollectionResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PrismColors.darkCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => PhoneCollectionSheet(
      initialMode: initialMode,
      initialCountryCode: initialCountryCode,
      initialPhoneNumber: initialPhoneNumber,
      allowSkip: allowSkip,
      title: title,
      subtitle: subtitle,
      primaryLabel: primaryLabel,
    ),
  );
}

class PhoneCollectionSheet extends StatefulWidget {
  final PhoneCollectionMode initialMode;
  final String? initialCountryCode;
  final String? initialPhoneNumber;
  final bool allowSkip;
  final String? title;
  final String? subtitle;
  final String? primaryLabel;

  const PhoneCollectionSheet({
    super.key,
    this.initialMode = PhoneCollectionMode.enter,
    this.initialCountryCode,
    this.initialPhoneNumber,
    this.allowSkip = true,
    this.title,
    this.subtitle,
    this.primaryLabel,
  });

  @override
  State<PhoneCollectionSheet> createState() => _PhoneCollectionSheetState();
}

class _PhoneCollectionSheetState extends State<PhoneCollectionSheet> {
  late PhoneCollectionMode _mode;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _phoneCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final code =
        (widget.initialCountryCode ?? PhoneParser.defaultCountryCode)
            .replaceAll(RegExp(r'[^\d]'), '');
    final phone = PhoneParser.normalizeLocalNumber(
      code.isEmpty ? PhoneParser.defaultCountryCode : code,
      widget.initialPhoneNumber ?? '',
    );
    _mode = widget.initialMode == PhoneCollectionMode.confirm &&
            PhoneParser.isValidLocalNumber(phone) &&
            code.isNotEmpty
        ? PhoneCollectionMode.confirm
        : PhoneCollectionMode.enter;
    _codeCtrl = TextEditingController(
      text: code.isEmpty ? PhoneParser.defaultCountryCode : code,
    );
    _phoneCtrl = TextEditingController(text: phone);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String get _normalizedCode => _codeCtrl.text.replaceAll('+', '').trim();

  String get _normalizedPhone => PhoneParser.normalizeLocalNumber(
        _normalizedCode,
        _phoneCtrl.text,
      );

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
    );
  }

  void _popSkipped() {
    Navigator.pop(context, PhoneCollectionResult.skipped());
  }

  void _popConfirmed() {
    Navigator.pop(
      context,
      PhoneCollectionResult.confirmed(
        countryCode: _normalizedCode,
        phoneNumber: _normalizedPhone,
      ),
    );
  }

  void _popSaved() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      PhoneCollectionResult.saved(
        countryCode: _normalizedCode,
        phoneNumber: _normalizedPhone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _mode == PhoneCollectionMode.confirm
          ? _buildConfirm()
          : _buildEnter(),
    );
  }

  Widget _buildConfirm() {
    final display = '+$_normalizedCode $_normalizedPhone';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title ?? 'Find friends already on Prism',
          style: PrismTextStyles.h3,
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle ??
              'We use your number only to match people in your contacts. '
                  'It is not used for login.',
          style: PrismTextStyles.bodySmall.copyWith(
            color: PrismColors.secondaryText,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Is this your number?',
                style: PrismTextStyles.bodySmall.copyWith(
                  color: PrismColors.secondaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(display, style: PrismTextStyles.h3),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrismButton(
          text: widget.primaryLabel ?? 'Yes, find my friends',
          onPressed: _popConfirmed,
        ),
        const SizedBox(height: 10),
        PrismButton(
          text: 'Edit',
          type: PrismButtonType.secondary,
          onPressed: () => setState(() => _mode = PhoneCollectionMode.enter),
        ),
        if (widget.allowSkip) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: _popSkipped,
            child: Text(
              'Not now',
              style: PrismTextStyles.button.copyWith(
                color: PrismColors.secondaryText,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEnter() {
    final isSettingsStyle = !widget.allowSkip;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title ??
                (isSettingsStyle
                    ? 'Update Phone Number'
                    : 'Add your phone number'),
            style: PrismTextStyles.h3,
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle ??
                (isSettingsStyle
                    ? 'Used for contact-based friend discovery.'
                    : 'We use your number only to match people in your contacts. '
                          'It is not used for login.'),
            style: PrismTextStyles.bodySmall.copyWith(
              color: PrismColors.secondaryText,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: TextFormField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  style: PrismTextStyles.bodyLarge,
                  decoration: _fieldDecoration('Code'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (int.tryParse(v.replaceAll('+', '')) == null) {
                      return 'Digits';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: PrismTextStyles.bodyLarge,
                  decoration: _fieldDecoration('Phone Number'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                    if (!PhoneParser.isValidLocalNumber(digits)) {
                      if (digits.length < 7) return 'Too short';
                      return 'Invalid number';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          PrismButton(
            text: widget.primaryLabel ??
                (isSettingsStyle ? 'Save' : 'Save and continue'),
            onPressed: _popSaved,
          ),
          if (widget.allowSkip) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: _popSkipped,
              child: Text(
                'Not now',
                style: PrismTextStyles.button.copyWith(
                  color: PrismColors.secondaryText,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: PrismTextStyles.button.copyWith(
                  color: PrismColors.secondaryText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
