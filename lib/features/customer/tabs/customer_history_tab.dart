import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../data/wallet/models.dart';
import '../../../data/wallet/wallet_repo.dart';
import '../../wallet/widgets/transaction_tile.dart';

class CustomerHistoryTab extends StatefulWidget {
  const CustomerHistoryTab({super.key});

  @override
  State<CustomerHistoryTab> createState() => _CustomerHistoryTabState();
}

class _CustomerHistoryTabState extends State<CustomerHistoryTab> {
  final _repo = WalletRepo();
  final _scroll = ScrollController();

  final List<LedgerTx> _ledger = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _customerId;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _initCustomerId();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _initCustomerId() async {
    final doc = await FirebaseFirestore.instance.doc('users/$_uid').get();
    final customerId = doc.data()?['customerId'] as String?;
    if (mounted) {
      setState(() => _customerId = customerId);
      if (customerId != null) {
        _loadFirstPage();
      }
    }
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    if (_customerId == null) return;
    
    setState(() {
      _loading = true;
      _error = null;
      _ledger.clear();
      _lastDoc = null;
      _hasMore = true;
    });

    try {
      final page = await _repo.fetchLedgerPage(_customerId!);
      setState(() {
        _ledger.addAll(page.items);
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_customerId == null) return;
    final startAfter = _lastDoc;
    if (startAfter == null) return;

    setState(() => _loadingMore = true);
    try {
      final page = await _repo.fetchLedgerPage(_customerId!, startAfter: startAfter);
      setState(() {
        _ledger.addAll(page.items);
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      setState(() => _error ??= e.toString());
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(12),
          children: [
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (!_loading && _ledger.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No transactions yet.')),
              ),
            Card(
              child: Column(
                children: [
                  for (final tx in _ledger) TransactionTile(tx: tx),
                ],
              ),
            ),
            if (_loadingMore)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

