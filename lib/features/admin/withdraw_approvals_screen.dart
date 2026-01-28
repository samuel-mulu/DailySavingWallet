import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/money/money.dart';
import '../../data/customers/customer_repo.dart';
import '../../data/wallet/models.dart';
import '../../data/wallet/wallet_repo.dart';

class WithdrawApprovalsScreen extends StatefulWidget {
  const WithdrawApprovalsScreen({super.key});

  @override
  State<WithdrawApprovalsScreen> createState() => _WithdrawApprovalsScreenState();
}

class _WithdrawApprovalsScreenState extends State<WithdrawApprovalsScreen> {
  final _repo = WalletRepo();
  final Set<String> _busyIds = {};
  final _uuid = const Uuid();

  bool _isBusy(String id) => _busyIds.contains(id);

  void _setBusy(String id, bool v) {
    setState(() {
      if (v) {
        _busyIds.add(id);
      } else {
        _busyIds.remove(id);
      }
    });
  }

  Future<bool> _confirmApprove(BuildContext context, WithdrawRequest r) async {
    // Fetch customer and wallet info
    final customer = await CustomerRepo().getCustomer(r.customerId);
    final walletSnap = await WalletRepo().streamWallet(r.customerId).first;
    
    final currentBalance = walletSnap?.balanceCents ?? 0;
    final afterBalance = currentBalance - r.amountCents;
    final willBeNegative = afterBalance < 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Withdraw'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer != null) ...[
              Text(
                customer.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(customer.companyName),
              const Divider(height: 16),
            ],
            Text('Amount: ${MoneyEtb.formatCents(r.amountCents)}'),
            const SizedBox(height: 8),
            Text('Reason: ${r.reason}'),
            const SizedBox(height: 8),
            Text('Current Balance: ${MoneyEtb.formatCents(currentBalance)}'),
            Text(
              'After Balance: ${MoneyEtb.formatCents(afterBalance)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: willBeNegative ? Colors.red : Colors.green,
              ),
            ),
            if (willBeNegative) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Will create debt',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (customer != null && customer.creditLimitCents > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Credit Limit: ${MoneyEtb.formatCents(customer.creditLimitCents)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      const Text(
                        'No credit limit (unlimited)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: willBeNegative
                ? FilledButton.styleFrom(backgroundColor: Colors.orange)
                : null,
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<String?> _askRejectNote(BuildContext context) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject request'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return res;
  }

  Future<bool> _confirmReject(BuildContext context, WithdrawRequest r, String? note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm reject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${r.customerId}'),
            const SizedBox(height: 8),
            Text('Amount: ${MoneyEtb.formatCents(r.amountCents)}'),
            const SizedBox(height: 8),
            Text('Reason: ${r.reason}'),
            if (note != null && note.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Note: ${note.trim()}'),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reject')),
        ],
      ),
    );
    return ok == true;
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw Approvals')),
      body: StreamBuilder<List<WithdrawRequest>>(
        stream: _repo.streamPendingWithdrawRequests(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString()));
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No pending requests.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = items[i];
              final busy = _isBusy(r.id);
              return Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: FutureBuilder(
                              future: CustomerRepo().getCustomer(r.customerId),
                              builder: (context, snap) {
                                final customer = snap.data;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer?.fullName ?? 'Loading...',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    if (customer != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        customer.companyName,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.secondary,
                                            ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                MoneyEtb.formatCents(r.amountCents),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                              ),
                              if (busy)
                                const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.message_outlined,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                r.reason,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final rootContext = this.context;
                                      final ok = await _confirmApprove(rootContext, r);
                                      if (!mounted) return;
                                      if (!ok) return;
                                      _setBusy(r.id, true);
                                      try {
                                        await _repo.approveWithdraw(r.id, idempotencyKey: _uuid.v4());
                                        _snack('Approved.');
                                      } catch (e) {
                                        _snack(e.toString());
                                      } finally {
                                        if (mounted) _setBusy(r.id, false);
                                      }
                                    },
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final note = await _askRejectNote(this.context);
                                      if (!mounted) return;
                                      if (note == null) return;

                                      final ok = await _confirmReject(this.context, r, note);
                                      if (!mounted) return;
                                      if (!ok) return;
                                      _setBusy(r.id, true);
                                      try {
                                        await _repo.rejectWithdraw(r.id, note: note);
                                        _snack('Rejected.');
                                      } catch (e) {
                                        _snack(e.toString());
                                      } finally {
                                        if (mounted) _setBusy(r.id, false);
                                      }
                                    },
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

