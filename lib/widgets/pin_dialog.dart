import 'package:flutter/material.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';

class PinDialog extends StatefulWidget {
  final bool isSettingPin;
  final bool Function(String) onConfirm;

  const PinDialog({
    super.key,
    required this.isSettingPin,
    required this.onConfirm,
  });

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final List<String> _pin = [];
  final int _pinLength = 4;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _message = widget.isSettingPin ? 'Set a new PIN' : 'Enter your PIN';
  }

  void _handleKeyPress(String key) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin.add(key);
      });
      if (_pin.length == _pinLength) {
        _submitPin();
      }
    }
  }

  void _handleBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin.removeLast();
      });
    }
  }

  void _submitPin() {
    final pinStr = _pin.join();
    if (widget.isSettingPin) {
      // In a real app we might ask for confirmation (enter twice)
      // For now, simple set
      final success = widget.onConfirm(pinStr);
      if (success) {
        Navigator.pop(context, true);
      }
    } else {
      final success = widget.onConfirm(pinStr);
      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _message = 'Incorrect PIN. Try again.';
          _pin.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PrismColors.glassDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isSettingPin ? 'Setup Security' : 'Locked',
              style: PrismTextStyles.h2,
            ),
            const SizedBox(height: 16),
            Text(
              _message,
              style: PrismTextStyles.bodyMedium.copyWith(
                color: _message.startsWith('Incorrect')
                    ? PrismColors.destructiveRed
                    : PrismColors.secondaryText,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pinLength,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pin.length
                        ? PrismColors.prismYellow
                        : PrismColors.surfaceGray,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildNumberPad(),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: PrismTextStyles.button.copyWith(color: Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_numBtn('1'), _numBtn('2'), _numBtn('3')],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_numBtn('4'), _numBtn('5'), _numBtn('6')],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_numBtn('7'), _numBtn('8'), _numBtn('9')],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 60), // Spacer
            _numBtn('0'),
            IconButton(
              onPressed: _handleBackspace,
              icon: const Icon(
                Icons.backspace_rounded,
                color: PrismColors.secondaryText,
              ),
              iconSize: 24,
            ),
          ],
        ),
      ],
    );
  }

  Widget _numBtn(String num) {
    return GestureDetector(
      onTap: () => _handleKeyPress(num),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: PrismColors.surfaceGray.withOpacity(0.5),
        ),
        child: Center(child: Text(num, style: PrismTextStyles.h2)),
      ),
    );
  }
}
