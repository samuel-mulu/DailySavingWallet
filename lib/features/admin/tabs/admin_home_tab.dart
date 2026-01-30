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
