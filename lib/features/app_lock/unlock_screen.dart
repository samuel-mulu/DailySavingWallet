import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/security/app_lock_service.dart';

class UnlockScreen extends StatefulWidget {
  final String uid;
  final VoidCallback onUnlocked;
  const UnlockScreen({super.key, required this.uid, required this.onUnlocked});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _auth = LocalAuthentication();
  final _pinCtrl = TextEditingController();
  final _lock = AppLockService();

  bool _busy = false;
  String? _error;

  int _failCount = 0;
  DateTime? _lockedUntil;

  @override
  void initState() {
    super.initState();
    _tryBiometric();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  bool get _isTempLocked {
    final until = _lockedUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  Future<void> _tryBiometric() async {
    try {
      // Biometrics are not supported on Flutter Web in this flow
      if (kIsWeb) return;

      final bioEnabled = await _lock.biometricEnabled();
      if (!bioEnabled) return;

      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!isSupported || !canCheck) return;

      final ok = await _auth.authenticate(
        localizedReason: 'Unlock to access your wallet',
      );

      if (ok && mounted) _unlock();
    } catch (_) {
      // Biometric failed -> user can still unlock with PIN
    }
  }

  void _unlock() {
    widget.onUnlocked();
  }

  Future<void> _verifyPin() async {
    if (_isTempLocked) {
      setState(() => _error = 'Too many attempts. Try again later.');
      return;
    }

    final pin = _pinCtrl.text.trim();
    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _error = 'Enter a valid 4-digit PIN.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await _lock.verifyPin(pin);

    if (!mounted) return;

    if (ok) {
      _unlock();
      return;
    }

    _failCount += 1;
    _pinCtrl.clear();

    if (_failCount >= 5) {
      _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
      _failCount = 0;
      setState(() {
        _busy = false;
        _error = 'Too many attempts. Locked for 30 seconds.';
      });
      return;
    }

    setState(() {
      _busy = false;
      _error = 'Incorrect PIN. Try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final lockMsg = _isTempLocked ? 'Locked… wait a moment' : 'Enter PIN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock'),
        actions: [
          if (!kIsWeb)
            IconButton(
              tooltip: 'Use fingerprint',
              onPressed: _busy ? null : _tryBiometric,
              icon: const Icon(Icons.fingerprint),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(lockMsg),
            const SizedBox(height: 12),
            TextField(
              controller: _pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(labelText: 'PIN'),
              onSubmitted: (_) => _verifyPin(),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _verifyPin,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Unlock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
