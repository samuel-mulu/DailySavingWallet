import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/empty_state.dart';
import '../../../core/ui/error_state.dart';
import '../../../core/ui/quick_action_button.dart';
import '../../../data/wallet/models.dart';
import '../../../data/wallet/wallet_repo.dart';
import '../../wallet/withdraw_request_screen.dart';
import '../../wallet/widgets/balance_card.dart';
import '../../wallet/widgets/transaction_tile.dart';

class CustomerHomeTab extends StatefulWidget {
  const CustomerHomeTab({super.key});

  @override
  State<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

class _CustomerHomeTabState extends State<CustomerHomeTab> {
  final _repo = WalletRepo();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            StreamBuilder(
              stream: _repo.streamWalletDoc(_uid),
              builder: (context, snap) {
                final doc = snap.data;
                final wallet = doc == null || !doc.exists ? null : WalletSnapshot.fromDoc(_uid, doc);
                return BalanceCard(
                  balanceCents: wallet?.balanceCents ?? 0,
                  updatedAt: wallet?.updatedAt,
                  loading: snap.connectionState == ConnectionState.waiting,
                  isFromCache: doc?.metadata.isFromCache ?? false,
                );
              },
            ),
            const SizedBox(height: 12),
            QuickActionButton(
              icon: Icons.request_page,
              label: 'Request Withdraw',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WithdrawRequestScreen()),
              ),
            ),
            const SizedBox(height: 16),
            Text('Recent Transactions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder(
              future: _repo.fetchRecentLedger(_uid, limit: 5),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
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
      ),
    );
  }
}

