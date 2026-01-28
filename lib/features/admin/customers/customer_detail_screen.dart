import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/money/money.dart';
import '../../../core/ui/date_selector.dart';
import '../../../data/customers/customer_model.dart';
import '../../../data/customers/customer_repo.dart';
import '../../../data/wallet/models.dart';
import '../../../data/wallet/wallet_repo.dart';
import '../../wallet/widgets/transaction_tile.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final _uuid = const Uuid();
  
  @override
  Widget build(BuildContext context) {
    final customerRepo = CustomerRepo();
    final walletRepo = WalletRepo();

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Details')),
      body: StreamBuilder<Customer?>(
        stream: customerRepo.streamCustomer(widget.customerId),
        builder: (context, custSnap) {
          if (custSnap.hasError) {
            return Center(child: Text('Error: ${custSnap.error}'));
          }

          if (!custSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final customer = custSnap.data;
          if (customer == null) {
            return const Center(child: Text('Customer not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              customer.fullName.isNotEmpty
                                  ? customer.fullName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer.fullName,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  customer.companyName,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _InfoRow(icon: Icons.phone, label: 'Phone', value: customer.phone),
                      const SizedBox(height: 8),
                      _InfoRow(icon: Icons.location_on, label: 'Address', value: customer.address),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.savings,
                        label: 'Daily Target',
                        value: MoneyEtb.formatCents(customer.dailyTargetCents),
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.credit_card,
                        label: 'Credit Limit',
                        value: customer.creditLimitCents == 0
                            ? 'Unlimited'
                            : MoneyEtb.formatCents(customer.creditLimitCents),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Wallet Balance Card
              StreamBuilder(
                stream: walletRepo.streamWallet(widget.customerId),
                builder: (context, walletSnap) {
                  if (!walletSnap.hasData || walletSnap.data == null) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  final wallet = walletSnap.data!;
                  final isNegative = wallet.balanceCents < 0;

                  return Card(
                    color: isNegative
                        ? Theme.of(context).colorScheme.errorContainer
                        : Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wallet Balance',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: isNegative
                                      ? Theme.of(context).colorScheme.onErrorContainer
                                      : Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            MoneyEtb.formatCents(wallet.balanceCents),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isNegative
                                      ? Theme.of(context).colorScheme.onErrorContainer
                                      : Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                          ),
                          if (isNegative) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Customer has debt',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showRecordPayment(context, customer, 'DAILY_PAYMENT'),
                      icon: const Icon(Icons.savings),
                      label: const Text('Daily Saving'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showRecordPayment(context, customer, 'DEPOSIT'),
                      icon: const Icon(Icons.add_circle),
                      label: const Text('Deposit'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showRequestWithdraw(context, customer),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Request Withdraw'),
                ),
              ),
              const SizedBox(height: 24),

              // Transaction History
              Text(
                'Recent Transactions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<LedgerTx>>(
                future: walletRepo.fetchRecentLedger(widget.customerId, limit: 10),
                builder: (context, txSnap) {
                  if (txSnap.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: ${txSnap.error}'),
                      ),
                    );
                  }

                  if (!txSnap.hasData) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  final txs = txSnap.data!;
                  if (txs.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('No transactions yet')),
                      ),
                    );
                  }

                  return Card(
                    child: Column(
                      children: txs.map((tx) => TransactionTile(tx: tx)).toList(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRecordPayment(BuildContext context, Customer customer, String type) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(type == 'DAILY_PAYMENT' ? 'Record Daily Saving' : 'Record Deposit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date Selector
                DateSelector(
                  selectedDate: selectedDate,
                  onDateChanged: (date) => setDialogState(() => selectedDate = date),
                  showQuickSelect: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Amount (ETB)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final cents = MoneyEtb.parseEtbToCents(amountCtrl.text);
                  final note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
                  final txDateMillis = dateToTxMillis(selectedDate);

                  if (type == 'DAILY_PAYMENT') {
                    await WalletRepo().recordDailySaving(
                      customerId: customer.customerId,
                      amountCents: cents,
                      txDateMillis: txDateMillis,
                      note: note,
                      idempotencyKey: _uuid.v4(),
                    );
                  } else {
                    await WalletRepo().recordDeposit(
                      customerId: customer.customerId,
                      amountCents: cents,
                      txDateMillis: txDateMillis,
                      note: note,
                      idempotencyKey: _uuid.v4(),
                    );
                  }

                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment recorded successfully')),
                  );
                  setState(() {}); // Refresh
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestWithdraw(BuildContext context, Customer customer) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Withdraw'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount (ETB)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final cents = MoneyEtb.parseEtbToCents(amountCtrl.text);
                final reason = reasonCtrl.text.trim();
                
                if (reason.isEmpty) {
                  throw const FormatException('Reason is required');
                }

                await WalletRepo().requestWithdrawForCustomer(
                  customerId: customer.customerId,
                  amountCents: cents,
                  reason: reason,
                );

                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Withdraw request created')),
                );
                setState(() {}); // Refresh
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
