import 'package:flutter/material.dart';

import '../../../core/dates/date_formatters.dart';
import '../../../core/money/money.dart';
import '../../../core/settings/calendar_mode.dart';
import '../../../data/wallet/models.dart';
import 'transaction_details_sheet.dart';

class TransactionTile extends StatelessWidget {
  final LedgerTx tx;
  final CalendarMode? calendarMode;

  const TransactionTile({super.key, required this.tx, this.calendarMode});

  @override
  Widget build(BuildContext context) {
    final (icon, title, bgColor) = _metaForType(tx.type, context);
    final isOut = tx.direction == 'OUT';
    final sign = isOut ? '-' : '+';
    final amountText = '$sign${MoneyEtb.formatCents(tx.amountCents)}';
    final scheme = Theme.of(context).colorScheme;
    final amountColor = isOut
        ? scheme.error
        : const Color(0xFF2E7D32); // Green for income

    // Use txDate (business date) with fallback to createdAt (audit timestamp)
    final displayDate = tx.displayDate;
    final dateStr = displayDate == null
        ? ''
        : formatDateTime(
            displayDate,
            calendarMode ?? CalendarMode.gregorian,
            locale: 'am',
          );

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: bgColor,
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
          if (tx.balanceAfterCents != null) ...[
            const SizedBox(height: 2),
            Text(
              'Balance: ${MoneyEtb.formatCents(tx.balanceAfterCents!)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tx.balanceAfterCents! < 0
                    ? scheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      trailing: Text(
        amountText,
        style: TextStyle(
          color: amountColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      onTap: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => TransactionDetailsSheet(tx: tx),
      ),
    );
  }

  (IconData, String, Color) _metaForType(String type, BuildContext context) {
    switch (type) {
      case 'DAILY_PAYMENT':
        return (
          Icons.savings_outlined,
          'Daily Payment',
          const Color(0xFF2E7D32),
        ); // Green
      case 'DEPOSIT':
        return (
          Icons.add_circle_outline,
          'Deposit',
          const Color(0xFF1565C0),
        ); // Blue
      case 'WITHDRAW_REQUEST':
        return (
          Icons.request_page_outlined,
          'Withdraw Requested',
          const Color(0xFFF57C00),
        ); // Amber
      case 'WITHDRAW_APPROVE':
        return (
          Icons.check_circle_outline,
          'Withdraw Approved',
          const Color(0xFFC62828),
        ); // Red
      case 'WITHDRAW_REJECT':
        return (Icons.cancel_outlined, 'Withdraw Rejected', Colors.grey);
      case 'ADJUSTMENT':
        return (
          Icons.tune_outlined,
          'Adjustment',
          const Color(0xFF00897B),
        ); // Teal
      default:
        return (Icons.receipt_long_outlined, type, Colors.grey);
    }
  }
}
