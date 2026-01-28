import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../data/wallet/models.dart';

class TransactionDetailsSheet extends StatelessWidget {
  final LedgerTx tx;
  const TransactionDetailsSheet({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final meta = tx.meta ?? const {};
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _row('Type', tx.type),
            _row('Direction', tx.direction),
            _row('Amount', MoneyEtb.formatCents(tx.amountCents)),
            if (tx.balanceAfterCents != null)
              _row('Balance After', MoneyEtb.formatCents(tx.balanceAfterCents!)),
            _row('Transaction Date', _formatDate(tx.txDate)),
            _row('Created At', _formatDateTime(tx.createdAt)),
            _row('By', tx.createdByUid.isEmpty ? '—' : tx.createdByUid),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Meta', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final e in meta.entries) _row(e.key, e.value?.toString() ?? '—'),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '—';
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

