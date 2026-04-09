import 'package:flutter/material.dart';

import '../../../core/security/app_lock_service.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _oldCtrl = TextEditingController();
  final _new1Ctrl = TextEditingController();
  final _new2Ctrl = TextEditingController();
  final _lock = AppLockService();

  bool _busy = false;
  String? _error;
  bool _verifiedOld = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _new1Ctrl.dispose();
    _new2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _verifyOld() async {
    final oldPin = _oldCtrl.text.trim();
    if (oldPin.length != 4 || int.tryParse(oldPin) == null) {
      setState(() => _error = 'Enter your current 4-digit PIN.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ok = await _lock.verifyPin(oldPin);
      if (!mounted) return;
      if (!ok) {
        setState(() => _error = 'Incorrect PIN.');
        return;
      }
      setState(() => _verifiedOld = true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveNew() async {
    final p1 = _new1Ctrl.text.trim();
    final p2 = _new2Ctrl.text.trim();

    if (p1.length != 4 || int.tryParse(p1) == null) {
      setState(() => _error = 'New PIN must be 4 digits.');
      return;
    }
    if (p1 != p2) {
      setState(() => _error = 'New PIN does not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final keepBio = await _lock.biometricEnabled();
      await _lock.setPin(p1, enableBiometric: keepBio);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change PIN')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_verifiedOld) ...[
              const Text('Verify your current PIN to continue.'),
              const SizedBox(height: 12),
              TextField(
                controller: _oldCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'Current PIN'),
                onSubmitted: (_) => _busy ? null : _verifyOld(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _verifyOld,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ),
            ] else ...[
              const Text('Enter a new 4-digit PIN.'),
              const SizedBox(height: 12),
              TextField(
                controller: _new1Ctrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'New PIN'),
              ),
              TextField(
                controller: _new2Ctrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'Confirm new PIN'),
                onSubmitted: (_) => _busy ? null : _saveNew(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _saveNew,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

