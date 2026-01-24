import 'package:flutter/material.dart';

import '../../core/security/app_lock_service.dart';

class SetPinScreen extends StatefulWidget {
  final String uid;
  final VoidCallback onPinSet;
  const SetPinScreen({super.key, required this.uid, required this.onPinSet});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p1 = _pin1.text.trim();
    final p2 = _pin2.text.trim();

    if (p1.length != 4 || int.tryParse(p1) == null) {
      setState(() => _error = 'PIN must be 4 digits.');
      return;
    }
    if (p1 != p2) {
      setState(() => _error = 'PIN does not match.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    await AppLockService().setPin(p1, enableBiometric: true);

    if (!mounted) return;
    widget.onPinSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set PIN')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Create a 4-digit PIN to unlock the app offline.'),
            const SizedBox(height: 12),
            TextField(
              controller: _pin1,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(labelText: 'PIN'),
            ),
            TextField(
              controller: _pin2,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(labelText: 'Confirm PIN'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save PIN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
