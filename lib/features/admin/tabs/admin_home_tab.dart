import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/routing/routes.dart';
import '../../../core/ui/app_header.dart';
import '../../../data/customers/customer_model.dart';
import '../../../data/customers/customer_repo.dart';
import '../../../data/wallet/wallet_repo.dart';
import '../../auth/providers/auth_providers.dart';
import '../../customers/admin_customer_ids_notifier.dart';
import '../../customers/customer_list_notifier.dart';
import '../customers/customer_detail_screen.dart';
import '../customers/widgets/customer_profile_avatar.dart';
import '../admin_tab.dart';

class AdminHomeTab extends ConsumerStatefulWidget {
  final ValueChanged<AdminTab>? onNavigateToTab;
  final WalletRepo? walletRepo;
  final CustomerRepo? customerRepo;
  final Future<int> Function()? loadPendingWithdrawCount;
  final Future<int> Function()? loadCustomerCount;
  final Future<int> Function()? loadTotalSaving;
  final Future<int> Function()? loadTotalCredit;

  const AdminHomeTab({
    super.key,
    this.onNavigateToTab,
    this.walletRepo,
    this.customerRepo,
    this.loadPendingWithdrawCount,
    this.loadCustomerCount,
    this.loadTotalSaving,
    this.loadTotalCredit,
  });

  @override
  ConsumerState<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends ConsumerState<AdminHomeTab> {
  WalletRepo? _walletRepo;
  CustomerRepo? _customerRepo;
  late Future<List<Customer>> _customersWithCreditFuture;

  @override
  void initState() {
    super.initState();
    _customerRepo = widget.customerRepo ?? CustomerRepo();
    if (widget.loadPendingWithdrawCount == null ||
        widget.loadTotalSaving == null ||
        widget.loadTotalCredit == null) {
      _walletRepo = widget.walletRepo ?? WalletRepo();
    }
    _customersWithCreditFuture = _loadCustomersWithCredit();
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
    return Column(
      children: [
        // Header
        Consumer(
          builder: (context, ref, _) {
            final name =
                ref.watch(accountDisplayLabelProvider).valueOrNull ?? 'User';
            return AppHeader(
              title: 'Admin Dashboard',
              subtitle: 'Welcome back',
              userName: name,
              onLogout: () => ref.read(authClientProvider).signOut(),
            );
          },
        ),

        // Content
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
                _customersWithCreditFuture = _loadCustomersWithCredit();
              });
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Stats Row
                Row(
                  children: [
                    // Pending Approvals
                    Expanded(
                      child: FutureBuilder<int>(
                        future:
                            widget.loadPendingWithdrawCount?.call() ??
                            _walletRepo!.fetchPendingWithdrawCount(limit: 99),
                        builder: (context, snap) {
                          return _StatCard(
                            title: 'Pending',
                            subtitle: 'Approvals',
                            value: snap.data?.toString() ?? '—',
                            icon: Icons.pending_actions_rounded,
                            color: const Color(0xFFF59E0B),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Total Customers
                    Expanded(
                      child: widget.loadCustomerCount != null
                          ? FutureBuilder<int>(
                              future: widget.loadCustomerCount!(),
                              builder: (context, snap) {
                                return _StatCard(
                                  title: 'Total',
                                  subtitle: 'Customers',
                                  value: snap.data?.toString() ?? '—',
                                  icon: Icons.people_rounded,
                                  color: const Color(0xFF8B5CF6),
                                );
                              },
                            )
                          : Builder(
                              builder: (context) {
                                final ids = ref.watch(
                                  adminCustomerIdsStaleProvider,
                                );
                                final n = ids.data?.length ?? 0;
                                final loading = ids.isRefreshing && n == 0;
                                return _StatCard(
                                  title: 'Total',
                                  subtitle: 'Customers',
                                  value: loading ? '—' : n.toString(),
                                  icon: Icons.people_rounded,
                                  color: const Color(0xFF8B5CF6),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Financial Stats Row 1
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<int>(
                        future:
                            widget.loadTotalSaving?.call() ??
                            _walletRepo!.fetchTotalSaving(),
                        builder: (context, snap) {
                          // Saving is positive
                          final val = snap.data ?? 0;
                          return _StatCard(
                            title: 'Total',
                            subtitle: 'Saving',
                            value: (val / 100).toStringAsFixed(0),
                            icon: Icons.account_balance_rounded,
                            color: const Color(0xFF10B981),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<List<Customer>>(
                        future: _customersWithCreditFuture,
                        builder: (context, creditCustomersSnap) {
                          final creditCustomers =
                              creditCustomersSnap.data ?? const <Customer>[];
                          return FutureBuilder<int>(
                            future:
                                widget.loadTotalCredit?.call() ??
                                _walletRepo!.fetchTotalCredit(),
                            builder: (context, snap) {
                              final val = (snap.data ?? 0).abs();
                              final countText =
                                  '${creditCustomers.length} customer${creditCustomers.length == 1 ? '' : 's'}';
                              return _StatCard(
                                title: 'Total',
                                subtitle: 'Credit',
                                value: (val / 100).toStringAsFixed(0),
                                icon: Icons.credit_card_rounded,
                                color: const Color(0xFFEF5350),
                                footerText: countText,
                                onTap: () =>
                                    _showCustomersWithCreditModal(context),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Financial Stats Row 2 (Revenue)
                FutureBuilder<List<int>>(
                  future: Future.wait([
                    widget.loadTotalSaving?.call() ??
                        _walletRepo!.fetchTotalSaving(),
                    widget.loadTotalCredit?.call() ??
                        _walletRepo!.fetchTotalCredit(),
                  ]),
                  builder: (context, snap) {
                    final saving = snap.data?[0] ?? 0;
                    final credit = snap.data?[1] ?? 0;
                    // Revenue = Saving - Credit
                    // If Credit in DB is NEGATIVE (e.g. -100).
                    // User said "wallets have credit and saving".
                    // "total revune(total saving - the crefit)".
                    // This implies Revenue = Net Value?
                    // If I have 100 saving, and -50 credit. Net = 50.
                    // "Saving - Credit" -> 100 - 50 = 50. (if Credit is magnitude)
                    // "Saving + Credit" -> 100 + (-50) = 50. (if Credit is raw)
                    // So standard Net = Sum.
                    // But User's formula "saving - credit" suggests they think of credit as a positive number TO BE SUBTRACTED?
                    // OR maybe they mean "Revenue = Saving (Assets) - Credit (Outstanding Loans)"?
                    // Let's assume Revenue = Saving + Credit (raw sum) which is Net Balance.
                    // Examples:
                    // User A: +200. User B: -50.
                    // Total Saving: 200.
                    // Total Credit: -50 (or 50).
                    // "Revenue" = 150.
                    // Formula: 200 + (-50) = 150.
                    // If I use user's string "saving - credit":
                    // 200 - 50 = 150.
                    // So `saving - credit.abs()` or `saving + credit`.
                    // I will use `saving + credit` (since credit is negative).

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

                const SizedBox(height: 20),

                // Quick Actions Section
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D2D2D),
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

                // Tips Card
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
                                color: const Color(0xFF6B7280),
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

  Future<List<Customer>> _loadCustomersWithCredit() async {
    final customers = await _customerRepo!.fetchAllActiveCustomers();
    final withCredit = customers
        .where((customer) => customer.balanceCents < 0)
        .toList(growable: false);
    final sorted = [...withCredit];
    sorted.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return sorted;
  }

  Future<void> _showCustomersWithCreditModal(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.8,
          child: FutureBuilder<List<Customer>>(
            future: _customersWithCreditFuture,
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
                      const Text(
                        'Could not load customers with credit.',
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
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No customers with credit right now.'),
                  ),
                );
              }

              final totalCreditCents = customers.fold<int>(
                0,
                (sum, customer) => sum + customer.balanceCents.abs(),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customers With Credit',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${customers.length} customer${customers.length == 1 ? '' : 's'} • ${MoneyEtb.formatCents(totalCreditCents)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
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
                          leading: CustomerProfileAvatar(
                            customer: customer,
                            radius: 20,
                            enablePreview: true,
                          ),
                          title: Text(customer.fullName),
                          subtitle: Text(
                            '${customer.companyName} • ${customer.phone}',
                          ),
                          trailing: Text(
                            MoneyEtb.formatCents(customer.balanceCents.abs()),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.error,
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
  final String? footerText;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
    this.footerText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 4),
              Text(
                '$title\n$subtitle',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                  height: 1.3,
                ),
              ),
              if (footerText != null) ...[
                const SizedBox(height: 8),
                Text(
                  footerText!,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: const Color(0xFF6B7280),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
