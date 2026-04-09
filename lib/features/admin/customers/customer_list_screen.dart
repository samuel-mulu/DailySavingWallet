import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/routing/routes.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/filter_count_chip.dart';
import '../../../data/customers/customer_model.dart';
import '../../customers/customer_list_notifier.dart';
import 'customer_detail_screen.dart';
import 'widgets/customer_profile_avatar.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  _AlphabetSortOrder _sortOrder = _AlphabetSortOrder.az;
  _CustomerBalanceFilter _balanceFilter = _CustomerBalanceFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerListNotifierProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(customerListNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final hasSearch = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Builder(
        builder: (context) {
          if (listState.error != null && listState.items.isEmpty) {
            return Center(child: Text('Error: ${listState.error}'));
          }

          if (listState.items.isEmpty &&
              listState.isRefreshing &&
              !listState.loadingMore) {
            return const Center(child: CircularProgressIndicator());
          }

          final sortedCustomers = _sortedCustomers(listState.items);
          final debtCount = sortedCustomers
              .where((c) => c.balanceCents < 0)
              .length;
          final positiveSavingCount = sortedCustomers
              .where((c) => c.balanceCents > 0)
              .length;
          final filteredCustomers = _applyBalanceFilter(sortedCustomers);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                          _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 350),
                            () {
                              ref
                                  .read(customerListNotifierProvider.notifier)
                                  .loadInitial(search: value.trim());
                            },
                          );
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by name, phone, or company',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: hasSearch
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                    ref
                                        .read(
                                          customerListNotifierProvider.notifier,
                                        )
                                        .loadInitial(search: '');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: PopupMenuButton<_AlphabetSortOrder>(
                        tooltip: 'Sort customers',
                        initialValue: _sortOrder,
                        onSelected: (value) =>
                            setState(() => _sortOrder = value),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _AlphabetSortOrder.az,
                            child: Text('Sort A-Z'),
                          ),
                          PopupMenuItem(
                            value: _AlphabetSortOrder.za,
                            child: Text('Sort Z-A'),
                          ),
                        ],
                        icon: Icon(
                          _sortOrder == _AlphabetSortOrder.az
                              ? Icons.sort_by_alpha
                              : Icons.sort_by_alpha_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterCountChip(
                        label: 'All',
                        count: sortedCustomers.length,
                        selected: _balanceFilter == _CustomerBalanceFilter.all,
                        icon: Icons.people_alt_outlined,
                        onTap: () => setState(
                          () => _balanceFilter = _CustomerBalanceFilter.all,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterCountChip(
                        label: 'Debt / Credit',
                        count: debtCount,
                        selected: _balanceFilter == _CustomerBalanceFilter.debt,
                        icon: Icons.credit_card_off_outlined,
                        onTap: () => setState(
                          () => _balanceFilter = _CustomerBalanceFilter.debt,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterCountChip(
                        label: 'Positive Saving',
                        count: positiveSavingCount,
                        selected:
                            _balanceFilter ==
                            _CustomerBalanceFilter.positiveSaving,
                        icon: Icons.savings_outlined,
                        onTap: () => setState(
                          () => _balanceFilter =
                              _CustomerBalanceFilter.positiveSaving,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: filteredCustomers.isEmpty
                    ? EmptyState(
                        icon: hasSearch
                            ? Icons.person_search
                            : Icons.people_outline,
                        title: hasSearch
                            ? 'No customers found'
                            : 'No customers in this filter',
                        message: hasSearch
                            ? 'Try a different name, phone number, or company.'
                            : _emptyMessageForFilter(),
                        action: FilledButton.icon(
                          onPressed: () async {
                            if (hasSearch) {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                              ref
                                  .read(customerListNotifierProvider.notifier)
                                  .loadInitial(search: '');
                              return;
                            }

                            if (_balanceFilter != _CustomerBalanceFilter.all) {
                              setState(
                                () =>
                                    _balanceFilter = _CustomerBalanceFilter.all,
                              );
                              return;
                            }

                            await AppRoutes.goToAdminCreateCustomer(context);
                          },
                          icon: Icon(
                            hasSearch ||
                                    _balanceFilter != _CustomerBalanceFilter.all
                                ? Icons.clear
                                : Icons.person_add,
                          ),
                          label: Text(
                            hasSearch ||
                                    _balanceFilter != _CustomerBalanceFilter.all
                                ? 'Clear Filters'
                                : 'Create Customer',
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(customerListNotifierProvider.notifier)
                            .refresh(force: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount:
                              filteredCustomers.length +
                              (listState.nextCursor != null ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= filteredCustomers.length) {
                              if (listState.loadingMore) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return Center(
                                child: TextButton(
                                  onPressed: () => ref
                                      .read(
                                        customerListNotifierProvider.notifier,
                                      )
                                      .loadMore(),
                                  child: const Text('Load more'),
                                ),
                              );
                            }

                            final customer = filteredCustomers[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: CustomerCard(
                                customer: customer,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CustomerDetailScreen(
                                        customerId: customer.customerId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'customer_status',
            tooltip: 'Customer status',
            onPressed: () => AppRoutes.goToAdminCustomerStatus(context),
            child: const Icon(Icons.manage_accounts_outlined),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'add_customer',
            tooltip: 'Add customer',
            onPressed: () async {
              await AppRoutes.goToAdminCreateCustomer(context);
              if (context.mounted) {
                await ref.read(customerListNotifierProvider.notifier).refresh();
              }
            },
            child: const Icon(Icons.person_add),
          ),
        ],
      ),
    );
  }

  String _emptyMessageForFilter() {
    switch (_balanceFilter) {
      case _CustomerBalanceFilter.all:
        return 'Create your first customer to start recording daily savings and deposits.';
      case _CustomerBalanceFilter.debt:
        return 'No customers currently have a debt or credit balance.';
      case _CustomerBalanceFilter.positiveSaving:
        return 'No customers currently have a positive saving balance.';
    }
  }

  List<Customer> _sortedCustomers(List<Customer> input) {
    final customers = [...input];
    customers.sort((a, b) {
      final compare = a.fullName.toLowerCase().compareTo(
        b.fullName.toLowerCase(),
      );
      return _sortOrder == _AlphabetSortOrder.az ? compare : -compare;
    });
    return customers;
  }

  List<Customer> _applyBalanceFilter(List<Customer> customers) {
    switch (_balanceFilter) {
      case _CustomerBalanceFilter.all:
        return customers;
      case _CustomerBalanceFilter.debt:
        return customers
            .where((customer) => customer.balanceCents < 0)
            .toList();
      case _CustomerBalanceFilter.positiveSaving:
        return customers
            .where((customer) => customer.balanceCents > 0)
            .toList();
    }
  }
}

enum _AlphabetSortOrder { az, za }

enum _CustomerBalanceFilter { all, debt, positiveSaving }

class CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const CustomerCard({super.key, required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final balance = customer.balanceCents;
    final hasDebt = balance < 0;
    final hasSaving = balance > 0;
    final accent = hasDebt
        ? colorScheme.error
        : hasSaving
        ? const Color(0xFF10B981)
        : colorScheme.primary;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CustomerProfileAvatar(
                      customer: customer,
                      radius: 24,
                      enablePreview: true,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.fullName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer.companyName,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer.phone,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _BalanceStatusChip(
                          label: hasDebt
                              ? 'Debt'
                              : hasSaving
                              ? 'Saving'
                              : 'Flat',
                          color: accent,
                        ),
                        const SizedBox(height: 10),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colorScheme.outline,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _CustomerMetricBlock(
                        label: 'Balance',
                        value: MoneyEtb.formatCents(balance.abs()),
                        color: accent,
                        emphasize: true,
                        prefix: hasDebt
                            ? '-'
                            : hasSaving
                            ? '+'
                            : '',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CustomerMetricBlock(
                        label: 'Daily Target',
                        value: MoneyEtb.formatCents(customer.dailyTargetCents),
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CustomerMetricBlock(
                        label: 'Credit Limit',
                        value: MoneyEtb.formatCents(customer.creditLimitCents),
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceStatusChip extends StatelessWidget {
  const _BalanceStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _CustomerMetricBlock extends StatelessWidget {
  const _CustomerMetricBlock({
    required this.label,
    required this.value,
    required this.color,
    this.emphasize = false,
    this.prefix = '',
  });

  final String label;
  final String value;
  final Color color;
  final bool emphasize;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$prefix$value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              color: emphasize ? color : colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
