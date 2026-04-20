import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/ui/date_selector.dart';
import '../wallet/wallet_providers.dart';

class RecordDailySavingScreen extends ConsumerStatefulWidget {
  const RecordDailySavingScreen({super.key});

  @override
  ConsumerState<RecordDailySavingScreen> createState() =>
      _RecordDailySavingScreenState();
}

class _RecordDailySavingScreenState
    extends ConsumerState<RecordDailySavingScreen> {
  final _customerIdCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _paymentMethod = 'CASH';

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _customerIdCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _bankNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final customerId = _customerIdCtrl.text.trim();
      if (customerId.isEmpty) {
        throw const FormatException('Customer ID is required');
      }

      final cents = MoneyEtb.parseEtbToCents(_amountCtrl.text);
      final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
      final txDateMillis = dateToTxMillis(_selectedDate);

      ref.read(recordDailySavingMutationProvider.notifier).clear();
      await ref.read(recordDailySavingMutationProvider.notifier).submit((
        customerId: customerId,
        walletId: null,
        amountCents: cents,
        txDateMillis: txDateMillis,
        paymentMethod: _paymentMethod,
        bankName: _paymentMethod == 'MOBILE_BANKING'
            ? (_bankNameCtrl.text.trim().isEmpty
                  ? null
                  : _bankNameCtrl.text.trim())
            : null,
        note: note,
      ));
      final mutation = ref.read(recordDailySavingMutationProvider);
      if (mutation.error != null) {
        throw mutation.error!;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Daily saving recorded.')));
      Navigator.of(context).pop();
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Daily Saving')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _customerIdCtrl,
              decoration: const InputDecoration(labelText: 'Customer ID (uid)'),
            ),
            const SizedBox(height: 16),
            DateSelector(
              selectedDate: _selectedDate,
              onDateChanged: (date) => setState(() => _selectedDate = date),
              showQuickSelect: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount (ETB)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(
                  value: 'MOBILE_BANKING',
                  child: Text('Mobile Banking'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _paymentMethod = value);
              },
            ),
            if (_paymentMethod == 'MOBILE_BANKING') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _bankNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bank (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
