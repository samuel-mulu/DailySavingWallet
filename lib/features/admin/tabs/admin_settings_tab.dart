import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/settings/calendar_mode.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  CalendarModeService? _calendarService;
  @override
  void initState() {
    super.initState();
    _loadCalendarMode();
  }

  Future<void> _loadCalendarMode() async {
    final service = await CalendarModeService.getInstance();
    if (!mounted) return;
    setState(() {
      _calendarService = service;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_calendarService == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return ValueListenableBuilder<CalendarMode>(
      valueListenable: _calendarService!,
      builder: (context, mode, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Calendar Mode Card
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Calendar',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
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
                        selected: {mode},
                        onSelectionChanged: (Set<CalendarMode> selected) {
                          _calendarService?.setMode(selected.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Logout Card
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () => FirebaseAuth.instance.signOut(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
