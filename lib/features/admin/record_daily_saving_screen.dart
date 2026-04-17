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
  DateTime _selectedDate = DateTime.now();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _customerIdCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final customerId = _customerIdCtrl.text.trim();
      if (customerId.isEmpty)
        throw const FormatException('Customer ID is required');

      final cents = MoneyEtb.parseEtbToCents(_amountCtrl.text);
      final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
      final txDateMillis = dateToTxMillis(_selectedDate);

      ref.read(recordDailySavingMutationProvider.notifier).clear();
      await ref.read(recordDailySavingMutationProvider.notifier).submit((
        customerId: customerId,
        walletId: null,
        amountCents: cents,
        txDateMillis: txDateMillis,
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
