import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/reachability_host.dart';
import '../../core/ui/sync_status_banner.dart';
import '../../data/users/user_model.dart';
import '../auth/providers/auth_providers.dart';
import '../wallet/wallet_providers.dart';
import 'tabs/customer_history_tab.dart';
import 'tabs/customer_home_tab.dart';
import 'tabs/customer_reports_tab.dart';
import 'tabs/customer_settings_tab.dart';

class CustomerShell extends ConsumerStatefulWidget {
  const CustomerShell({super.key});

  @override
  ConsumerState<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends ConsumerState<CustomerShell>
    with WidgetsBindingObserver {
  int _index = 0;
  int _historyRefreshSignal = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(ReachabilityHost.instance.probeServer());
    final uid = ref.read(authUidProvider).valueOrNull;
    if (uid == null) return;
    final profile = ref.read(appUserProfileProvider(uid));
    if (profile is! AsyncData<AppUser>) return;
    final cid = profile.value.customerId;
    if (cid == null || cid.isEmpty) return;
    ref
        .read(walletStaleProvider((customerId: cid, walletId: null)).notifier)
        .ensureFresh(force: false);
    ref
        .read(recentLedgerStaleProvider((customerId: cid, walletId: null)).notifier)
        .ensureFresh(force: false);
  }

  String get _title => switch (_index) {
        0 => 'Home',
        1 => 'History',
        _ => 'Reports',
      };

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const CustomerSettingsTab(),
      ),
    );
  }

  Future<void> _showCompanyRulesModal() {
    const ruleItems = <String>[
      'ዕቁብ ዝኽፈለሉ ግዜ ሰምናዊ ቀዳም ካብ 10፡00-12:00።',
      'ዋሕስ ኮይኑ ዝፈረመ ናይ ዝተዋሓሰ ሰብ ቀጥተኛ ከፋሊ ዝኸውን ምኻኑ ክፈልጥ አለዎ።',
      'ናይ ዕቁብተኛ መሰል ሕልው አዩ።',
      'ቅድሚያ ንዝወስድ ቸክ የዛጋጅው',
    ];

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Company Rules',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < ruleItems.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle_outline, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ruleItems[i],
                        style: Theme.of(sheetContext).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
                if (i < ruleItems.length - 1) const SizedBox(height: 10),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.check),
                  label: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTabSelected(int i) {
    setState(() {
      _index = i;
      if (i == 1) {
        _historyRefreshSignal++;
      }
    });

    final uid = ref.read(authUidProvider).valueOrNull;
    if (uid == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = ref.read(appUserProfileProvider(uid)).valueOrNull;
      final cid = profile?.customerId;
      if (cid == null || cid.isEmpty) return;

      if (i == 0) {
        await Future.wait([
          ref
              .read(walletStaleProvider((customerId: cid, walletId: null)).notifier)
              .refresh(force: true),
          ref
              .read(
                recentLedgerStaleProvider((customerId: cid, walletId: null))
                    .notifier,
              )
              .refresh(force: true),
        ]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_index) {
      0 => const CustomerHomeTab(),
      1 => CustomerHistoryTab(refreshSignal: _historyRefreshSignal),
      _ => const CustomerReportsTab(),
    };

    return Scaffold(
      backgroundColor: const Color(0xFFFEFBFF),
      body: SafeArea(
        child: Column(
          children: [
            const SyncStatusBanner(),
            Material(
              color: Colors.white,
              elevation: 0,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Reports',
                      icon: const Icon(Icons.assessment_outlined),
                      onPressed: () => _onTabSelected(2),
                    ),
                    IconButton(
                      tooltip: 'Rules',
                      icon: const Icon(Icons.policy_outlined),
                      onPressed: _showCompanyRulesModal,
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: _openSettings,
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
          onDestinationSelected: _onTabSelected,
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
              icon: Icon(Icons.assessment_outlined),
              selectedIcon: Icon(Icons.assessment, color: Color(0xFF8B5CF6)),
              label: 'Reports',
            ),
          ],
        ),
      ),
    );
  }
}
