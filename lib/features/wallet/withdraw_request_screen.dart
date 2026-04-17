import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/mutation_state.dart';
import '../../core/money/money.dart';
import '../../data/wallet/models.dart';
import 'wallet_providers.dart';

class WithdrawRequestScreen extends ConsumerStatefulWidget {
  final String? customerId;
  final String? walletId;
  const WithdrawRequestScreen({super.key, this.customerId, this.walletId});

  @override
  ConsumerState<WithdrawRequestScreen> createState() =>
      _WithdrawRequestScreenState();
}

class _WithdrawRequestScreenState extends ConsumerState<WithdrawRequestScreen> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  Timer? _previewDebounce;
  String? _localError;

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
    if (_localError != null) {
      setState(() => _localError = null);
    }

    final text = _amountCtrl.text.trim();
    if (text.isEmpty) {
      setState(() {});
      return;
    }

    final amountCents = _tryParseAmountCents();
    if (amountCents == null) {
      setState(() {});
      return;
    }

    setState(() {});

    _previewDebounce = Timer(
      const Duration(milliseconds: 300),
      () => ref.read(withdrawPreviewProvider(amountCents).notifier).refresh(),
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

  Future<void> _submit() async {
    setState(() => _localError = null);
    ref.read(withdrawSubmitMutationProvider.notifier).clear();

    try {
      final cents = MoneyEtb.parseEtbToCents(_amountCtrl.text);
      final reason = _reasonCtrl.text.trim();
      if (reason.isEmpty) throw const FormatException('Reason is required');
      final previewState = ref.read(withdrawPreviewProvider(cents));
      final preview = previewState.data ?? WithdrawPreview.calculate(cents);
      if (!mounted) return;

      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm withdraw request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Requested amount: ${MoneyEtb.formatCents(preview.requestedAmountCents)}',
              ),
              const SizedBox(height: 8),
              Text('Fee deducted: ${MoneyEtb.formatCents(preview.feeCents)}'),
              const SizedBox(height: 8),
              Text(
                'Net payout: ${MoneyEtb.formatCents(preview.netPayoutCents)}',
              ),
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
      await ref.read(withdrawSubmitMutationProvider.notifier).submit((
        customerId: widget.customerId,
        walletId: widget.walletId,
        amountCents: cents,
        reason: reason,
      ));
    } on FormatException catch (e) {
      if (mounted) setState(() => _localError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MutationState<String?>>(withdrawSubmitMutationProvider, (
      previous,
      next,
    ) {
      if (!mounted) return;
      final prevLoading = previous?.isLoading ?? false;
      if (prevLoading && !next.isLoading && next.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Withdraw request submitted.')),
        );
        Navigator.of(context).pop();
      }
    });
    final amountCents = _tryParseAmountCents();
    final previewState = amountCents == null
        ? null
        : ref.watch(withdrawPreviewProvider(amountCents));
    final preview = previewState?.data;
    final previewBusy = previewState?.isRefreshing ?? false;
    final submitState = ref.watch(withdrawSubmitMutationProvider);
    final submitError = submitState.error;
    final errorText = _localError ?? submitError?.toString();

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
                'Fee uses the exact 1/30 rule and is deducted from requested amount.',
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
                      label: 'Requested amount',
                      value: MoneyEtb.formatCents(preview.requestedAmountCents),
                    ),
                    const SizedBox(height: 8),
                    _PreviewRow(
                      label: 'Fee deducted',
                      value: MoneyEtb.formatCents(preview.feeCents),
                    ),
                    const SizedBox(height: 8),
                    _PreviewRow(
                      label: 'Net payout',
                      value: MoneyEtb.formatCents(preview.netPayoutCents),
                      emphasize: true,
                    ),
                    if (previewBusy) ...[
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
            if (errorText != null)
              Text(errorText, style: const TextStyle(color: Colors.red)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: submitState.isLoading ? null : _submit,
                child: submitState.isLoading
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
