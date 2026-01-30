import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/security/app_lock_service.dart';
import '../../../core/settings/calendar_mode.dart';
import '../screens/change_pin_screen.dart';

class CustomerSettingsTab extends StatefulWidget {
  const CustomerSettingsTab({super.key});

  @override
  State<CustomerSettingsTab> createState() => _CustomerSettingsTabState();
}

class _CustomerSettingsTabState extends State<CustomerSettingsTab> {
  final _lock = AppLockService();
  bool? _bioEnabled;
  bool _savingBio = false;
  String? _bioError;

  CalendarModeService? _calendarService;
  CalendarMode _calendarMode = CalendarMode.gregorian;

  @override
  void initState() {
    super.initState();
    _loadBio();
    _loadCalendarMode();
  }

  Future<void> _loadBio() async {
    try {
      final v = await _lock.biometricEnabled();
      if (!mounted) return;
      setState(() => _bioEnabled = v);
    } catch (e) {
      if (!mounted) return;
      setState(() => _bioError = e.toString());
    }
  }

  Future<void> _setBio(bool v) async {
    setState(() {
      _savingBio = true;
      _bioError = null;
    });

    try {
      await _lock.setBiometricEnabled(v);
      if (!mounted) return;
      setState(() => _bioEnabled = v);
    } catch (e) {
      if (!mounted) return;
      setState(() => _bioError = e.toString());
    } finally {
      if (mounted) setState(() => _savingBio = false);
    }
  }

  Future<void> _loadCalendarMode() async {
    final service = await CalendarModeService.getInstance();
    if (!mounted) return;
    setState(() {
      _calendarService = service;
      _calendarMode = service.getMode();
    });
  }

  Future<void> _setCalendarMode(CalendarMode mode) async {
    await _calendarService?.setMode(mode);
    if (!mounted) return;
    setState(() => _calendarMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biometric unlock'),
                  subtitle: const Text('Use fingerprint/biometrics to unlock'),
                  value: _bioEnabled ?? true,
                  onChanged: (_bioEnabled == null || _savingBio)
                      ? null
                      : _setBio,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.password),
                  title: const Text('Change PIN'),
                  subtitle: const Text('Update your 4-digit app PIN'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChangePinScreen()),
                  ),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () => FirebaseAuth.instance.signOut(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Calendar Mode Card
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Calendar',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SegmentedButton<CalendarMode>(
                    segments: const [
                      ButtonSegment(
                        value: CalendarMode.gregorian,
                        label: Text('Gregorian'),
                        icon: Icon(Icons.calendar_today),
                      ),
                      ButtonSegment(
                        value: CalendarMode.ethiopian,
                        label: Text('Ethiopian'),
                        icon: Icon(Icons.calendar_month),
                      ),
                    ],
                    selected: {_calendarMode},
                    onSelectionChanged: (Set<CalendarMode> selected) {
                      _setCalendarMode(selected.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_bioError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _bioError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}
