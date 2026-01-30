import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/app_header.dart';
import '../../../data/customers/customer_repo.dart';
import '../../../data/wallet/wallet_repo.dart';

class AdminHomeTab extends StatefulWidget {
  const AdminHomeTab({super.key});

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  final _walletRepo = WalletRepo();
  final _customerRepo = CustomerRepo();

  String? get _userName => FirebaseAuth.instance.currentUser?.displayName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        AppHeader(
          title: 'Admin Dashboard',
          subtitle: 'Welcome back ${_userName ?? ''}'.trim(),
        ),

        // Content
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFF8B5CF6),
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Stats Row
                Row(
                  children: [
                    // Pending Approvals
                    Expanded(
                      child: FutureBuilder<int>(
                        future: _walletRepo.fetchPendingWithdrawCount(
                          limit: 99,
                        ),
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
                      child: StreamBuilder(
                        stream: _customerRepo.streamAllCustomers(),
                        builder: (context, snap) {
                          final count = snap.data?.length ?? 0;
                          return _StatCard(
                            title: 'Total',
                            subtitle: 'Customers',
                            value: count.toString(),
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
                        future: _walletRepo.fetchTotalSaving(),
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
                      child: FutureBuilder<int>(
                        future: _walletRepo.fetchTotalCredit(),
                        builder: (context, snap) {
                          // Credit is negative in DB.
                          // Display as positive for "Total Credit" context?
                          // Or display as negative?
                          // User said "total revenue (total saving - the credit)".
                          // If credit is -500. Saving 1000. Rev = 1000 - (-500)?? No.
                          // Likely "Credit" means DEBT (positive magnitude).
                          // If DB has -500.
                          // I will display |-500| = 500.
                          final val = (snap.data ?? 0).abs();
                          return _StatCard(
                            title: 'Total',
                            subtitle: 'Credit',
                            value: (val / 100).toStringAsFixed(0),
                            icon: Icons.credit_card_rounded,
                            color: const Color(0xFFEF5350),
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
                    _walletRepo.fetchTotalSaving(),
                    _walletRepo.fetchTotalCredit(),
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
                    // Navigate to create customer
                    Navigator.of(context).pushNamed('/admin/customers/create');
                  },
                ),
                const SizedBox(height: 8),
                _QuickActionTile(
                  icon: Icons.savings_rounded,
                  title: 'Record Daily Saving',
                  subtitle: 'Add daily payment for a customer',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    // Navigate to daily check tab
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Go to Daily tab')),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _QuickActionTile(
                  icon: Icons.approval_rounded,
                  title: 'Review Withdrawals',
                  subtitle: 'Approve or reject pending requests',
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    // Navigate to approvals tab
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Go to Approvals tab')),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Tips Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
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
}

class _StatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
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
          ],
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
                  color: color.withOpacity(0.1),
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
