import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../core/settings/calendar_mode.dart';
import '../../../core/ui/app_header.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/error_state.dart';
import '../../../data/wallet/models.dart';
import '../../../data/wallet/wallet_repo.dart';
import '../../wallet/widgets/transaction_tile.dart';
import '../../wallet/withdraw_request_screen.dart';

class CustomerHomeTab extends StatefulWidget {
  const CustomerHomeTab({super.key});

  @override
  State<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

class _CustomerHomeTabState extends State<CustomerHomeTab> {
  final _repo = WalletRepo();
  CalendarModeService? _calendarService;

  @override
  void initState() {
    super.initState();
    _initCalendarService();
  }

  Future<void> _initCalendarService() async {
    final service = await CalendarModeService.getInstance();
    if (mounted) setState(() => _calendarService = service);
  }

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  String? get _userName => FirebaseAuth.instance.currentUser!.displayName;

  Stream<String?> _getCustomerId() {
    return FirebaseFirestore.instance
        .doc('users/$_uid')
        .snapshots()
        .map((doc) => doc.data()?['customerId'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    if (_calendarService == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ValueListenableBuilder<CalendarMode>(
      valueListenable: _calendarService!,
      builder: (context, mode, _) {
        return StreamBuilder<String?>(
          stream: _getCustomerId(),
          builder: (context, customerIdSnap) {
            if (customerIdSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final customerId = customerIdSnap.data;
            if (customerId == null) {
              return Column(
                children: [
                  AppHeader(
                    title: 'My Wallet',
                    subtitle: 'Welcome back ${_userName ?? ''}'.trim(),
                  ),
                  Expanded(
                    child: Center(
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
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                // Standard White Header
                AppHeader(
                  title: 'My Wallet',
                  subtitle: 'Welcome back ${_userName ?? ''}'.trim(),
                ),

                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF8B5CF6),
                    onRefresh: () async => setState(() {}),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        const SizedBox(height: 16),

                        // Modern Floating Balance Card
                        BalanceCard(customerId: customerId),

                        const SizedBox(height: 24),

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
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const WithdrawRequestScreen(),
                                  ),
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
                                    const SnackBar(
                                      content: Text('Go to History tab'),
                                    ),
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
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
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
                                message:
                                    'Your wallet activity will appear here.',
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
                                  for (final tx in items)
                                    TransactionTile(tx: tx, calendarMode: mode),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class BalanceCard extends StatefulWidget {
  final String customerId;
  const BalanceCard({super.key, required this.customerId});

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  final _repo = WalletRepo();
  bool _hideBalance = true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _repo.streamWalletDoc(widget.customerId),
      builder: (context, snap) {
        final doc = snap.data;
        final wallet = doc == null || !doc.exists
            ? null
            : WalletSnapshot.fromDoc(widget.customerId, doc);
        final balance = wallet?.balanceCents ?? 0;
        final isNegative = balance < 0;

        // Professional lighter palette
        final baseColor = isNegative
            ? const Color(0xFFEF5350)
            : const Color(0xFF0EA5E9);
        final accentColor = isNegative
            ? const Color(0xFFE57373)
            : const Color(0xFF2DD4BF);

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [baseColor, accentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: baseColor.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Subtle ornaments
                Positioned(
                  top: -20,
                  right: -20,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white.withOpacity(0.1),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white.withOpacity(0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isNegative
                                ? 'OUTSTANDING BALANCE'
                                : 'AVAILABLE BALANCE',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Glassmorphic Balance Area (Clean Layer)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _hideBalance = !_hideBalance),
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        _hideBalance
                                            ? '••••••'
                                            : MoneyEtb.formatCents(
                                                balance,
                                              ).replaceAll('ETB ', ''),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 40,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        _hideBalance
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: Colors.white.withOpacity(0.8),
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
