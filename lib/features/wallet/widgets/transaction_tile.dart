import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../data/wallet/models.dart';
import 'transaction_details_sheet.dart';

class TransactionTile extends StatelessWidget {
  final LedgerTx tx;
  const TransactionTile({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final (icon, title) = _metaForType(tx.type);
    final isOut = tx.direction == 'OUT';
    final sign = isOut ? '-' : '+';
    final amountText = '$sign${MoneyEtb.formatCents(tx.amountCents)}';
    final scheme = Theme.of(context).colorScheme;
    final amountColor = isOut ? scheme.error : scheme.primary;

    return ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      subtitle: Text(tx.createdAt?.toString() ?? ''),
      trailing: Text(amountText, style: TextStyle(color: amountColor, fontWeight: FontWeight.w700)),
      onTap: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => TransactionDetailsSheet(tx: tx),
      ),
    );
  }

  (IconData, String) _metaForType(String type) {
    switch (type) {
      case 'DAILY_PAYMENT':
        return (Icons.savings_outlined, 'Daily Payment');
      case 'DEPOSIT':
        return (Icons.add_circle_outline, 'Deposit');
      case 'WITHDRAW_REQUEST':
        return (Icons.request_page_outlined, 'Withdraw Requested');
      case 'WITHDRAW_APPROVE':
        return (Icons.check_circle_outline, 'Withdraw Approved');
      case 'WITHDRAW_REJECT':
        return (Icons.cancel_outlined, 'Withdraw Rejected');
      case 'ADJUSTMENT':
        return (Icons.tune_outlined, 'Adjustment');
      default:
        return (Icons.receipt_long_outlined, type);
    }
  }
}

