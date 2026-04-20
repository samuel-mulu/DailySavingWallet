import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/dates/date_formatters.dart';
import '../../../core/money/money.dart';
import '../../../core/settings/calendar_mode.dart';
import '../../../core/ui/date_selector.dart';
import '../../../data/wallet/models.dart';
import '../../wallet/wallet_providers.dart';
import '../../wallet/widgets/transaction_tile.dart';
import 'admin_reports_pdf.dart';

class AdminReportsTab extends ConsumerStatefulWidget {
  const AdminReportsTab({super.key});

  @override
  ConsumerState<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends ConsumerState<AdminReportsTab> {
  DateTime _selectedDate = DateTime.now();
  int _dailyReportNonce = 0;
  int _monthlyReportNonce = 0;
  bool _dailyPdfBusy = false;
  bool _monthlyPdfBusy = false;
  CalendarModeService? _calendarService;
  String _dailyPaymentMethod = 'ALL';

  @override
  void initState() {
    super.initState();
    CalendarModeService.getInstance().then((s) {
      if (mounted) setState(() => _calendarService = s);
    });
  }

  String get _txDay =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
  String get _month =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}';

  Future<void> _showCompanyRulesModal(BuildContext context) {
    const ruleItems = <String>[
      'ዕቁብ ዝኽፈለሉ ግዜ ሰምናዊ ቀዳም ካብ 10፡00-12:00።',
      'ዋሕስ ኮይኑ ዝፈረመ ናይ ዝተዋሓሰ ሰብ ቀጥተኛ ከፋሊ ዝኸውን ምኻኑ ክፈልጥ አለዎ።',
      'ናይ ዕቁብተኛ መሰል ሕልው አዩ።',
      'ቅድሚያ ንዝወስድ ቸክ የዛጋጅው',
    ];

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Company Rules',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < ruleItems.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle_outline, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ruleItems[i],
                        style: Theme.of(sheetContext).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
                if (i < ruleItems.length - 1) const SizedBox(height: 10),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.check),
                  label: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_calendarService == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ValueListenableBuilder<CalendarMode>(
      valueListenable: _calendarService!,
      builder: (context, calendarMode, _) {
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reports',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Company rules',
                      onPressed: () => _showCompanyRulesModal(context),
                      icon: const Icon(Icons.policy_outlined),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: DateSelector(
                  selectedDate: _selectedDate,
                  onDateChanged: (value) =>
                      setState(() => _selectedDate = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _CompanyWalletEntryCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _CompanyWalletReportPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const TabBar(
                tabs: [
                  Tab(text: 'Daily'),
                  Tab(text: 'Monthly'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async =>
                          setState(() => _dailyReportNonce++),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _StableReportFuture(
                            key: ValueKey<String>(
                              'd_${_txDay}_${_dailyPaymentMethod}_$_dailyReportNonce',
                            ),
                            load: () => ref.read(
                              dailySavingsActivityReportProvider(
                                DailyActivityReportQuery(
                                  txDay: _txDay,
                                  paymentMethod: _dailyPaymentMethod,
                                ),
                              ).future,
                            ),
                            builder: (context, snap) {
                              if (snap.hasError) {
                                return _ReportErrorCard(
                                  message: '${snap.error}',
                                  onRetry: () =>
                                      setState(() => _dailyReportNonce++),
                                );
                              }
                              if (snap.connectionState ==
                                      ConnectionState.waiting &&
                                  !snap.hasData) {
                                return const _ReportLoadingCard(
                                  title: 'Daily collections',
                                  accentColor: Color(0xFF10B981),
                                  icon: Icons.calendar_today_outlined,
                                );
                              }
                              final data =
                                  snap.data ?? const <String, dynamic>{};
                              return _ReportCard(
                                title: 'Daily collections',
                                accentColor: const Color(0xFF10B981),
                                icon: Icons.calendar_today_outlined,
                                body: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      initialValue: _dailyPaymentMethod,
                                      decoration: const InputDecoration(
                                        labelText: 'Payment Filter',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'ALL',
                                          child: Text('All'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'CASH',
                                          child: Text('Cash'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'MOBILE_BANKING',
                                          child: Text('Mobile Banking'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() {
                                          _dailyPaymentMethod = value;
                                          _dailyReportNonce++;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _DailyActivityReportSummary(data: data),
                                  ],
                                ),
                                isExporting: _dailyPdfBusy,
                                onViewDetail: () => _showDailyActivityDetail(
                                  context,
                                  data,
                                  calendarMode,
                                ),
                                onExportPdf: () =>
                                    _exportDailyActivityPdf(context, data),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: () async =>
                          setState(() => _monthlyReportNonce++),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _StableReportFuture(
                            key: ValueKey<String>(
                              'm_${_month}_$_monthlyReportNonce',
                            ),
                            load: () => ref.read(
                              monthlySavingsReportProvider(_month).future,
                            ),
                            builder: (context, snap) {
                              if (snap.hasError) {
                                return _ReportErrorCard(
                                  message: '${snap.error}',
                                  onRetry: () =>
                                      setState(() => _monthlyReportNonce++),
                                );
                              }
                              if (snap.connectionState ==
                                      ConnectionState.waiting &&
                                  !snap.hasData) {
                                return const _ReportLoadingCard(
                                  title: 'Monthly overview',
                                  accentColor: Color(0xFF0EA5E9),
                                  icon: Icons.calendar_month_outlined,
                                );
                              }
                              final data =
                                  snap.data ?? const <String, dynamic>{};
                              final daily =
                                  (data['daily'] as List?) ?? const <dynamic>[];
                              return _ReportCard(
                                title: 'Monthly overview',
                                accentColor: const Color(0xFF0EA5E9),
                                icon: Icons.calendar_month_outlined,
                                body: _MonthlyReportSummary(
                                  data: data,
                                  dayCount: daily.length,
                                  calendarMode: calendarMode,
                                ),
                                isExporting: _monthlyPdfBusy,
                                onViewDetail: () => _showMonthlyDetail(
                                  context,
                                  data,
                                  calendarMode,
                                ),
                                onExportPdf: () =>
                                    _exportMonthlyPdf(context, data),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatReportIsoDay(String iso, CalendarMode mode) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(iso)) return iso;
    return formatTxDay(iso, mode, locale: 'am');
  }

  Future<void> _exportDailyActivityPdf(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    if (_dailyPdfBusy) return;
    setState(() => _dailyPdfBusy = true);
    try {
      final bytes = await buildDailySavingsActivityReportPdf(
        data: data,
        generatedAt: DateTime.now(),
      );
      final day = '${data['activityDay'] ?? _txDay}'.replaceAll('-', '');
      if (!context.mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'daily-activity-$day.pdf',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily PDF is ready to download/share.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not download Daily PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _dailyPdfBusy = false);
    }
  }

  Future<void> _exportMonthlyPdf(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    if (_monthlyPdfBusy) return;
    setState(() => _monthlyPdfBusy = true);
    try {
      final bytes = await buildMonthlySavingsReportPdf(
        data: data,
        month: '${data['month'] ?? _month}',
        generatedAt: DateTime.now(),
      );
      final m = '${data['month'] ?? _month}'.replaceAll('-', '');
      if (!context.mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'monthly-overview-$m.pdf',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Monthly PDF is ready to download/share.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not download Monthly PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _monthlyPdfBusy = false);
    }
  }

  void _showDailyActivityDetail(
    BuildContext context,
    Map<String, dynamic> data,
    CalendarMode calendarMode,
  ) {
    final lines = _mapList(data['lines'])
      ..sort((a, b) {
        final n = '${a['customerName']}'.compareTo('${b['customerName']}');
        if (n != 0) return n;
        final d = '${a['coveredTxDay'] ?? ''}'.compareTo(
          '${b['coveredTxDay'] ?? ''}',
        );
        if (d != 0) return d;
        return '${a['walletLabel']}'.compareTo('${b['walletLabel']}');
      });
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Daily collections',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _dailyPdfBusy
                        ? null
                        : () => _exportDailyActivityPdf(sheetContext, data),
                    icon: _dailyPdfBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      _dailyPdfBusy ? 'Generating...' : 'Generate PDF',
                    ),
                  ),
                ],
              ),
              Text(
                _formatReportIsoDay(
                  '${data['activityDay'] ?? ''}',
                  calendarMode,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _DailyActivityReportSummary(data: data, compact: true),
              const SizedBox(height: 16),
              Text(
                'Payments (${lines.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 8),
              if (lines.isEmpty)
                Text(
                  'Nothing recorded for this day.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...lines.map(
                  (row) =>
                      _ActivityLineTile(row: row, calendarMode: calendarMode),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showMonthlyDetail(
    BuildContext context,
    Map<String, dynamic> data,
    CalendarMode calendarMode,
  ) {
    final daily = (data['daily'] as List?) ?? const [];
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Monthly overview',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _monthlyPdfBusy
                        ? null
                        : () => _exportMonthlyPdf(sheetContext, data),
                    icon: _monthlyPdfBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      _monthlyPdfBusy ? 'Generating...' : 'Generate PDF',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _MonthlyReportSummary(
                data: data,
                dayCount: daily.length,
                calendarMode: calendarMode,
                compact: true,
              ),
              const SizedBox(height: 16),
              Text(
                'By day',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (daily.isEmpty)
                Text(
                  'No data for this month.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < daily.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          dense: true,
                          title: Text(
                            _formatReportIsoDay(
                              '${daily[i]['txDay'] ?? ''}',
                              calendarMode,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${daily[i]['savedWalletCount'] ?? 0} wallet(s)',
                          ),
                          trailing: Text(
                            MoneyEtb.formatCents(
                              _toInt(daily[i]['totalSavedCents']),
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0EA5E9),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

/// Runs [load] once per [key] — avoids refetching on every parent rebuild.
class _StableReportFuture extends StatefulWidget {
  const _StableReportFuture({
    super.key,
    required this.load,
    required this.builder,
  });

  final Future<Map<String, dynamic>> Function() load;
  final AsyncWidgetBuilder<Map<String, dynamic>> builder;

  @override
  State<_StableReportFuture> createState() => _StableReportFutureState();
}

class _StableReportFutureState extends State<_StableReportFuture> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  void didUpdateWidget(covariant _StableReportFuture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.key != oldWidget.key) {
      _future = widget.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: widget.builder,
    );
  }
}

int _reportIntFromJson(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class _DailyActivityReportSummary extends StatelessWidget {
  const _DailyActivityReportSummary({required this.data, this.compact = false});

  final Map<String, dynamic> data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _reportIntFromJson(data['totalCollectedCents']);
    final paymentCount = _reportIntFromJson(data['paymentCount']);
    final pad = compact ? 12.0 : 0.0;

    final stats = <_StatItem>[
      _StatItem(
        'Customers',
        '${data['distinctCustomerCount'] ?? 0}',
        Icons.people_outline,
      ),
      _StatItem(
        'Wallets',
        '${data['distinctWalletCount'] ?? 0}',
        Icons.account_balance_wallet_outlined,
      ),
      _StatItem('Payments', '$paymentCount', Icons.receipt_long_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact) SizedBox(height: pad),
        Text(
          MoneyEtb.formatCents(total),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF059669),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Total collected',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: stats
              .map(
                (s) => Chip(
                  avatar: Icon(
                    s.icon,
                    size: 18,
                    color: const Color(0xFF047857),
                  ),
                  label: Text('${s.label}: ${s.value}'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _StatItem {
  const _StatItem(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class _MonthlyReportSummary extends StatelessWidget {
  const _MonthlyReportSummary({
    required this.data,
    required this.dayCount,
    required this.calendarMode,
    this.compact = false,
  });

  final Map<String, dynamic> data;
  final int dayCount;
  final CalendarMode calendarMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _reportIntFromJson(data['totalSavedCents']);
    final monthKey = '${data['month'] ?? ''}';
    final monthLabel = formatApiMonth(monthKey, calendarMode, locale: 'am');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          monthLabel,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          MoneyEtb.formatCents(total),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0284C7),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$dayCount day${dayCount == 1 ? '' : 's'} with activity',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (!compact) const SizedBox(height: 8),
      ],
    );
  }
}

class _ActivityLineTile extends StatelessWidget {
  const _ActivityLineTile({required this.row, required this.calendarMode});

  final Map<String, dynamic> row;
  final CalendarMode calendarMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = '${row['customerName'] ?? ''}'.trim();
    final company = '${row['companyName'] ?? ''}'.trim();
    final wallet = '${row['walletLabel'] ?? ''}'.trim();
    final coveredRaw = '${row['coveredTxDay'] ?? ''}'.trim();
    final covered = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(coveredRaw)
        ? formatTxDay(coveredRaw, calendarMode, locale: 'am')
        : coveredRaw;
    final amount = _reportIntFromJson(row['amountCents']);
    final createdRaw = row['createdAt'];
    final createdAt = createdRaw is String
        ? DateTime.tryParse(createdRaw)
        : createdRaw is DateTime
        ? createdRaw
        : null;
    final sub = <String>[
      if (company.isNotEmpty) company,
      if (wallet.isNotEmpty) wallet,
      if (covered.isNotEmpty) 'Saving day: $covered',
      if (createdAt != null) formatEatTime(createdAt),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          name.isEmpty ? '—' : name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: sub.isEmpty
            ? null
            : Text(sub, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: Text(
          MoneyEtb.formatCents(amount),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF059669),
          ),
        ),
      ),
    );
  }
}

class _CompanyWalletEntryCard extends StatelessWidget {
  const _CompanyWalletEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Company Wallet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Open the company balance, status, and recent history.',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.open_in_new_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyWalletReportPage extends ConsumerStatefulWidget {
  const _CompanyWalletReportPage();

  @override
  ConsumerState<_CompanyWalletReportPage> createState() =>
      _CompanyWalletReportPageState();
}

class _CompanyWalletReportPageState
    extends ConsumerState<_CompanyWalletReportPage> {
  CalendarModeService? _calendarService;
  bool _submittingExpense = false;

  @override
  void initState() {
    super.initState();
    CalendarModeService.getInstance().then((s) {
      if (mounted) setState(() => _calendarService = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_calendarService == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Company Wallet')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return ValueListenableBuilder<CalendarMode>(
      valueListenable: _calendarService!,
      builder: (context, calendarMode, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Company Wallet')),
          body: FutureBuilder<Map<String, dynamic>>(
            future: ref.read(companyWalletReportProvider(60).future),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('${snap.error}'));
              }

              final data = snap.data ?? const <String, dynamic>{};
              final wallet = (data['wallet'] as Map?) ?? const {};
              final summary = (data['summary'] as Map?) ?? const {};
              final history = (data['history'] as List?) ?? const [];
              final isProvisioned = wallet['isProvisioned'] != false;
              final balanceCents = _toInt(wallet['balanceCents']);
              final feeRevenueCents = _toInt(summary['feeRevenueCents']);
              final feeEntryCount = _toInt(summary['feeEntryCount']);
              final isNegative = balanceCents < 0;
              final headerColor = isNegative
                  ? const Color(0xFFEF5350)
                  : const Color(0xFF0EA5E9);
              final accentColor = isNegative
                  ? const Color(0xFFE57373)
                  : const Color(0xFF2DD4BF);

              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    FilledButton.icon(
                      onPressed: _submittingExpense
                          ? null
                          : () => _showRecordExpenseSheet(context),
                      icon: _submittingExpense
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.remove_circle_outline),
                      label: Text(
                        _submittingExpense
                            ? 'Recording expense...'
                            : 'Record Company Expense',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [headerColor, accentColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: headerColor.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${wallet['displayName'] ?? 'Company Wallet'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if ((wallet['code'] as String?)?.isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${wallet['code']}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            Text(
                              'Current Balance',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              MoneyEtb.formatCents(balanceCents),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _WalletInfoChip(
                                  label:
                                      'Status ${wallet['status'] ?? 'ACTIVE'}',
                                ),
                                _WalletInfoChip(
                                  label:
                                      '${history.length} history item${history.length == 1 ? '' : 's'}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!isProvisioned)
                      Card(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Company wallet is not provisioned yet. Showing safe zero values.',
                          ),
                        ),
                      ),
                    if (!isProvisioned) const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _WalletStatCard(
                            label: 'Fee Revenue',
                            value: MoneyEtb.formatCents(feeRevenueCents),
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _WalletStatCard(
                            label: 'Fee Entries',
                            value: '$feeEntryCount',
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _WalletStatCard(
                            label: 'Status',
                            value: '${wallet['status'] ?? 'ACTIVE'}',
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _WalletStatCard(
                            label: 'Recent Entries',
                            value: '${history.length}',
                            color: const Color(0xFF0EA5E9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'History',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (history.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('No company wallet history yet.'),
                          ),
                        ),
                      )
                    else
                      Card(
                        child: Column(
                          children: history
                              .map(
                                (entry) => TransactionTile(
                                  tx: LedgerTx.fromBackendMap(
                                    Map<String, dynamic>.from(entry as Map),
                                  ),
                                  calendarMode: calendarMode,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _showRecordExpenseSheet(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    var paymentMethod = 'CASH';
    var selectedDate = DateTime.now();
    var busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DateSelector(
                selectedDate: selectedDate,
                onDateChanged: (value) =>
                    setSheetState(() => selectedDate = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (ETB)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Expense reason',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: paymentMethod,
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
                onChanged: busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        setSheetState(() => paymentMethod = value);
                      },
              ),
              if (paymentMethod == 'MOBILE_BANKING') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: bankCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bank (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        try {
                          final amountCents = MoneyEtb.parseEtbToCents(amountCtrl.text);
                          final reason = reasonCtrl.text.trim();
                          if (reason.isEmpty) {
                            throw const FormatException('Expense reason is required');
                          }
                          setSheetState(() => busy = true);
                          setState(() => _submittingExpense = true);
                          await ref.read(companyExpenseMutationProvider.notifier).submit((
                            amountCents: amountCents,
                            txDateMillis: dateToTxMillis(selectedDate),
                            reason: reason,
                            paymentMethod: paymentMethod,
                            bankName: paymentMethod == 'MOBILE_BANKING'
                                ? (bankCtrl.text.trim().isEmpty
                                      ? null
                                      : bankCtrl.text.trim())
                                : null,
                            note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                          ));
                          final mutation = ref.read(companyExpenseMutationProvider);
                          if (mutation.error != null) throw mutation.error!;
                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                          if (!mounted) return;
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Company expense recorded')),
                          );
                        } catch (e) {
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _submittingExpense = false);
                          }
                          if (sheetContext.mounted) {
                            setSheetState(() => busy = false);
                          }
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletInfoChip extends StatelessWidget {
  const _WalletInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WalletStatCard extends StatelessWidget {
  const _WalletStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.accentColor,
    required this.icon,
    required this.body,
    required this.onViewDetail,
    this.onExportPdf,
    this.isExporting = false,
  });

  final String title;
  final Color accentColor;
  final IconData icon;
  final Widget body;
  final VoidCallback onViewDetail;
  final VoidCallback? onExportPdf;
  final bool isExporting;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            body,
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onExportPdf != null)
                  FilledButton.icon(
                    onPressed: isExporting ? null : onExportPdf,
                    icon: isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(isExporting ? 'Generating...' : 'Generate PDF'),
                  ),
                TextButton.icon(
                  onPressed: onViewDetail,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View detail'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportLoadingCard extends StatelessWidget {
  const _ReportLoadingCard({
    required this.title,
    required this.accentColor,
    required this.icon,
  });

  final String title;
  final Color accentColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 36,
              width: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading report…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportErrorCard extends StatelessWidget {
  const _ReportErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Could not load report',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onRetry, child: const Text('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
