import 'package:flutter/material.dart';

import '../../core/security/app_lock_service.dart';
import '../../core/ui/branded_header.dart';
import '../../core/ui/pin_input_widget.dart';

class SetPinScreen extends StatefulWidget {
  final String uid;
  final VoidCallback onPinSet;
  const SetPinScreen({super.key, required this.uid, required this.onPinSet});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final _pinController1 = PinInputWidgetController();
  final _pinController2 = PinInputWidgetController();
  
  String? _firstPin;
  String? _error;
  bool _saving = false;
  bool _isConfirmStep = false;

  Future<void> _onFirstPinComplete(String pin) async {
    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _error = 'PIN must be 4 digits.');
      _pinController1.clearPin();
      return;
    }

    setState(() {
      _firstPin = pin;
      _isConfirmStep = true;
      _error = null;
    });
  }

  Future<void> _onConfirmPinComplete(String pin) async {
    if (pin != _firstPin) {
      setState(() => _error = 'PIN does not match. Try again.');
      _pinController2.clearPin();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    await AppLockService().setPin(pin, enableBiometric: true);

    if (!mounted) return;
    widget.onPinSet();
  }

  void _goBack() {
    setState(() {
      _isConfirmStep = false;
      _firstPin = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back button on confirm step
                    if (_isConfirmStep) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: _goBack,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 20),
                    
                    // Purple Branding Header
                    const BrandedHeader(
                      title: 'Daily Saving',
                      height: 150,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Heading
                    Text(
                      _isConfirmStep ? 'Confirm Your PIN' : 'Create Your PIN',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isConfirmStep
                          ? 'Enter the same PIN again'
                          : 'Choose a 4-digit PIN to secure your wallet',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // PIN Input Widget with Keypad
                    if (_saving)
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF8B5CF6),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Setting up your PIN...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_isConfirmStep)
                      PinInputWidget(
                        controller: _pinController2,
                        onPinComplete: _onConfirmPinComplete,
                        errorMessage: _error,
                      )
                    else
                      PinInputWidget(
                        controller: _pinController1,
                        onPinComplete: _onFirstPinComplete,
                        errorMessage: _error,
                      ),
                    
                    const SizedBox(height: 40),
                    
                    // Security Info
                    if (!_isConfirmStep && !_saving)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.security,
                              color: Color(0xFF8B5CF6),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your PIN is stored securely on your device and never sent to our servers.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
