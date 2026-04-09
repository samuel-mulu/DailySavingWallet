import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/routes.dart';
import '../../core/money/money.dart';
import '../../data/wallet/models.dart';
import '../../data/wallet/wallet_repo.dart';
import '../../data/users/user_model.dart';
import '../auth/providers/auth_providers.dart';
import '../wallet/withdraw_request_screen.dart';
import '../wallet/widgets/balance_card.dart';
import '../wallet/wallet_providers.dart';

class CustomerDashboard extends ConsumerStatefulWidget {
  const CustomerDashboard({super.key});

  @override
  ConsumerState<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends ConsumerState<CustomerDashboard> {
  final _repo = WalletRepo();
  final _scroll = ScrollController();

  final List<LedgerTx> _ledger = [];
  Object? _lastDoc;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _ledgerError;
  String? _activeCustomerId;
  String? _lastLoadedCustomerId;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadFirstPage(String customerId) async {
    setState(() {
      _loading = true;
      _ledgerError = null;
      _ledger.clear();
      _lastDoc = null;
      _hasMore = true;
      _activeCustomerId = customerId;
      _lastLoadedCustomerId = customerId;
    });

    try {
      final page = await _repo.fetchLedgerPage(customerId);
      if (!mounted) return;
      setState(() {
        _ledger.addAll(page.items);
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _ledgerError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final customerId = _activeCustomerId;
    if (customerId == null) return;
    final startAfter = _lastDoc;
    if (startAfter == null) return;

    setState(() => _loadingMore = true);
    try {
      final page = await _repo.fetchLedgerPage(
        customerId,
        startAfter: startAfter,
      );
      if (!mounted) return;
      setState(() {
        _ledger.addAll(page.items);
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _ledgerError ??= e.toString());
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authUidProvider).valueOrNull;
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profileAsync = ref.watch(appUserProfileProvider(uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authClientProvider).signOut();
              if (context.mounted) {
                AppRoutes.goToAuthGate(context);
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (AppUser profile) {
          final customerId = profile.customerId;
          if (customerId == null || customerId.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Your customer profile is not linked. Contact support.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (_lastLoadedCustomerId != customerId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                unawaited(_loadFirstPage(customerId));
              }
            });
          }

          final stale = ref.watch(
            walletStaleProvider((customerId: customerId, walletId: null)),
          );
          final bal = stale.data?.balanceCents ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(
                    walletStaleProvider((
                      customerId: customerId,
                      walletId: null,
                    )).notifier,
                  )
                  .refresh(force: true);
              await _loadFirstPage(customerId);
            },
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              children: [
                BalanceCard(
                  balanceCents: bal,
                  updatedAt: stale.data?.updatedAt,
                  onSync: () => ref
                      .read(
                        walletStaleProvider((
                          customerId: customerId,
                          walletId: null,
                        )).notifier,
                      )
                      .refresh(force: true),
                  isSyncing: stale.isRefreshing,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const WithdrawRequestScreen(),
                        ),
                      );
                      if (!mounted) return;
                      await ref
                          .read(
                            walletStaleProvider((
                              customerId: customerId,
                              walletId: null,
                            )).notifier,
                          )
                          .refresh(force: true);
                      await _loadFirstPage(customerId);
                    },
                    icon: const Icon(Icons.request_page),
                    label: const Text('Request Withdraw'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (_ledgerError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _ledgerError.toString(),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ..._ledger.map((tx) {
                  final sign = tx.direction == 'OUT' ? '-' : '+';
                  final amount = '$sign${MoneyEtb.formatCents(tx.amountCents)}';
                  final when = tx.createdAt == null
                      ? ''
                      : '${tx.createdAt!.year.toString().padLeft(4, '0')}-${tx.createdAt!.month.toString().padLeft(2, '0')}-${tx.createdAt!.day.toString().padLeft(2, '0')}';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tx.type),
                    subtitle: when.isEmpty ? null : Text(when),
                    trailing: Text(amount),
                  );
                }),
                if (_loadingMore)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (!_loading && _ledger.isEmpty && _ledgerError == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No transactions yet.')),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
