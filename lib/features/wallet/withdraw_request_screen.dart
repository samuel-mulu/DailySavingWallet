import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../data/wallet/models.dart';
import '../../data/wallet/wallet_repo.dart';

class WithdrawRequestScreen extends StatefulWidget {
  final String? customerId;
  final String? walletId;
  const WithdrawRequestScreen({super.key, this.customerId, this.walletId});

  @override
  State<WithdrawRequestScreen> createState() => _WithdrawRequestScreenState();
}

class _WithdrawRequestScreenState extends State<WithdrawRequestScreen> {
  final _repo = WalletRepo();
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  Timer? _previewDebounce;
  bool _busy = false;
  bool _previewBusy = false;
  String? _error;
  WithdrawPreview? _preview;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_handleAmountChanged);
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _handleAmountChanged() {
    _previewDebounce?.cancel();

    final text = _amountCtrl.text.trim();
    if (text.isEmpty) {
      setState(() {
        _preview = null;
        _previewBusy = false;
      });
      return;
    }

    final amountCents = _tryParseAmountCents();
    if (amountCents == null) {
      setState(() {
        _preview = null;
        _previewBusy = false;
      });
      return;
    }

    setState(() {
      _preview = WithdrawPreview.calculate(amountCents);
      _previewBusy = true;
    });

    _previewDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _syncPreview(amountCents),
    );
  }

  int? _tryParseAmountCents() {
    final text = _amountCtrl.text.trim();
    if (text.isEmpty) return null;
    try {
      return MoneyEtb.parseEtbToCents(text);
    } on FormatException {
      return null;
    }
  }

  Future<void> _syncPreview(int amountCents) async {
    try {
      final preview = await _repo.previewWithdraw(amountCents: amountCents);
      if (!mounted || _tryParseAmountCents() != amountCents) return;
      setState(() {
        _preview = preview;
        _previewBusy = false;
      });
    } catch (_) {
      if (!mounted || _tryParseAmountCents() != amountCents) return;
      setState(() => _previewBusy = false);
    }
  }

  Future<WithdrawPreview> _resolvePreview(int amountCents) async {
    final preview = _preview;
    if (preview != null && preview.amountCents == amountCents) {
      return preview;
    }

    try {
      return await _repo.previewWithdraw(amountCents: amountCents);
    } catch (_) {
      return WithdrawPreview.calculate(amountCents);
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    try {
      final cents = MoneyEtb.parseEtbToCents(_amountCtrl.text);
      final reason = _reasonCtrl.text.trim();
      if (reason.isEmpty) throw const FormatException('Reason is required');
      final preview = await _resolvePreview(cents);
      if (!mounted) return;

      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm withdraw request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount: ${MoneyEtb.formatCents(preview.amountCents)}'),
              const SizedBox(height: 8),
              Text('Fee: ${MoneyEtb.formatCents(preview.feeCents)}'),
              const SizedBox(height: 8),
              Text('Total: ${MoneyEtb.formatCents(preview.totalDebitCents)}'),
              const SizedBox(height: 8),
              Text('Reason: $reason'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;

      setState(() => _busy = true);
      try {
        if (widget.customerId != null && widget.customerId!.isNotEmpty) {
          await _repo.requestWithdrawForCustomer(
            customerId: widget.customerId!,
            walletId: widget.walletId,
            amountCents: cents,
            reason: reason,
          );
        } else {
          await _repo.requestWithdraw(amountCents: cents, reason: reason);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Withdraw request submitted.')),
        );
        Navigator.of(context).pop();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(title: const Text('Request Withdraw')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount (ETB)'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Fee uses the exact 1/30 rule. Example: 3000 -> 100.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (preview != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Withdrawal summary',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _PreviewRow(
                      label: 'Amount',
                      value: MoneyEtb.formatCents(preview.amountCents),
                    ),
                    const SizedBox(height: 8),
                    _PreviewRow(
                      label: 'Fee',
                      value: MoneyEtb.formatCents(preview.feeCents),
                    ),
                    const SizedBox(height: 8),
                    _PreviewRow(
                      label: 'Total',
                      value: MoneyEtb.formatCents(preview.totalDebitCents),
                      emphasize: true,
                    ),
                    if (_previewBusy) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                  ],
                ),
              ),
            ],
            if (_amountCtrl.text.trim().isNotEmpty &&
                _tryParseAmountCents() == null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Enter a valid amount',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason'),
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

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(value, style: style),
      ],
    );
  }
}
