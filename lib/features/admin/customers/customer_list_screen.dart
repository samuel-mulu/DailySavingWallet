import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/routes.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/money/money.dart';
import '../../../data/customers/customer_model.dart';
import 'customer_detail_screen.dart';
import '../../customers/customer_list_notifier.dart';
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
    final hasSearch = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          PopupMenuButton<_AlphabetSortOrder>(
            tooltip: 'Sort customers',
            initialValue: _sortOrder,
            onSelected: (value) => setState(() => _sortOrder = value),
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
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  ref
                      .read(customerListNotifierProvider.notifier)
                      .loadInitial(search: v.trim());
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or company',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
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

          final customers = _sortedCustomers(listState.items);

          if (customers.isEmpty) {
            return EmptyState(
              icon: hasSearch ? Icons.person_search : Icons.people_outline,
              title: hasSearch ? 'No customers found' : 'No customers yet',
              message: hasSearch
                  ? 'Try a different name, phone number, or company.'
                  : 'Create your first customer to start recording daily savings and deposits.',
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

                  await AppRoutes.goToAdminCreateCustomer(context);
                },
                icon: Icon(hasSearch ? Icons.clear : Icons.person_add),
                label: Text(hasSearch ? 'Clear Search' : 'Create Customer'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(customerListNotifierProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount:
                  customers.length + (listState.nextCursor != null ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= customers.length) {
                  if (listState.loadingMore) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return Center(
                    child: TextButton(
                      onPressed: () => ref
                          .read(customerListNotifierProvider.notifier)
                          .loadMore(),
                      child: const Text('Load more'),
                    ),
                  );
                }
                final customer = customers[i];
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
}

enum _AlphabetSortOrder { az, za }

class CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const CustomerCard({super.key, required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final balance = customer.balanceCents;
    final isNegative = balance < 0;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CustomerProfileAvatar(
                customer: customer,
                radius: 30,
                enablePreview: true,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.companyName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phone,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _CustomerMetricPill(
                          label: 'Daily',
                          value: MoneyEtb.formatCents(
                            customer.dailyTargetCents,
                          ),
                        ),
                        _CustomerMetricPill(
                          label: 'Credit',
                          value: MoneyEtb.formatCents(
                            customer.creditLimitCents,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    MoneyEtb.formatCents(balance),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isNegative
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (isNegative)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DEBT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerMetricPill extends StatelessWidget {
  const _CustomerMetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}
