import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/sync_status_banner.dart';
import '../customers/admin_customer_ids_notifier.dart';
import '../customers/customer_list_notifier.dart';
import '../wallet/wallet_providers.dart';
import '../withdrawals/pending_withdrawals_provider.dart';
import 'admin_tab.dart';
import 'customers/customer_list_screen.dart';
import 'tabs/admin_approvals_tab.dart';
import 'tabs/admin_daily_check_tab.dart';
import 'tabs/admin_home_tab.dart';
import 'tabs/admin_reports_tab.dart';
import 'tabs/admin_settings_tab.dart';

class AdminShell extends ConsumerStatefulWidget {
  final AdminTab initialTab;

  const AdminShell({super.key, this.initialTab = AdminTab.daily});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  late int _index;
  DateTime _dailyBadgeDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab.index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminCustomerIdsStaleProvider.notifier).ensureFresh(force: false);
      ref.read(pendingWithdrawalsStaleProvider.notifier).ensureFresh(force: false);
    });
  }

  String _txDay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final txDay = _txDay(_dailyBadgeDate);
    ref.watch(recordedDailyWalletIdsProvider(txDay));
    final pendingSummary = ref.watch(dailyPendingSummaryProvider(txDay));
    final pendingItems =
        ref.watch(pendingWithdrawalsStaleProvider).data ?? const [];

    final pendingDailyCount =
        pendingSummary.valueOrNull?.pendingCustomerCount ?? 0;
    final pendingApprovalCount = pendingItems.length;

    final Widget body = switch (_index) {
      0 => AdminDailyCheckTab(
        selectedDate: _dailyBadgeDate,
        onSelectedDateChanged: (date) => setState(() => _dailyBadgeDate = date),
      ),
      1 => const CustomerListScreen(),
      2 => AdminHomeTab(
        onNavigateToTab: (tab) => setState(() => _index = tab.index),
      ),
      3 => const AdminApprovalsTab(),
      _ => const AdminReportsTab(),
    };

    final title = switch (_index) {
      0 => 'Daily',
      1 => 'Customers',
      2 => 'Dashboard',
      3 => 'Approvals',
      _ => 'Reports',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFFEFBFF),
      body: SafeArea(
        child: Column(
          children: [
            const SyncStatusBanner(),
            Material(
              color: Colors.white,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Reports',
                      icon: const Icon(Icons.assessment_outlined),
                      onPressed: () => setState(() => _index = 4),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const AdminSettingsTab(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
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
          onDestinationSelected: (i) {
            setState(() => _index = i);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (i == 0) {
                ref
                    .read(recordedDailyWalletIdsProvider(txDay).notifier)
                    .refresh(force: true);
                ref.invalidate(dailyPendingSummaryProvider(txDay));
                ref
                    .read(adminCustomerIdsStaleProvider.notifier)
                    .refresh(force: true);
              }
              if (i == 1) {
                ref.read(customerListNotifierProvider.notifier).refresh();
              }
              if (i == 2) {
                ref
                    .read(adminCustomerIdsStaleProvider.notifier)
                    .refresh(force: true);
                ref.read(customerListNotifierProvider.notifier).refresh();
              }
              if (i == 3) {
                ref
                    .read(pendingWithdrawalsStaleProvider.notifier)
                    .refresh(force: true);
              }
            });
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: _buildBadgeIcon(
                count: pendingDailyCount,
                child: const Icon(Icons.add_circle_outline),
              ),
              selectedIcon: _buildBadgeIcon(
                count: pendingDailyCount,
                child: const Icon(
                  Icons.add_circle,
                  color: Color(0xFF8B5CF6),
                ),
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
              icon: _buildBadgeIcon(
                count: pendingApprovalCount,
                child: const Icon(Icons.approval_outlined),
              ),
              selectedIcon: _buildBadgeIcon(
                count: pendingApprovalCount,
                child: const Icon(Icons.approval, color: Color(0xFF8B5CF6)),
              ),
              label: 'Approvals',
            ),
            const NavigationDestination(
              icon: Icon(Icons.assessment_outlined),
              selectedIcon: Icon(Icons.assessment, color: Color(0xFF8B5CF6)),
              label: 'Reports',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeIcon({
    required int count,
    required Widget child,
  }) {
    return Badge(
      label: Text(count.toString()),
      isLabelVisible: count > 0,
      child: child,
    );
  }
}
