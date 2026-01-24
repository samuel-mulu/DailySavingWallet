import 'package:flutter/material.dart';

import '../../core/security/app_lock_service.dart';
import '../customer/customer_shell.dart';
import 'set_pin_screen.dart';
import 'unlock_screen.dart';

class AppLockGate extends StatefulWidget {
  final String uid;
  const AppLockGate({super.key, required this.uid});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  bool _unlocked = false;

  void _setUnlocked() => setState(() => _unlocked = true);

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return const CustomerShell();

    return FutureBuilder<bool>(
      future: AppLockService().isPinSet(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(body: Center(child: Text(snap.error.toString())));
        }

        final hasPin = snap.data ?? false;
        return hasPin
            ? UnlockScreen(uid: widget.uid, onUnlocked: _setUnlocked)
            : SetPinScreen(uid: widget.uid, onPinSet: _setUnlocked);
      },
    );
  }
}
