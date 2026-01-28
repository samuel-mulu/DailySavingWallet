import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/money/money.dart';
import '../../../core/ui/date_selector.dart';
import '../../../data/customers/customer_model.dart';
import '../../../data/customers/customer_repo.dart';
import '../../../data/wallet/wallet_repo.dart';

class AdminDailyCheckTab extends StatefulWidget {
  const AdminDailyCheckTab({super.key});

  @override
  State<AdminDailyCheckTab> createState() => _AdminDailyCheckTabState();
}

class _AdminDailyCheckTabState extends State<AdminDailyCheckTab> {
  final _searchCtrl = TextEditingController();
  final _uuid = const Uuid();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showPaymentModal(BuildContext context, Customer customer, String type) {
    final amountCtrl = TextEditingController(
      text: type == 'DAILY_PAYMENT'
          ? MoneyEtb.formatCents(customer.dailyTargetCents).replaceAll('ETB ', '')
          : '',
    );
    final noteCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: type == 'DAILY_PAYMENT'
                        ? Colors.green.shade100
                        : Colors.blue.shade100,
                    child: Icon(
                      type == 'DAILY_PAYMENT' ? Icons.savings : Icons.add_circle,
                      color: type == 'DAILY_PAYMENT'
                          ? Colors.green.shade700
                          : Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type == 'DAILY_PAYMENT' ? 'Daily Saving' : 'Deposit',
                          style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          customer.fullName,
                          style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(sheetContext).colorScheme.secondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Date Selector
              DateSelector(
                selectedDate: selectedDate,
                onDateChanged: (date) => setSheetState(() => selectedDate = date),
                showQuickSelect: true,
              ),
              const SizedBox(height: 16),

              // Amount
              TextField(
                controller: amountCtrl,
                decoration: InputDecoration(
                  labelText: 'Amount (ETB)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.attach_money),
                  helperText: type == 'DAILY_PAYMENT'
                      ? 'Daily target: ${MoneyEtb.formatCents(customer.dailyTargetCents)}'
                      : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 12),

              // Note
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Submit Button
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        setSheetState(() => busy = true);
                        
                        // Debug logging for daily saving
                        if (type == 'DAILY_PAYMENT') {
                          print('🟢 [Daily Saving] Starting submission...');
                          print('   Customer ID: ${customer.customerId}');
                          print('   Customer Name: ${customer.fullName}');
                          print('   Amount Text: ${amountCtrl.text}');
                          print('   Selected Date: $selectedDate');
                          print('   Note: ${noteCtrl.text}');
                        }
                        
                        try {
                          // Validate amount
                          if (amountCtrl.text.trim().isEmpty) {
                            throw FormatException('Amount is required');
                          }

                          final cents = MoneyEtb.parseEtbToCents(amountCtrl.text);
                          final note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
                          final txDateMillis = dateToTxMillis(selectedDate);

                          if (type == 'DAILY_PAYMENT') {
                            print('   Amount in cents: $cents');
                            print('   TxDate millis: $txDateMillis');
                            print('   Calling recordDailySaving...');
                            
                            await WalletRepo().recordDailySaving(
                              customerId: customer.customerId,
                              amountCents: cents,
                              txDateMillis: txDateMillis,
                              note: note,
                              idempotencyKey: _uuid.v4(),
                            );
                            
                            print('✅ [Daily Saving] Successfully recorded!');
                          } else {
                            await WalletRepo().recordDeposit(
                              customerId: customer.customerId,
                              amountCents: cents,
                              txDateMillis: txDateMillis,
                              note: note,
                              idempotencyKey: _uuid.v4(),
                            );
                          }

                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      type == 'DAILY_PAYMENT'
                                          ? '✓ Daily saving recorded for ${customer.fullName}'
                                          : '✓ Deposit recorded for ${customer.fullName}',
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.green.shade600,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        } on FormatException catch (e) {
                          setSheetState(() => busy = false);
                          
                          if (type == 'DAILY_PAYMENT') {
                            print('❌ [Daily Saving] FormatException: ${e.message}');
                          }
                          
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Invalid input: ${e.message}'),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.orange.shade700,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        } catch (e, stackTrace) {
                          setSheetState(() => busy = false);
                          
                          if (type == 'DAILY_PAYMENT') {
                            print('❌ [Daily Saving] Error occurred:');
                            print('   Error: $e');
                            print('   Stack trace: $stackTrace');
                          }
                          
                          if (!sheetContext.mounted) return;
                          
                          // Parse error message
                          String errorMessage = e.toString();
                          if (errorMessage.contains('permission-denied')) {
                            errorMessage = '🔒 Access denied. Admin permission required.';
                          } else if (errorMessage.contains('unauthenticated')) {
                            errorMessage = '🔑 Please log in again.';
                          } else if (errorMessage.contains('INTERNAL')) {
                            errorMessage = '⚠️ Server error. Please try again or contact support.';
                          } else if (errorMessage.length > 100) {
                            errorMessage = '❌ Operation failed. Check console for details.';
                          }
                          
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.error, color: Colors.white),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Error',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(errorMessage),
                                ],
                              ),
                              backgroundColor: Colors.red.shade700,
                              duration: const Duration(seconds: 6),
                              action: SnackBarAction(
                                label: 'Dismiss',
                                textColor: Colors.white,
                                onPressed: () {},
                              ),
                            ),
                          );
                        }
                      },
                icon: busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(type == 'DAILY_PAYMENT' ? Icons.savings : Icons.add_circle),
                label: Text(type == 'DAILY_PAYMENT' ? 'Record Daily Saving' : 'Record Deposit'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: type == 'DAILY_PAYMENT' ? Colors.green.shade600 : Colors.blue.shade600,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Check'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or company...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
              ),
            ),
          ),

          // Customer List
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: CustomerRepo().streamAllCustomers(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allCustomers = snap.data!;
                final customers = _searchQuery.isEmpty
                    ? allCustomers
                    : allCustomers.where((c) => c.matchesQuery(_searchQuery)).toList();

                if (customers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_search,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No customers yet' : 'No customers found',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            // Avatar
                            CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text(
                                customer.fullName.isNotEmpty
                                    ? customer.fullName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Customer Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${customer.companyName} • ${customer.phone}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  Text(
                                    'Target: ${MoneyEtb.formatCents(customer.dailyTargetCents)}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ),

                            // Action Buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Daily Saving Button
                                _ActionIconButton(
                                  icon: Icons.savings,
                                  color: Colors.green.shade600,
                                  tooltip: 'Daily Saving',
                                  onPressed: () => _showPaymentModal(context, customer, 'DAILY_PAYMENT'),
                                ),
                                const SizedBox(width: 4),
                                // Deposit Button
                                _ActionIconButton(
                                  icon: Icons.add_circle,
                                  color: Colors.blue.shade600,
                                  tooltip: 'Deposit',
                                  onPressed: () => _showPaymentModal(context, customer, 'DEPOSIT'),
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
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
