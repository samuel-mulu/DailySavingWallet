import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/money/money.dart';
import '../../core/ui/date_selector.dart';
import '../../data/wallet/wallet_repo.dart';

class RecordDailySavingScreen extends StatefulWidget {
  const RecordDailySavingScreen({super.key});

  @override
  State<RecordDailySavingScreen> createState() => _RecordDailySavingScreenState();
}

class _RecordDailySavingScreenState extends State<RecordDailySavingScreen> {
  final _customerIdCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _uuid = const Uuid();
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
      if (customerId.isEmpty) throw const FormatException('Customer ID is required');

      final cents = MoneyEtb.parseEtbToCents(_amountCtrl.text);
      final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
      final txDateMillis = dateToTxMillis(_selectedDate);

      await WalletRepo().recordDailySaving(
        customerId: customerId,
        amountCents: cents,
        txDateMillis: txDateMillis,
        note: note,
        idempotencyKey: _uuid.v4(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily saving recorded.')),
      );
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (ETB)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
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

