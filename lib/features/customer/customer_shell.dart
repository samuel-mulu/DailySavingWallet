import 'package:flutter/material.dart';

import '../../core/ui/sync_status_banner.dart';
import 'tabs/customer_history_tab.dart';
import 'tabs/customer_home_tab.dart';
import 'tabs/customer_settings_tab.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Important for Firestore cost: build only the active tab so streams stop
    // when the tab is not visible.
    final Widget body = switch (_index) {
      0 => const CustomerHomeTab(),
      1 => const CustomerHistoryTab(),
      _ => const CustomerSettingsTab(),
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
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

