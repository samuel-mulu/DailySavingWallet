import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/routing/routes.dart';
import '../../../core/ui/app_header.dart';
import '../../../data/api/wallet_api.dart';
import '../../../data/customers/customer_model.dart';
import '../../../data/customers/customer_repo.dart';
import '../../../data/wallet/models.dart';
import '../../../data/wallet/wallet_repo.dart';
import '../../auth/providers/auth_providers.dart';
import '../../customers/admin_customer_ids_notifier.dart';
import '../../customers/customer_list_notifier.dart';
import '../admin_tab.dart';
import '../customers/customer_detail_screen.dart';
import '../customers/widgets/customer_profile_avatar.dart';

class AdminHomeTab extends ConsumerStatefulWidget {
  final ValueChanged<AdminTab>? onNavigateToTab;
  final WalletRepo? walletRepo;
  final CustomerRepo? customerRepo;
  final Future<int> Function()? loadPendingWithdrawCount;
  final Future<int> Function()? loadCustomerCount;
  final Future<int> Function()? loadTotalSaving;
  final Future<int> Function()? loadTotalCredit;

  /// When set (e.g. tests), overrides [WalletRepo.fetchWalletTotals].
  final Future<WalletTotals> Function()? loadWalletTotals;

  const AdminHomeTab({
    super.key,
    this.onNavigateToTab,
    this.walletRepo,
    this.customerRepo,
    this.loadPendingWithdrawCount,
    this.loadCustomerCount,
    this.loadTotalSaving,
    this.loadTotalCredit,
    this.loadWalletTotals,
  });

  @override
  ConsumerState<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends ConsumerState<AdminHomeTab> {
  WalletRepo? _walletRepo;
  CustomerRepo? _customerRepo;
  late Future<WalletTotals> _walletTotalsFuture;
  late Future<List<Customer>> _customersWithSavingFuture;
  late Future<List<Customer>> _customersWithCreditFuture;
  late Future<List<Customer>> _customersWithFlatFuture;
  bool _logoutLoading = false;

  Future<void> _logout() async {
    if (_logoutLoading) return;
    setState(() => _logoutLoading = true);
    try {
      await ref.read(authClientProvider).signOut();
      if (mounted) {
        AppRoutes.goToAuthGate(context);
      }
    } finally {
      if (mounted) setState(() => _logoutLoading = false);
    }
  }

  Future<WalletTotals> _resolveWalletTotals() async {
    if (widget.loadWalletTotals != null) {
      return widget.loadWalletTotals!();
    }
    if (_walletRepo != null) {
      return _walletRepo!.fetchWalletTotals();
    }
    final saving = await (widget.loadTotalSaving?.call() ?? Future.value(0));
    final credit = await (widget.loadTotalCredit?.call() ?? Future.value(0));
    return WalletTotals(
      totalSavingCents: saving,
      totalCreditCents: credit,
      companyWalletBalanceCents: 0,
      companyFeeRevenueCents: 0,
    );
  }

  @override
  void initState() {
    super.initState();
    _customerRepo = widget.customerRepo ?? CustomerRepo();
    if (widget.loadPendingWithdrawCount == null ||
        widget.loadTotalSaving == null ||
        widget.loadTotalCredit == null) {
      _walletRepo = widget.walletRepo ?? WalletRepo();
    }
    _walletTotalsFuture = _resolveWalletTotals();
    _customersWithSavingFuture = _loadCustomersWithPositiveSaving();
    _customersWithCreditFuture = _loadCustomersWithCredit();
    _customersWithFlatFuture = _loadCustomersWithFlatBalance();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.loadCustomerCount == null) {
        ref.read(customerListNotifierProvider.notifier).loadInitial();
        ref
            .read(adminCustomerIdsStaleProvider.notifier)
            .ensureFresh(force: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Consumer(
          builder: (context, ref, _) {
            final name =
                ref.watch(accountDisplayLabelProvider).valueOrNull ?? 'User';
            return AppHeader(
              title: 'Admin Dashboard',
              subtitle: 'Welcome back',
              userName: name,
              onLogout: _logout,
              logoutLoading: _logoutLoading,
            );
          },
        ),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFF8B5CF6),
            onRefresh: () async {
              if (widget.loadCustomerCount == null) {
                await ref
                    .read(customerListNotifierProvider.notifier)
                    .refresh(force: true);
                await ref
                    .read(adminCustomerIdsStaleProvider.notifier)
                    .refresh(force: true);
              }
              setState(() {
                _walletTotalsFuture = _resolveWalletTotals();
                _customersWithSavingFuture = _loadCustomersWithPositiveSaving();
                _customersWithCreditFuture = _loadCustomersWithCredit();
                _customersWithFlatFuture = _loadCustomersWithFlatBalance();
              });
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<int>(
                        future:
                            widget.loadPendingWithdrawCount?.call() ??
                            _walletRepo!.fetchPendingWithdrawCount(limit: 99),
                        builder: (context, snap) {
                          return _StatCard(
                            title: 'Pending',
                            subtitle: 'Approvals',
                            value: snap.data?.toString() ?? '--',
                            icon: Icons.pending_actions_rounded,
                            color: const Color(0xFFF59E0B),
                            footerText: widget.onNavigateToTab == null
                                ? null
                                : 'Tap to review',
                            onTap: () => widget.onNavigateToTab?.call(
                              AdminTab.approvals,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<WalletTotals>(
                        future: _walletTotalsFuture,
                        builder: (context, wtSnap) {
                          final wt = wtSnap.data;
                          return widget.loadCustomerCount != null
                              ? FutureBuilder<int>(
                                  future: widget.loadCustomerCount!(),
                                  builder: (context, snap) {
                                    return _StatCard(
                                      title: 'Total',
                                      subtitle: 'Customers',
                                      value: snap.data?.toString() ?? '--',
                                      metricLine: wt != null
                                          ? _walletCountLabel(
                                              wt.totalCustomerWalletCount,
                                            )
                                          : null,
                                      icon: Icons.people_rounded,
                                      color: const Color(0xFF8B5CF6),
                                      footerText: widget.onNavigateToTab == null
                                          ? null
                                          : 'Tap to open list',
                                      onTap: () => widget.onNavigateToTab?.call(
                                        AdminTab.customers,
                                      ),
                                    );
                                  },
                                )
                              : Builder(
                                  builder: (context) {
                                    final ids = ref.watch(
                                      adminCustomerIdsStaleProvider,
                                    );
                                    final count = ids.data?.length ?? 0;
                                    final loading =
                                        ids.isRefreshing && count == 0;
                                    return _StatCard(
                                      title: 'Total',
                                      subtitle: 'Customers',
                                      value: loading ? '--' : count.toString(),
                                      metricLine: wt != null
                                          ? _walletCountLabel(
                                              wt.totalCustomerWalletCount,
                                            )
                                          : null,
                                      icon: Icons.people_rounded,
                                      color: const Color(0xFF8B5CF6),
                                      footerText: widget.onNavigateToTab == null
                                          ? null
                                          : 'Tap to open list',
                                      onTap: () => widget.onNavigateToTab?.call(
                                        AdminTab.customers,
                                      ),
                                    );
                                  },
                                );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<WalletTotals>(
                        future: _walletTotalsFuture,
                        builder: (context, wtSnap) {
                          final wt = wtSnap.data;
                          return FutureBuilder<List<Customer>>(
                            future: _customersWithSavingFuture,
                            builder: (context, savingCustomersSnap) {
                              final savingCustomers =
                                  savingCustomersSnap.data ??
                                  const <Customer>[];
                              final savingCents = wt?.totalSavingCents ?? 0;
                              final wPos = wt?.walletsWithPositiveBalanceCount;
                              return _StatCard(
                                title: 'Total',
                                subtitle: 'Saving',
                                value: (savingCents / 100).toStringAsFixed(0),
                                icon: Icons.account_balance_rounded,
                                color: const Color(0xFF10B981),
                                metricLine: wPos != null
                                    ? '${_walletCountLabel(wPos)} · ${_customerCountLabel(savingCustomers.length)}'
                                    : _customerCountLabel(
                                        savingCustomers.length,
                                      ),
                                footerText: widget.onNavigateToTab == null
                                    ? null
                                    : 'Tap for detail',
                                onTap: () => _showCustomersWithSavingModal(
                                  context,
                                  headerTotalCents: savingCents,
                                  walletMetricCount: wPos ?? 0,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<WalletTotals>(
                        future: _walletTotalsFuture,
                        builder: (context, wtSnap) {
                          final wt = wtSnap.data;
                          return FutureBuilder<List<Customer>>(
                            future: _customersWithCreditFuture,
                            builder: (context, creditCustomersSnap) {
                              final creditCustomers =
                                  creditCustomersSnap.data ??
                                  const <Customer>[];
                              final creditCents = (wt?.totalCreditCents ?? 0)
                                  .abs();
                              final wNeg = wt?.walletsWithNegativeBalanceCount;
                              return _StatCard(
                                title: 'Total',
                                subtitle: 'Credit',
                                value: (creditCents / 100).toStringAsFixed(0),
                                icon: Icons.credit_card_rounded,
                                color: const Color(0xFFEF5350),
                                metricLine: wNeg != null
                                    ? '${_walletCountLabel(wNeg)} · ${_customerCountLabel(creditCustomers.length)}'
                                    : _customerCountLabel(
                                        creditCustomers.length,
                                      ),
                                footerText: widget.onNavigateToTab == null
                                    ? null
                                    : 'Tap for detail',
                                onTap: () => _showCustomersWithCreditModal(
                                  context,
                                  headerTotalCents: creditCents,
                                  walletMetricCount: wNeg ?? 0,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<WalletTotals>(
                  future: _walletTotalsFuture,
                  builder: (context, wtSnap) {
                    final wt = wtSnap.data;
                    return FutureBuilder<List<Customer>>(
                      future: _customersWithFlatFuture,
                      builder: (context, flatCustomersSnap) {
                        final flatCustomers =
                            flatCustomersSnap.data ?? const <Customer>[];
                        final totalWallets = wt?.totalCustomerWalletCount ?? 0;
                        final positiveWallets =
                            wt?.walletsWithPositiveBalanceCount ?? 0;
                        final negativeWallets =
                            wt?.walletsWithNegativeBalanceCount ?? 0;
                        final flatWallets =
                            (totalWallets - positiveWallets - negativeWallets)
                                .clamp(0, totalWallets);

                        return _StatCard(
                          title: 'Total',
                          subtitle: 'Flat',
                          value: flatCustomers.length.toString(),
                          icon: Icons.horizontal_rule_rounded,
                          color: const Color(0xFF6366F1),
                          metricLine:
                              '${_walletCountLabel(flatWallets)} · ${_customerCountLabel(flatCustomers.length)}',
                          footerText: widget.onNavigateToTab == null
                              ? null
                              : 'Tap for detail',
                          onTap: () => _showCustomersWithFlatModal(
                            context,
                            walletMetricCount: flatWallets,
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<WalletTotals>(
                        future: _walletTotalsFuture,
                        builder: (context, snap) {
                          final wt = snap.data;
                          final saving = wt?.totalSavingCents ?? 0;
                          final credit = wt?.totalCreditCents ?? 0;
                          final revenue = saving + credit;
                          return _StatCard(
                            title: 'Total',
                            subtitle: 'Revenue',
                            value: (revenue / 100).toStringAsFixed(0),
                            icon: Icons.monetization_on_rounded,
                            color: const Color(0xFF0EA5E9),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<WalletTotals>(
                        future: _walletTotalsFuture,
                        builder: (context, snap) {
                          final wt = snap.data;
                          final saving = wt?.totalSavingCents ?? 0;
                          final creditAbs = (wt?.totalCreditCents ?? 0).abs();
                          final totalMoney = saving + creditAbs;
                          return _StatCard(
                            title: 'Total',
                            subtitle: 'Money',
                            value: (totalMoney / 100).toStringAsFixed(0),
                            icon: Icons.account_balance_wallet_rounded,
                            color: const Color(0xFF14B8A6),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 12),
                _QuickActionTile(
                  icon: Icons.person_add_rounded,
                  title: 'Add New Customer',
                  subtitle: 'Create a new customer profile',
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    AppRoutes.goToAdminCreateCustomer(context);
                  },
                ),
                const SizedBox(height: 8),
                _QuickActionTile(
                  icon: Icons.savings_rounded,
                  title: 'Record Daily Saving',
                  subtitle: 'Add daily payment for a customer',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    widget.onNavigateToTab?.call(AdminTab.daily);
                  },
                ),
                const SizedBox(height: 8),
                _QuickActionTile(
                  icon: Icons.approval_rounded,
                  title: 'Review Withdrawals',
                  subtitle: 'Approve or reject pending requests',
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    widget.onNavigateToTab?.call(AdminTab.approvals);
                  },
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Color(0xFF8B5CF6),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pro Tip',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B5CF6),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Use the Daily tab to quickly record payments for multiple customers.',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<List<Customer>> _loadCustomersWithPositiveSaving() async {
    final customers = await _customerRepo!.fetchAllActiveCustomers();
    final walletBalances = await _loadWalletBalancesByCustomerIds(customers);
    final withSaving = customers.where((customer) {
      final wallets = walletBalances[customer.customerId] ?? const <CustomerWallet>[];
      if (wallets.isEmpty) {
        return customer.balanceCents > 0;
      }
      return wallets.any((wallet) => wallet.balanceCents > 0);
    }).toList(growable: false);
    return _sortCustomers(withSaving);
  }

  Future<List<Customer>> _loadCustomersWithCredit() async {
    final customers = await _customerRepo!.fetchAllActiveCustomers();
    final walletBalances = await _loadWalletBalancesByCustomerIds(customers);
    final withCredit = customers.where((customer) {
      final wallets = walletBalances[customer.customerId] ?? const <CustomerWallet>[];
      if (wallets.isEmpty) {
        return customer.balanceCents < 0;
      }
      return wallets.any((wallet) => wallet.balanceCents < 0);
    }).toList(growable: false);
    return _sortCustomers(withCredit);
  }

  Future<List<Customer>> _loadCustomersWithFlatBalance() async {
    final customers = await _customerRepo!.fetchAllActiveCustomers();
    final walletBalances = await _loadWalletBalancesByCustomerIds(customers);
    final withFlat = customers.where((customer) {
      final wallets = walletBalances[customer.customerId] ?? const <CustomerWallet>[];
      if (wallets.isEmpty) {
        return customer.balanceCents == 0;
      }
      return wallets.any((wallet) => wallet.balanceCents == 0);
    }).toList(growable: false);
    return _sortCustomers(withFlat);
  }

  Future<Map<String, List<CustomerWallet>>> _loadWalletBalancesByCustomerIds(
    List<Customer> customers,
  ) async {
    if (_walletRepo == null || customers.isEmpty) {
      return const <String, List<CustomerWallet>>{};
    }
    final customerIds = customers.map((customer) => customer.customerId).toList(growable: false);
    return _walletRepo!.fetchWalletsForCustomers(customerIds);
  }

  Future<Map<String, int>> _loadSavingByCustomerId(List<Customer> customers) async {
    final walletBalances = await _loadWalletBalancesByCustomerIds(customers);
    final result = <String, int>{};
    for (final customer in customers) {
      final wallets = walletBalances[customer.customerId] ?? const <CustomerWallet>[];
      if (wallets.isEmpty) {
        result[customer.customerId] = customer.balanceCents > 0 ? customer.balanceCents : 0;
        continue;
      }
      final sum = wallets
          .where((wallet) => wallet.balanceCents > 0)
          .fold<int>(0, (acc, wallet) => acc + wallet.balanceCents);
      result[customer.customerId] = sum;
    }
    return result;
  }

  Future<Map<String, int>> _loadCreditByCustomerId(List<Customer> customers) async {
    final walletBalances = await _loadWalletBalancesByCustomerIds(customers);
    final result = <String, int>{};
    for (final customer in customers) {
      final wallets = walletBalances[customer.customerId] ?? const <CustomerWallet>[];
      if (wallets.isEmpty) {
        result[customer.customerId] = customer.balanceCents < 0 ? customer.balanceCents.abs() : 0;
        continue;
      }
      final sum = wallets
          .where((wallet) => wallet.balanceCents < 0)
          .fold<int>(0, (acc, wallet) => acc + wallet.balanceCents.abs());
      result[customer.customerId] = sum;
    }
    return result;
  }

  List<Customer> _sortCustomers(List<Customer> customers) {
    final sorted = [...customers];
    sorted.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return sorted;
  }

  String _customerCountLabel(int count) {
    return '$count customer${count == 1 ? '' : 's'}';
  }

  String _walletCountLabel(int count) {
    return '$count wallet${count == 1 ? '' : 's'}';
  }

  Future<void> _showCustomersWithSavingModal(
    BuildContext context, {
    required int headerTotalCents,
    required int walletMetricCount,
  }) async {
    await _showCustomerBalanceModal(
      context,
      title: 'Customers With Saving',
      future: _customersWithSavingFuture,
      emptyMessage: 'No customers with positive saving right now.',
      valueFor: (customer) => customer.balanceCents,
      walletValueForCustomers: _loadSavingByCustomerId,
      valueColor: const Color(0xFF10B981),
      headerTotalCents: headerTotalCents,
      walletMetricCount: walletMetricCount,
    );
  }

  Future<void> _showCustomersWithCreditModal(
    BuildContext context, {
    required int headerTotalCents,
    required int walletMetricCount,
  }) async {
    await _showCustomerBalanceModal(
      context,
      title: 'Customers With Credit',
      future: _customersWithCreditFuture,
      emptyMessage: 'No customers with credit right now.',
      valueFor: (customer) => customer.balanceCents.abs(),
      walletValueForCustomers: _loadCreditByCustomerId,
      valueColor: const Color(0xFFEF5350),
      headerTotalCents: headerTotalCents,
      walletMetricCount: walletMetricCount,
    );
  }

  Future<void> _showCustomersWithFlatModal(
    BuildContext context, {
    required int walletMetricCount,
  }) async {
    await _showCustomerBalanceModal(
      context,
      title: 'Customers With Flat Balance',
      future: _customersWithFlatFuture,
      emptyMessage: 'No customers with flat (0) balance right now.',
      valueFor: (_) => 0,
      valueColor: const Color(0xFF6366F1),
      headerTotalCents: 0,
      walletMetricCount: walletMetricCount,
    );
  }

  Future<void> _showCustomerBalanceModal(
    BuildContext context, {
    required String title,
    required Future<List<Customer>> future,
    required String emptyMessage,
    required int Function(Customer customer) valueFor,
    Future<Map<String, int>> Function(List<Customer> customers)? walletValueForCustomers,
    required Color valueColor,
    int? headerTotalCents,
    int? walletMetricCount,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.82,
          child: FutureBuilder<List<Customer>>(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load $title.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${snap.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final customers = snap.data ?? const <Customer>[];
              if (customers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(emptyMessage)),
                );
              }
              return FutureBuilder<Map<String, int>>(
                future: walletValueForCustomers?.call(customers) ??
                    Future.value(const <String, int>{}),
                builder: (context, walletValuesSnap) {
                  final walletValues = walletValuesSnap.data ?? const <String, int>{};
                  final resolvedValueFor = (Customer customer) {
                    final walletValue = walletValues[customer.customerId];
                    return walletValue ?? valueFor(customer);
                  };
                  final listSumCents = customers.fold<int>(
                    0,
                    (sum, customer) => sum + resolvedValueFor(customer),
                  );
                  final totalCents = headerTotalCents ?? listSumCents;

                  return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          headerTotalCents != null
                              ? '${_walletCountLabel(walletMetricCount ?? 0)} · ${_customerCountLabel(customers.length)} listed · ${MoneyEtb.formatCents(totalCents)} total'
                              : '${_customerCountLabel(customers.length)} · ${MoneyEtb.formatCents(totalCents)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (headerTotalCents != null &&
                            listSumCents != headerTotalCents &&
                            customers.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'List sum ${MoneyEtb.formatCents(listSumCents)} (wallet-based per customer).',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: customers.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = customers[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          leading: CustomerProfileAvatar(
                            customer: customer,
                            radius: 20,
                            enablePreview: true,
                          ),
                          title: Text(customer.fullName),
                          subtitle: Text(
                            '${customer.companyName} - ${customer.phone}',
                          ),
                          trailing: Text(
                            MoneyEtb.formatCents(resolvedValueFor(customer)),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: valueColor,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CustomerDetailScreen(
                                  customerId: customer.customerId,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color color;

  /// Optional line under the main [value] (e.g. wallet totals).
  final String? metricLine;
  final String? footerText;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
    this.metricLine,
    this.footerText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              if (metricLine != null) ...[
                const SizedBox(height: 6),
                Text(
                  metricLine!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: secondary,
                    height: 1.25,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '$title\n$subtitle',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  height: 1.3,
                ),
              ),
              if (footerText != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        footerText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (enabled)
                      Icon(Icons.open_in_new_rounded, size: 16, color: color),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF6B7280),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
