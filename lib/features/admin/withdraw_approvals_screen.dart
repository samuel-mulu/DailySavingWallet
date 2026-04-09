import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/money/money.dart';
import '../../data/customers/customer_repo.dart';
import '../../data/wallet/models.dart';
import '../../data/wallet/wallet_repo.dart';
import '../withdrawals/pending_withdrawals_provider.dart';

class WithdrawApprovalsScreen extends ConsumerStatefulWidget {
  const WithdrawApprovalsScreen({super.key});

  @override
  ConsumerState<WithdrawApprovalsScreen> createState() =>
      _WithdrawApprovalsScreenState();
}

class _WithdrawApprovalsScreenState
    extends ConsumerState<WithdrawApprovalsScreen> {
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

  Future<int?> _confirmApprove(WithdrawRequest r) async {
    final customer = await CustomerRepo().getCustomer(r.customerId);
    final walletSnap = await WalletRepo().fetchWallet(
      r.customerId,
      walletId: r.walletId,
    );
    if (!mounted) return null;

    final currentBalance = walletSnap?.balanceCents ?? 0;
    final ok = await showDialog<int?>(
      context: context,
      builder: (context) {
        final feeCtrl = TextEditingController(text: '0.00');
        return StatefulBuilder(
          builder: (context, setLocalState) {
            int feeCents;
            try {
              feeCents = MoneyEtb.parseEtbToCents(feeCtrl.text.trim());
            } on FormatException {
              feeCents = -1;
            }
            final totalDebit = r.amountCents + (feeCents < 0 ? 0 : feeCents);
            final afterBalance = currentBalance - totalDebit;
            final willBeNegative = afterBalance < 0;
            final limitCents = walletSnap?.creditLimitCents ?? 0;
            final debtCents = afterBalance < 0 ? -afterBalance : 0;
            final exceedsLimit = limitCents > 0 && debtCents > limitCents;

            return AlertDialog(
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
                  Text('Requested: ${MoneyEtb.formatCents(r.amountCents)}'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: feeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Approval fee (ETB)',
                      hintText: 'e.g. 10.50',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setLocalState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text('Total debit: ${MoneyEtb.formatCents(totalDebit)}'),
                  const SizedBox(height: 8),
                  Text('Reason: ${r.reason}'),
                  const SizedBox(height: 8),
                  Text('Current balance: ${MoneyEtb.formatCents(currentBalance)}'),
                  Text(
                    'After balance: ${MoneyEtb.formatCents(afterBalance)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: exceedsLimit
                          ? Colors.red
                          : (willBeNegative ? Colors.orange : Colors.green),
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
                                'Debt check',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            limitCents > 0
                                ? 'Credit limit: ${MoneyEtb.formatCents(limitCents)}'
                                : 'No credit limit (unlimited)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (limitCents > 0)
                            Text(
                              exceedsLimit
                                  ? 'Exceeds limit by ${MoneyEtb.formatCents(debtCents - limitCents)}'
                                  : 'Within limit',
                              style: TextStyle(
                                fontSize: 12,
                                color: exceedsLimit ? Colors.red : Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: (feeCents < 0 || exceedsLimit)
                      ? null
                      : () => Navigator.pop(context, feeCents),
                  style: willBeNegative
                      ? FilledButton.styleFrom(backgroundColor: Colors.orange)
                      : null,
                  child: const Text('Approve'),
                ),
              ],
            );
          },
        );
      },
    );
    return ok;
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
    final stale = ref.watch(pendingWithdrawalsStaleProvider);
    final items = stale.data ?? const <WithdrawRequest>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw Approvals')),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(pendingWithdrawalsStaleProvider.notifier).refresh(force: true),
        child: stale.data == null && stale.isRefreshing
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : stale.error != null && items.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: 120),
                  Center(child: Text(stale.error.toString())),
                ],
              )
            : items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No pending requests.')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
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
                                      final fee = await _confirmApprove(r);
                                      if (!mounted) return;
                                      if (fee == null) return;
                                      _setBusy(r.id, true);
                                      try {
                                        await _repo.approveWithdraw(
                                          r.id,
                                          idempotencyKey: _uuid.v4(),
                                          approvalFeeCents: fee,
                                        );
                                        ref
                                            .read(pendingWithdrawalsStaleProvider.notifier)
                                            .removeById(r.id);
                                        unawaited(
                                          ref
                                              .read(pendingWithdrawalsStaleProvider.notifier)
                                              .refresh(force: true),
                                        );
                                        _snack('Approved.');
                                      } catch (e) {
                                        await ref
                                            .read(pendingWithdrawalsStaleProvider.notifier)
                                            .refresh(force: true);
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
                                        ref
                                            .read(pendingWithdrawalsStaleProvider.notifier)
                                            .removeById(r.id);
                                        unawaited(
                                          ref
                                              .read(pendingWithdrawalsStaleProvider.notifier)
                                              .refresh(force: true),
                                        );
                                        _snack('Rejected.');
                                      } catch (e) {
                                        await ref
                                            .read(pendingWithdrawalsStaleProvider.notifier)
                                            .refresh(force: true);
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
              ),
      ),
    );
  }
}

