import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/security/app_lock_service.dart';
import '../../core/ui/app_brand.dart';
import '../../core/ui/branded_header.dart';
import '../../core/ui/pin_input_widget.dart';

class UnlockScreen extends StatefulWidget {
  final String uid;
  final VoidCallback onUnlocked;

  const UnlockScreen({super.key, required this.uid, required this.onUnlocked});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _auth = LocalAuthentication();
  final _lock = AppLockService();
  final _pinController = PinInputWidgetController();

  String? _error;
  int _failCount = 0;
  DateTime? _lockedUntil;

  @override
  void initState() {
    super.initState();
    _tryBiometric();
  }

  bool get _isTempLocked {
    final until = _lockedUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  Future<void> _tryBiometric() async {
    try {
      if (kIsWeb) return;

      final bioEnabled = await _lock.biometricEnabled();
      if (!bioEnabled) return;

      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!isSupported || !canCheck) return;

      final ok = await _auth.authenticate(
        localizedReason: 'Unlock to access your wallet',
      );

      if (ok && mounted) {
        _unlock();
      }
    } catch (_) {
      // Biometric errors are non-fatal; the PIN flow stays available.
    }
  }

  void _unlock() {
    widget.onUnlocked();
  }

  Future<void> _verifyPin(String pin) async {
    if (_isTempLocked) {
      setState(() => _error = 'Too many attempts. Try again later.');
      _pinController.clearPin();
      return;
    }

    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _error = 'Enter a valid 4-digit PIN.');
      _pinController.clearPin();
      return;
    }

    setState(() => _error = null);

    final ok = await _lock.verifyPin(pin);
    if (!mounted) return;

    if (ok) {
      _unlock();
      return;
    }

    _failCount += 1;
    _pinController.clearPin();

    if (_failCount >= 5) {
      _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
      _failCount = 0;
      setState(() => _error = 'Too many attempts. Locked for 30 seconds.');
      return;
    }

    setState(() {
      _error = 'Incorrect PIN. ${5 - _failCount} attempts remaining.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final lockMessage = _isTempLocked
        ? 'Locked... wait a moment'
        : 'Unlock Your Wallet';

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 20),
              const BrandedHeader(
                title: AppBrand.shortName,
                subtitle: 'Secure PIN access',
                height: 168,
              ),
              const SizedBox(height: 40),
              Text(
                lockMessage,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppBrand.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your 4-digit PIN',
                style: TextStyle(fontSize: 14, color: AppBrand.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              PinInputWidget(
                controller: _pinController,
                onPinComplete: _verifyPin,
                showBiometric: !kIsWeb,
                onBiometricPressed: _tryBiometric,
                errorMessage: _error,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
