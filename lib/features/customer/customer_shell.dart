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
      backgroundColor: const Color(0xFFFEFBFF),
      body: SafeArea(
        child: Column(
          children: [
            const SyncStatusBanner(),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF8B5CF6).withOpacity(0.15),
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: Color(0xFF8B5CF6)),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF8B5CF6)),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings, color: Color(0xFF8B5CF6)),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
