import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable numeric keypad for PIN entry
class NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onNumberPressed;
  final VoidCallback onDeletePressed;
  final bool showBiometric;
  final VoidCallback? onBiometricPressed;

  const NumericKeypad({
    super.key,
    required this.onNumberPressed,
    required this.onDeletePressed,
    this.showBiometric = false,
    this.onBiometricPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: 1, 2, 3
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 12),
        
        // Row 2: 4, 5, 6
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 12),
        
        // Row 3: 7, 8, 9
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 12),
        
        // Row 4: biometric (optional), 0, delete
        _buildBottomRow(),
      ],
    );
  }

  Widget _buildRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: numbers.map((number) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _NumberButton(
            number: number,
            onPressed: () {
              HapticFeedback.mediumImpact();
              onNumberPressed(number);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left slot: Biometric or empty
        SizedBox(
          width: 64,
          height: 64,
          child: showBiometric && onBiometricPressed != null
              ? _ActionButton(
                  icon: Icons.fingerprint,
                  onPressed: onBiometricPressed!,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 12),
        
        // Center: 0
        _NumberButton(
          number: '0',
          onPressed: () {
            HapticFeedback.mediumImpact();
            onNumberPressed('0');
          },
        ),
        const SizedBox(width: 12),
        
        // Right: Delete
        _ActionButton(
          icon: Icons.backspace_outlined,
          onPressed: () {
            HapticFeedback.lightImpact();
            onDeletePressed();
          },
        ),
      ],
    );
  }
}

class _NumberButton extends StatelessWidget {
  final String number;
  final VoidCallback onPressed;

  const _NumberButton({
    required this.number,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        splashColor: const Color(0xFF8B5CF6).withOpacity(0.2),
        highlightColor: const Color(0xFF8B5CF6).withOpacity(0.1),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFE5E5E5),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D2D2D),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        splashColor: const Color(0xFF8B5CF6).withOpacity(0.2),
        highlightColor: const Color(0xFF8B5CF6).withOpacity(0.1),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFE5E5E5),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 28,
              color: const Color(0xFF8B5CF6),
            ),
          ),
        ),
      ),
    );
  }
}
