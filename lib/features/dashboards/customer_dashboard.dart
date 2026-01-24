import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../data/wallet/models.dart';
import '../../data/wallet/wallet_repo.dart';
import '../wallet/withdraw_request_screen.dart';
import '../wallet/widgets/balance_card.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final _repo = WalletRepo();
  final _scroll = ScrollController();

  final List<LedgerTx> _ledger = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _ledgerError;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _ledgerError = null;
      _ledger.clear();
      _lastDoc = null;
      _hasMore = true;
    });

    try {
      final page = await _repo.fetchLedgerPage(_uid);
      setState(() {
        _ledger.addAll(page.items);
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      setState(() => _ledgerError = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final startAfter = _lastDoc;
    if (startAfter == null) return;

    setState(() => _loadingMore = true);
    try {
      final page = await _repo.fetchLedgerPage(_uid, startAfter: startAfter);
      setState(() {
        _ledger.addAll(page.items);
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      // Keep UI usable; show error once.
      setState(() => _ledgerError ??= e.toString());
    } finally {
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(12),
          children: [
            StreamBuilder<WalletSnapshot?>(
              stream: _repo.streamWallet(_uid),
              builder: (context, snap) {
                final wallet = snap.data;
                final bal = wallet?.balanceCents ?? 0;
                return BalanceCard(balanceCents: bal, updatedAt: wallet?.updatedAt);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WithdrawRequestScreen()),
                  );
                  if (!mounted) return;
                  await _loadFirstPage();
                },
                icon: const Icon(Icons.request_page),
                label: const Text('Request Withdraw'),
              ),
            ),
            const SizedBox(height: 16),
            Text('Recent Transactions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_ledgerError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_ledgerError!, style: const TextStyle(color: Colors.red)),
              ),
            ..._ledger.map((tx) {
              final sign = tx.direction == 'OUT' ? '-' : '+';
              final amount = '$sign${MoneyEtb.formatCents(tx.amountCents)}';
              final when = tx.createdAt == null
                  ? ''
                  : '${tx.createdAt!.year.toString().padLeft(4, '0')}-${tx.createdAt!.month.toString().padLeft(2, '0')}-${tx.createdAt!.day.toString().padLeft(2, '0')}';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tx.type),
                subtitle: when.isEmpty ? null : Text(when),
                trailing: Text(amount),
              );
            }),
            if (_loadingMore) const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
            if (!_loading && _ledger.isEmpty && _ledgerError == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No transactions yet.')),
              ),
          ],
        ),
      ),
    );
  }
}
