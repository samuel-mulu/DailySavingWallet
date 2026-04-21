import 'package:flutter/material.dart';

import '../../../core/dates/date_formatters.dart';
import '../../../core/money/money.dart';
import '../../../core/settings/calendar_mode.dart';
import '../../../data/wallet/models.dart';

class TransactionDetailsSheet extends StatelessWidget {
  final LedgerTx tx;
  final CalendarMode calendarMode;

  const TransactionDetailsSheet({
    super.key,
    required this.tx,
    this.calendarMode = CalendarMode.gregorian,
  });

  @override
  Widget build(BuildContext context) {
    final meta = tx.meta ?? const {};
    final savingDay = tx.txDate == null
        ? '—'
        : formatTxDay(toTxDay(tx.txDate!.toUtc()), calendarMode, locale: 'am');
    final recorded = tx.createdAt == null
        ? '—'
        : '${formatInstantDate(tx.createdAt!, calendarMode, locale: 'am')} · '
            '${formatEatTime(tx.createdAt!)}';

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
              _row(
                'Balance After',
                MoneyEtb.formatCents(tx.balanceAfterCents!),
              ),
            _row('Saving day', savingDay),
            _row('Recorded', recorded),
            _row('By', tx.createdByUid.isEmpty ? '—' : tx.createdByUid),
            _row(
              'Payment',
              tx.paymentMethod == 'MOBILE_BANKING'
                  ? 'Mobile Banking'
                  : 'Cash',
            ),
            if ((tx.bankName ?? '').trim().isNotEmpty)
              _row('Bank', tx.bankName!.trim()),
            if ((tx.expenseReason ?? '').trim().isNotEmpty)
              _row('Expense reason', tx.expenseReason!.trim()),
            if (meta.isNotEmpty) ...[
              if (tx.type == 'WITHDRAW_APPROVE') ...[
                const SizedBox(height: 8),
                Text(
                  'Withdrawal Approval',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _row(
                  'Requested amount',
                  MoneyEtb.formatCents(_toInt(meta['requestedAmountCents'])),
                ),
                if (meta['approvedAmountCents'] != null)
                  _row(
                    'Approved',
                    MoneyEtb.formatCents(_toInt(meta['approvedAmountCents'])),
                  ),
                _row(
                  'Fee deducted',
                  MoneyEtb.formatCents(_toInt(meta['approvalFeeCents'])),
                ),
                _row(
                  'Net payout',
                  MoneyEtb.formatCents(_toInt(meta['netPayoutCents'])),
                ),
              ],
              const SizedBox(height: 12),
              Text('Meta', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final e in meta.entries)
                _row(e.key, e.value?.toString() ?? '—'),
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
          SizedBox(
            width: 110,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
