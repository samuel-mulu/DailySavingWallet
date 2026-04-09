import 'package:flutter/material.dart';
import 'numeric_keypad.dart';

/// Complete PIN input widget with visual indicators and numeric keypad
class PinInputWidget extends StatefulWidget {
  final ValueChanged<String> onPinComplete;
  final bool showBiometric;
  final VoidCallback? onBiometricPressed;
  final String? errorMessage;
  final VoidCallback? onErrorShake;
  final PinInputWidgetController? controller;

  const PinInputWidget({
    super.key,
    required this.onPinComplete,
    this.showBiometric = false,
    this.onBiometricPressed,
    this.errorMessage,
    this.onErrorShake,
    this.controller,
  });

  @override
  State<PinInputWidget> createState() => _PinInputWidgetState();
}

class PinInputWidgetController {
  _PinInputWidgetState? _state;

  void clearPin() {
    _state?.clearPin();
  }
}

class _PinInputWidgetState extends State<PinInputWidget>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.elasticIn,
      ),
    );
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _shakeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PinInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != null && oldWidget.errorMessage == null) {
      _triggerShake();
    }
  }

  void _triggerShake() {
    _shakeController.forward(from: 0).then((_) {
      _shakeController.reverse();
    });
    widget.onErrorShake?.call();
  }

  void _onNumberPressed(String number) {
    if (_pin.length < 4) {
      setState(() {
        _pin += number;
      });
      
      if (_pin.length == 4) {
        // Auto-submit when 4 digits entered
        Future.delayed(const Duration(milliseconds: 200), () {
          widget.onPinComplete(_pin);
        });
      }
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void clearPin() {
    setState(() {
      _pin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PIN Indicators
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _PinIndicator(filled: index < _pin.length),
              );
            }),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Error Message
        if (widget.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.errorMessage!,
              style: const TextStyle(
                color: Color(0xFFC62828),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        // Numeric Keypad
        NumericKeypad(
          onNumberPressed: _onNumberPressed,
          onDeletePressed: _onDeletePressed,
          showBiometric: widget.showBiometric,
          onBiometricPressed: widget.onBiometricPressed,
        ),
      ],
    );
  }
}

class _PinIndicator extends StatelessWidget {
  final bool filled;

  const _PinIndicator({required this.filled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? const Color(0xFF8B5CF6) : Colors.transparent,
        border: Border.all(
          color: filled ? const Color(0xFF8B5CF6) : const Color(0xFFE5E5E5),
          width: 2,
        ),
      ),
    );
  }
}
