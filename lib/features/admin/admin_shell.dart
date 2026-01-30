import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/ui/sync_status_banner.dart';
import '../../data/wallet/wallet_repo.dart';
import 'customers/customer_list_screen.dart';
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
      0 => const AdminDailyCheckTab(),
      1 => const CustomerListScreen(),
      2 => const AdminHomeTab(),
      3 => const AdminApprovalsTab(),
      _ => const AdminSettingsTab(),
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
      bottomNavigationBar: StreamBuilder<int>(
        stream: WalletRepo().streamPendingWithdrawCount(),
        builder: (context, countSnap) {
          final pendingCount = countSnap.data ?? 0;

          return Container(
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
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(
                    Icons.add_circle,
                    color: Color(0xFF8B5CF6),
                  ),
                  label: 'Daily',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people, color: Color(0xFF8B5CF6)),
                  label: 'Customers',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard, color: Color(0xFF8B5CF6)),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Badge(
                    label: Text(pendingCount.toString()),
                    isLabelVisible: pendingCount > 0,
                    child: const Icon(Icons.approval_outlined),
                  ),
                  selectedIcon: Badge(
                    label: Text(pendingCount.toString()),
                    isLabelVisible: pendingCount > 0,
                    child: const Icon(Icons.approval, color: Color(0xFF8B5CF6)),
                  ),
                  label: 'Approvals',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings, color: Color(0xFF8B5CF6)),
                  label: 'Settings',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Small helper for tab code that needs the current uid.
String currentUidOrEmpty() => FirebaseAuth.instance.currentUser?.uid ?? '';
