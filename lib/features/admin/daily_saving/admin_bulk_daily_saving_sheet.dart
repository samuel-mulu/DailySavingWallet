import 'dart:async';

import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates/date_formatters.dart';
import '../../../core/settings/calendar_mode.dart';
import '../../../core/money/money.dart';
import '../../../core/ui/date_selector.dart';
import '../../../data/wallet/models.dart';
import '../../wallet/wallet_providers.dart';

enum BulkDailyDateStatus { success, skippedAlreadyRecorded, failed }

class BulkDailyDateResult {
  final DateTime date;
  final BulkDailyDateStatus status;
  final String? error;

  const BulkDailyDateResult({
    required this.date,
    required this.status,
    this.error,
  });
}

Future<void> showAdminBulkDailySavingSheet({
  required BuildContext context,
  required String customerId,
  required String customerName,
  required CustomerWallet wallet,
  required Future<void> Function(WalletSnapshot? updatedSnapshot)
  onWalletUpdated,
  required VoidCallback onRefreshAfterBatch,
  VoidCallback? onOpenCustomerDetail,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AdminBulkDailySavingSheet(
      customerId: customerId,
      customerName: customerName,
      wallet: wallet,
      onWalletUpdated: onWalletUpdated,
      onRefreshAfterBatch: onRefreshAfterBatch,
      onOpenCustomerDetail: onOpenCustomerDetail,
    ),
  );
}

class _AdminBulkDailySavingSheet extends ConsumerStatefulWidget {
  const _AdminBulkDailySavingSheet({
    required this.customerId,
    required this.customerName,
    required this.wallet,
    required this.onWalletUpdated,
    required this.onRefreshAfterBatch,
    required this.onOpenCustomerDetail,
  });

  final String customerId;
  final String customerName;
  final CustomerWallet wallet;
  final Future<void> Function(WalletSnapshot? updatedSnapshot) onWalletUpdated;
  final VoidCallback onRefreshAfterBatch;
  final VoidCallback? onOpenCustomerDetail;

  @override
  ConsumerState<_AdminBulkDailySavingSheet> createState() =>
      _AdminBulkDailySavingSheetState();
}

class _AdminBulkDailySavingSheetState
    extends ConsumerState<_AdminBulkDailySavingSheet> {
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _bankNameCtrl = TextEditingController();
  final Set<String> _selectedIsoDays = <String>{};
  final Map<String, Set<String>> _recordedByMonth = <String, Set<String>>{};
  final Set<String> _monthsLoading = <String>{};
  DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  bool _loadingRecorded = false;
  bool _running = false;
  int _processed = 0;
  int _total = 0;
  String? _currentIso;
  final List<BulkDailyDateResult> _results = <BulkDailyDateResult>[];
  int _totalAddedCents = 0;
  int? _finalBalanceCents;
  late int _currentBalanceCents;
  CalendarModeService? _calendarModeService;
  String _paymentMethod = 'CASH';

  @override
  void initState() {
    super.initState();
    _currentBalanceCents = widget.wallet.balanceCents;
    CalendarModeService.getInstance().then((service) {
      if (mounted) {
        setState(() => _calendarModeService = service);
      }
    });
    unawaited(_loadRecordedMonth(_monthKey(_visibleMonth)));
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _bankNameCtrl.dispose();
    super.dispose();
  }

  /// Single GET for one `yyyy-MM` bucket; no UI state.
  Future<Set<String>> _fetchRecordedDaysForMonth(String month) async {
    final res = await ref.read(
      recordedDailyDaysByMonthProvider((
        customerId: widget.customerId,
        walletId: widget.wallet.id,
        month: month,
      )).future,
    );
    return Set<String>.from(res.recordedTxDays);
  }

  Future<void> _loadRecordedMonth(String month) async {
    if (_recordedByMonth.containsKey(month)) return;
    if (_monthsLoading.contains(month)) return;

    _monthsLoading.add(month);
    if (_monthsLoading.length == 1 && mounted) {
      setState(() => _loadingRecorded = true);
    }

    try {
      final days = await _fetchRecordedDaysForMonth(month);
      if (!mounted) return;
      _recordedByMonth[month] = days;
      _maybePreselectToday();
    } finally {
      _monthsLoading.remove(month);
      if (mounted) {
        setState(() {
          _loadingRecorded = _monthsLoading.isNotEmpty;
        });
      }
    }
  }

  /// Refreshes all months in [months] in parallel before bulk POSTs (no loading bar).
  Future<void> _prefetchMonthsForBatch(Set<String> months) async {
    if (months.isEmpty) return;
    final entries = await Future.wait(
      months.map((m) async => MapEntry(m, await _fetchRecordedDaysForMonth(m))),
    );
    if (!mounted) return;
    setState(() {
      for (final e in entries) {
        _recordedByMonth[e.key] = e.value;
      }
    });
  }

  void _maybePreselectToday() {
    // Default-pick today once, only if it's not already recorded.
    final today = DateTime.now();
    final todayIso = _isoDay(today);
    final month = _monthKey(today);
    final recorded = _recordedByMonth[month];
    if (recorded == null) return;
    final alreadyRecorded = recorded.contains(todayIso);
    if (alreadyRecorded || _selectedIsoDays.isNotEmpty) return;
    _selectedIsoDays.add(todayIso);
  }

  Future<void> _runBatch() async {
    if (_selectedIsoDays.isEmpty || _running) return;
    setState(() {
      _running = true;
      _results.clear();
      _processed = 0;
      _total = _selectedIsoDays.length;
      _currentIso = null;
      _totalAddedCents = 0;
      _finalBalanceCents = null;
    });

    final selected = _selectedIsoDays.toList()..sort();
    final months = selected.map((d) => d.substring(0, 7)).toSet();
    await _prefetchMonthsForBatch(months);

    final pending = <String>[];
    for (final iso in selected) {
      final month = iso.substring(0, 7);
      if ((_recordedByMonth[month] ?? const <String>{}).contains(iso)) {
        _results.add(
          BulkDailyDateResult(
            date: DateTime.parse('${iso}T12:00:00.000Z').toLocal(),
            status: BulkDailyDateStatus.skippedAlreadyRecorded,
          ),
        );
      } else {
        pending.add(iso);
      }
    }

    WalletSnapshot? lastSuccessful;
    for (final iso in pending) {
      setState(() {
        _currentIso = iso;
      });
      try {
        ref.read(recordDailySavingMutationProvider.notifier).clear();
        await ref.read(recordDailySavingMutationProvider.notifier).submit((
          customerId: widget.customerId,
          walletId: widget.wallet.id,
          amountCents: widget.wallet.dailyTargetCents,
          txDateMillis: dateToTxMillis(
            DateTime.parse('${iso}T12:00:00.000Z').toLocal(),
          ),
          paymentMethod: _paymentMethod,
          bankName: _paymentMethod == 'MOBILE_BANKING'
              ? (_bankNameCtrl.text.trim().isEmpty
                    ? null
                    : _bankNameCtrl.text.trim())
              : null,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        ));
        final mutation = ref.read(recordDailySavingMutationProvider);
        if (mutation.error != null) {
          throw mutation.error!;
        }
        final snap = mutation.data;
        lastSuccessful = snap ?? lastSuccessful;
        _totalAddedCents += widget.wallet.dailyTargetCents;
        _results.add(
          BulkDailyDateResult(
            date: DateTime.parse('${iso}T12:00:00.000Z').toLocal(),
            status: BulkDailyDateStatus.success,
          ),
        );
        _recordedByMonth
            .putIfAbsent(iso.substring(0, 7), () => <String>{})
            .add(iso);
      } catch (e) {
        final message = '$e';
        final skipped =
            message.contains('already exists') || message.contains('CONFLICT');
        _results.add(
          BulkDailyDateResult(
            date: DateTime.parse('${iso}T12:00:00.000Z').toLocal(),
            status: skipped
                ? BulkDailyDateStatus.skippedAlreadyRecorded
                : BulkDailyDateStatus.failed,
            error: skipped ? null : message,
          ),
        );
      } finally {
        setState(() {
          _processed += 1;
        });
      }
    }

    _finalBalanceCents = lastSuccessful?.balanceCents;
    await widget.onWalletUpdated(lastSuccessful);
    widget.onRefreshAfterBatch();
    if (!mounted) return;
    setState(() {
      if (lastSuccessful != null) {
        _currentBalanceCents = lastSuccessful.balanceCents;
      }
      _running = false;
      _currentIso = null;
      _selectedIsoDays
        ..clear()
        ..addAll(
          _results
              .where((r) => r.status == BulkDailyDateStatus.failed)
              .map((r) => _isoDay(r.date)),
        );
    });
    _showResultSheet();
  }

  void _showResultSheet() {
    final success = _results
        .where((r) => r.status == BulkDailyDateStatus.success)
        .length;
    final skipped = _results
        .where((r) => r.status == BulkDailyDateStatus.skippedAlreadyRecorded)
        .length;
    final failed = _results
        .where((r) => r.status == BulkDailyDateStatus.failed)
        .length;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${widget.customerName} • ${widget.wallet.label}'),
              const SizedBox(height: 8),
              Text(
                'Daily amount: ${MoneyEtb.formatCents(widget.wallet.dailyTargetCents)}',
              ),
              Text('Success: $success • Skipped: $skipped • Failed: $failed'),
              Text('Total added: ${MoneyEtb.formatCents(_totalAddedCents)}'),
              if (_finalBalanceCents != null)
                Text(
                  'Final balance: ${MoneyEtb.formatCents(_finalBalanceCents!)}',
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final r = _results[index];
                    final status = switch (r.status) {
                      BulkDailyDateStatus.success => 'success',
                      BulkDailyDateStatus.skippedAlreadyRecorded => 'skipped',
                      BulkDailyDateStatus.failed => 'failed',
                    };
                    return ListTile(
                      dense: true,
                      title: Text(_isoDay(r.date)),
                      subtitle: r.error == null
                          ? Text(status)
                          : Text('$status • ${r.error}'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.onOpenCustomerDetail == null
                          ? null
                          : () {
                              Navigator.of(ctx).pop();
                              widget.onOpenCustomerDetail!.call();
                            },
                      child: const Text('Open customer detail / history'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_calendarModeService == null) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ValueListenableBuilder<CalendarMode>(
      valueListenable: _calendarModeService!,
      builder: (context, mode, _) => _buildForMode(context, mode),
    );
  }

  Widget _buildForMode(BuildContext context, CalendarMode mode) {
    final days = _monthGridDays(_visibleMonth);
    final month = _monthKey(_visibleMonth);
    final recorded = _recordedByMonth[month] ?? const <String>{};
    final selectedDates = _selectedIsoDays.toList()..sort();
    final success = _results
        .where((r) => r.status == BulkDailyDateStatus.success)
        .length;
    final skipped = _results
        .where((r) => r.status == BulkDailyDateStatus.skippedAlreadyRecorded)
        .length;
    final failed = _results
        .where((r) => r.status == BulkDailyDateStatus.failed)
        .length;
    final selectedTotalCents =
        widget.wallet.dailyTargetCents * _selectedIsoDays.length;
    final projectedBalanceCents = _currentBalanceCents + selectedTotalCents;
    final headerLabel = mode == CalendarMode.ethiopian
        ? _ethiopianMonthHeader(_visibleMonth)
        : month;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bulk Daily Saving',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('${widget.customerName} • ${widget.wallet.label}'),
              Text(
                'Amount per date: ${MoneyEtb.formatCents(widget.wallet.dailyTargetCents)}',
              ),
              Text(
                'Current balance: ${MoneyEtb.formatCents(_currentBalanceCents)}',
              ),
              Text(
                'Balance after selected saving: ${MoneyEtb.formatCents(projectedBalanceCents)}',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _running
                        ? null
                        : () {
                            final prev = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month - 1,
                              1,
                            );
                            setState(() => _visibleMonth = prev);
                            unawaited(_loadRecordedMonth(_monthKey(prev)));
                          },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(child: Center(child: Text(headerLabel))),
                  IconButton(
                    onPressed: _running
                        ? null
                        : () {
                            final next = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month + 1,
                              1,
                            );
                            setState(() => _visibleMonth = next);
                            unawaited(_loadRecordedMonth(_monthKey(next)));
                          },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.1,
                ),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final d = days[index];
                  if (d == null) return const SizedBox.shrink();
                  final iso = _isoDay(d);
                  final isRecorded = recorded.contains(iso);
                  final selected = _selectedIsoDays.contains(iso);
                  return Padding(
                    padding: const EdgeInsets.all(2),
                    child: InkWell(
                      onTap: _running || isRecorded
                          ? null
                          : () {
                              setState(() {
                                if (selected) {
                                  _selectedIsoDays.remove(iso);
                                } else {
                                  _selectedIsoDays.add(iso);
                                }
                              });
                            },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: isRecorded
                              ? Colors.grey.shade300
                              : selected
                              ? Colors.green.shade100
                              : null,
                          border: Border.all(
                            color: selected
                                ? Colors.green
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            mode == CalendarMode.ethiopian
                                ? '${d.convertToEthiopian().day}'
                                : '${d.day}',
                            style: TextStyle(
                              color: isRecorded ? Colors.grey.shade700 : null,
                              decoration: isRecorded
                                  ? TextDecoration.lineThrough
                                  : null,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_loadingRecorded) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: selectedDates
                    .map(
                      (d) => Chip(
                        label: Text(
                          mode == CalendarMode.ethiopian
                              ? formatDateTime(
                                  DateTime.parse(
                                    '${d}T12:00:00.000Z',
                                  ).toLocal(),
                                  mode,
                                  locale: 'am',
                                )
                              : d,
                        ),
                        onDeleted: _running
                            ? null
                            : () => setState(() => _selectedIsoDays.remove(d)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'Selected: ${_selectedIsoDays.length} • Total: ${MoneyEtb.formatCents(widget.wallet.dailyTargetCents * _selectedIsoDays.length)}',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                enabled: !_running,
                decoration: const InputDecoration(
                  labelText: 'Shared note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
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
                onChanged: _running
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _paymentMethod = value);
                      },
              ),
              if (_paymentMethod == 'MOBILE_BANKING') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _bankNameCtrl,
                  enabled: !_running,
                  decoration: const InputDecoration(
                    labelText: 'Bank (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_running) ...[
                const SizedBox(height: 12),
                Text(
                  'Progress $_processed/$_total • Current: ${_currentIso == null ? '-' : _formatIso(_currentIso!, mode)}',
                ),
                LinearProgressIndicator(
                  value: _total == 0 ? 0 : (_processed / _total).clamp(0, 1),
                ),
                Text('Success: $success • Skipped: $skipped • Failed: $failed'),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _running || _selectedIsoDays.isEmpty
                    ? null
                    : _runBatch,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run bulk daily saving'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _monthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

String _isoDay(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

List<DateTime?> _monthGridDays(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final total = DateTime(month.year, month.month + 1, 0).day;
  final offset = first.weekday % 7;
  final out = <DateTime?>[];
  for (var i = 0; i < offset; i += 1) {
    out.add(null);
  }
  for (var day = 1; day <= total; day += 1) {
    out.add(DateTime(month.year, month.month, day));
  }
  return out;
}

String _ethiopianMonthHeader(DateTime gregorianMonth) {
  final eth = gregorianMonth.convertToEthiopian();
  return '${eth.month}/${eth.year}';
}

String _formatIso(String iso, CalendarMode mode) {
  if (mode == CalendarMode.gregorian) return iso;
  final date = DateTime.parse('${iso}T12:00:00.000Z').toLocal();
  return formatDateTime(date, mode, locale: 'am');
}
