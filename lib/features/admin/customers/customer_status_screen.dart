import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/filter_count_chip.dart';
import '../../../core/ui/skeleton_box.dart';
import '../../../data/customers/customer_model.dart';
import '../../../data/wallet/models.dart';
import '../../data/repository_providers.dart';
import 'customer_detail_screen.dart';
import 'customer_status_providers.dart';
import 'customer_status_list_state.dart';
import 'widgets/customer_profile_avatar.dart';

class CustomerStatusScreen extends ConsumerStatefulWidget {
  const CustomerStatusScreen({super.key});

  @override
  ConsumerState<CustomerStatusScreen> createState() =>
      _CustomerStatusScreenState();
}

class _CustomerStatusScreenState extends ConsumerState<CustomerStatusScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  _AlphabetSortOrder _sortOrder = _AlphabetSortOrder.az;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  IconData _iconForWalletStatus(String status) {
    switch (status) {
      case WalletStatusFilter.all:
        return Icons.account_balance_wallet_outlined;
      case WalletStatusFilter.active:
        return Icons.check_circle_outline;
      case WalletStatusFilter.frozen:
        return Icons.ac_unit;
      case WalletStatusFilter.closed:
        return Icons.lock_outline;
      default:
        return Icons.tune;
    }
  }

  String _labelForWalletStatus(String status) {
    switch (status) {
      case WalletStatusFilter.all:
        return 'All';
      case WalletStatusFilter.active:
        return 'Active';
      case WalletStatusFilter.frozen:
        return 'Frozen';
      case WalletStatusFilter.closed:
        return 'Closed';
      default:
        return status;
    }
  }

  Future<void> _refreshAll() async {
    ref.invalidate(customerStatusWalletsProvider);
    await ref.read(customerStatusListNotifierProvider.notifier).refresh();
  }

  List<Customer> _sorted(List<Customer> input) {
    final list = [...input];
    list.sort((a, b) {
      final c = a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      return _sortOrder == _AlphabetSortOrder.az ? c : -c;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(customerStatusListNotifierProvider);
    final walletsMapAsync = ref.watch(customerStatusWalletsProvider);
    final hasSearch = listState.searchApplied.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer wallet status'),
        actions: [
          PopupMenuButton<_AlphabetSortOrder>(
            tooltip: 'Sort customers',
            initialValue: _sortOrder,
            onSelected: (v) => setState(() => _sortOrder = v),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _AlphabetSortOrder.az, child: Text('Sort A-Z')),
              PopupMenuItem(value: _AlphabetSortOrder.za, child: Text('Sort Z-A')),
            ],
            icon: Icon(
              _sortOrder == _AlphabetSortOrder.az
                  ? Icons.sort_by_alpha
                  : Icons.sort_by_alpha_outlined,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < WalletStatusFilter.allValues.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    FilterCountChip(
                      label: _labelForWalletStatus(WalletStatusFilter.allValues[i]),
                      count: walletsMapAsync.valueOrNull == null
                          ? 0
                          : _countWalletsByStatus(
                              walletsMapAsync.valueOrNull!,
                              WalletStatusFilter.allValues[i],
                            ),
                      selected:
                          listState.walletStatusFilter ==
                              WalletStatusFilter.allValues[i],
                      icon: _iconForWalletStatus(WalletStatusFilter.allValues[i]),
                      onTap: () => ref
                          .read(customerStatusListNotifierProvider.notifier)
                          .setWalletStatusFilter(WalletStatusFilter.allValues[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  final wf =
                      ref.read(customerStatusListNotifierProvider).walletStatusFilter;
                  ref
                      .read(customerStatusListNotifierProvider.notifier)
                      .loadInitial(
                        search: v.trim(),
                        walletStatusFilter: wf,
                      );
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or company',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (listState.error != null && listState.items.isEmpty) {
                  return Center(child: Text('Error: ${listState.error}'));
                }
                if (listState.items.isEmpty &&
                    listState.isRefreshing &&
                    !listState.loadingMore) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (walletsMapAsync.isLoading && !walletsMapAsync.hasValue) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      SkeletonBox(width: double.infinity, height: 70, radius: 12),
                      SizedBox(height: 10),
                      SkeletonBox(width: double.infinity, height: 70, radius: 12),
                      SizedBox(height: 10),
                      SkeletonBox(width: double.infinity, height: 70, radius: 12),
                    ],
                  );
                }
                if (walletsMapAsync.hasError) {
                  return Center(child: Text('Error: ${walletsMapAsync.error}'));
                }

                final walletsMap = walletsMapAsync.value ?? const {};
                final filtered = _filterCustomersByWalletStatus(
                  _sorted(listState.items),
                  walletsMap,
                  listState.walletStatusFilter,
                );

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: hasSearch ? Icons.person_search : Icons.filter_alt_off,
                    title: hasSearch
                        ? 'No customers found'
                        : 'No customers in this wallet status',
                    message: hasSearch
                        ? 'Try a different search.'
                        : 'Pick another wallet status chip above.',
                    action: hasSearch
                        ? FilledButton.icon(
                            onPressed: () {
                              _searchCtrl.clear();
                              ref
                                  .read(customerStatusListNotifierProvider.notifier)
                                  .loadInitial(
                                    search: '',
                                    walletStatusFilter: listState.walletStatusFilter,
                                  );
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear search'),
                          )
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: filtered.length + (listState.nextCursor != null ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= filtered.length) {
                        if (listState.loadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return Center(
                          child: TextButton(
                            onPressed: () => ref
                                .read(customerStatusListNotifierProvider.notifier)
                                .loadMore(),
                            child: const Text('Load more'),
                          ),
                        );
                      }

                      final c = filtered[i];
                      final wallets = walletsMap[c.customerId] ?? const <CustomerWallet>[];
                      final totalBalance = wallets.fold<int>(0, (sum, w) => sum + w.balanceCents);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CustomerProfileAvatar(customer: c, radius: 20, enablePreview: true),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c.fullName, style: Theme.of(context).textTheme.titleSmall),
                                          Text(
                                            '${c.companyName} • ${wallets.length} wallets • ${MoneyEtb.formatCents(totalBalance)}',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Open details',
                                      icon: const Icon(Icons.open_in_new),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => CustomerDetailScreen(customerId: c.customerId),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                for (final w in wallets.where((w) => listState.walletStatusFilter == WalletStatusFilter.all || w.status == listState.walletStatusFilter))
                                  _WalletRow(
                                    customer: c,
                                    wallet: w,
                                    onActionDone: _refreshAll,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _countWalletsByStatus(
    Map<String, List<CustomerWallet>> walletsMap,
    String filter,
  ) {
    final wallets = walletsMap.values.expand((e) => e);
    if (filter == WalletStatusFilter.all) return wallets.length;
    return wallets.where((w) => w.status == filter).length;
  }

  List<Customer> _filterCustomersByWalletStatus(
    List<Customer> customers,
    Map<String, List<CustomerWallet>> walletsMap,
    String filter,
  ) {
    if (filter == WalletStatusFilter.all) return customers;
    return customers.where((c) {
      final ws = walletsMap[c.customerId] ?? const <CustomerWallet>[];
      return ws.any((w) => w.status == filter);
    }).toList();
  }
}

enum _AlphabetSortOrder { az, za }

class _WalletRow extends ConsumerWidget {
  const _WalletRow({
    required this.customer,
    required this.wallet,
    required this.onActionDone,
  });

  final Customer customer;
  final CustomerWallet wallet;
  final Future<void> Function() onActionDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final labelColor = switch (wallet.status) {
      WalletStatusFilter.active => Colors.green,
      WalletStatusFilter.frozen => Colors.orange,
      _ => Colors.redAccent,
    };

    Future<void> submit(String targetStatus) async {
      final reason = await _askReason(context, targetStatus);
      if (reason == null) return;
      await ref.read(walletRepoProvider).updateWalletStatus(
            customerId: customer.customerId,
            walletId: wallet.id,
            targetStatus: targetStatus,
            reason: reason,
          );
      await onActionDone();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${wallet.label} • ${MoneyEtb.formatCents(wallet.balanceCents)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            _TinyPill(label: wallet.status.toUpperCase(), color: labelColor),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz),
              onSelected: submit,
              itemBuilder: (_) => _actionsForStatus(wallet.status)
                  .map((e) => PopupMenuItem(value: e.$1, child: Text(e.$2)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askReason(BuildContext context, String targetStatus) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change to $targetStatus'),
        content: TextField(
          controller: ctrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  List<(String, String)> _actionsForStatus(String status) {
    switch (status) {
      case WalletStatusFilter.active:
        return [('FROZEN', 'Freeze'), ('CLOSED', 'Close')];
      case WalletStatusFilter.frozen:
        return [('ACTIVE', 'Reactivate'), ('CLOSED', 'Close')];
      default:
        return [('ACTIVE', 'Reactivate')];
    }
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? cs.surfaceContainerHighest).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color ?? cs.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
      ),
    );
  }
}
