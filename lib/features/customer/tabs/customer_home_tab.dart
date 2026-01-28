import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../core/ui/app_header.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/error_state.dart';
import '../../../data/wallet/models.dart';
import '../../../data/wallet/wallet_repo.dart';
import '../../wallet/withdraw_request_screen.dart';
import '../../wallet/widgets/transaction_tile.dart';

class CustomerHomeTab extends StatefulWidget {
  const CustomerHomeTab({super.key});

  @override
  State<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

class _CustomerHomeTabState extends State<CustomerHomeTab> {
  final _repo = WalletRepo();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<String?> _getCustomerId() {
    return FirebaseFirestore.instance
        .doc('users/$_uid')
        .snapshots()
        .map((doc) => doc.data()?['customerId'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        const AppHeader(
          title: 'My Wallet',
          subtitle: 'Welcome back',
        ),
        
        // Content
        Expanded(
          child: StreamBuilder<String?>(
            stream: _getCustomerId(),
            builder: (context, customerIdSnap) {
              if (customerIdSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final customerId = customerIdSnap.data;
              if (customerId == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.link_off_rounded,
                            size: 40,
                            color: Color(0xFFC62828),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Profile Not Linked',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please contact your administrator to link your account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                color: const Color(0xFF8B5CF6),
                onRefresh: () async => setState(() {}),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Balance Card
                    StreamBuilder(
                      stream: _repo.streamWalletDoc(customerId),
                      builder: (context, snap) {
                        final doc = snap.data;
                        final wallet = doc == null || !doc.exists 
                            ? null 
                            : WalletSnapshot.fromDoc(customerId, doc);
                        final balance = wallet?.balanceCents ?? 0;
                        final isNegative = balance < 0;
                        
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isNegative
                                  ? [const Color(0xFFC62828), const Color(0xFFE53935)]
                                  : [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (isNegative 
                                    ? const Color(0xFFC62828) 
                                    : const Color(0xFF8B5CF6)).withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isNegative ? 'Outstanding Balance' : 'Available Balance',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              snap.connectionState == ConnectionState.waiting
                                  ? Container(
                                      height: 40,
                                      width: 150,
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    )
                                  : Text(
                                      MoneyEtb.formatCents(balance),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                              if (wallet?.updatedAt != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Updated: ${_formatDate(wallet!.updatedAt!)}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.request_page_rounded,
                            label: 'Request\nWithdraw',
                            color: const Color(0xFF8B5CF6),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const WithdrawRequestScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.history_rounded,
                            label: 'View\nHistory',
                            color: const Color(0xFF10B981),
                            onTap: () {
                              // Navigate to history tab would require a callback
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Go to History tab')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Recent Transactions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D2D2D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    FutureBuilder(
                      future: _repo.fetchRecentLedger(customerId, limit: 5),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          );
                        }
                        if (snap.hasError) {
                          return ErrorState(
                            title: 'Could not load transactions',
                            message: snap.error.toString(),
                            onRetry: () => setState(() {}),
                          );
                        }

                        final items = snap.data ?? const [];
                        if (items.isEmpty) {
                          return const EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'No transactions yet',
                            message: 'Your wallet activity will appear here.',
                          );
                        }

                        return Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              for (final tx in items) TransactionTile(tx: tx),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D2D2D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
