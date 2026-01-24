import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/ui/sync_status_banner.dart';
import 'tabs/admin_approvals_tab.dart';
import 'tabs/admin_daily_check_tab.dart';
import 'tabs/admin_home_tab.dart';
import 'tabs/admin_settings_tab.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_index) {
      0 => const AdminHomeTab(),
      1 => const AdminDailyCheckTab(),
      2 => const AdminApprovalsTab(),
      _ => const AdminSettingsTab(),
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SyncStatusBanner(),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), label: 'Daily Check'),
          NavigationDestination(icon: Icon(Icons.approval_outlined), label: 'Approvals'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

// Small helper for tab code that needs the current uid.
String currentUidOrEmpty() => FirebaseAuth.instance.currentUser?.uid ?? '';

