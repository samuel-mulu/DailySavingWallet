import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/money/money.dart';
import '../../../core/ui/date_selector.dart';
import '../../../data/wallet/models.dart';
import '../../../data/wallet/wallet_repo.dart';
import '../../wallet/widgets/transaction_tile.dart';
import 'admin_reports_pdf.dart';

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  final _repo = WalletRepo();
  DateTime _selectedDate = DateTime.now();
  int _dailyReportNonce = 0;
  int _monthlyReportNonce = 0;

  String get _txDay =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
  String get _month =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: DateSelector(
              selectedDate: _selectedDate,
              onDateChanged: (value) => setState(() => _selectedDate = value),
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
                  onRefresh: () async => setState(() => _dailyReportNonce++),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _StableReportFuture(
                        key: ValueKey<String>('d_${_txDay}_$_dailyReportNonce'),
                        load: () => _repo.fetchDailySavingsReport(_txDay),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return _ReportErrorCard(
                              message: '${snap.error}',
                              onRetry: () =>
                                  setState(() => _dailyReportNonce++),
                            );
                          }
                          if (snap.connectionState == ConnectionState.waiting &&
                              !snap.hasData) {
                            return const _ReportLoadingCard(
                              title: 'Daily Savings',
                              accentColor: Color(0xFF10B981),
                              icon: Icons.calendar_today_outlined,
                            );
                          }
                          final data = snap.data ?? const <String, dynamic>{};
                          return _ReportCard(
                            title: 'Daily Savings',
                            accentColor: const Color(0xFF10B981),
                            icon: Icons.calendar_today_outlined,
                            body: _DailyReportSummary(data: data),
                            onViewDetail: () => _showDailyDetail(context, data),
                            onExportPdf: () => _exportDailyPdf(context, data),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                RefreshIndicator(
                  onRefresh: () async => setState(() => _monthlyReportNonce++),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _StableReportFuture(
                        key: ValueKey<String>('m_${_month}_$_monthlyReportNonce'),
                        load: () => _repo.fetchMonthlySavingsReport(_month),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return _ReportErrorCard(
                              message: '${snap.error}',
                              onRetry: () =>
                                  setState(() => _monthlyReportNonce++),
                            );
                          }
                          if (snap.connectionState == ConnectionState.waiting &&
                              !snap.hasData) {
                            return const _ReportLoadingCard(
                              title: 'Monthly Savings',
                              accentColor: Color(0xFF0EA5E9),
                              icon: Icons.calendar_month_outlined,
                            );
                          }
                          final data = snap.data ?? const <String, dynamic>{};
                          final daily =
                              (data['daily'] as List?) ?? const <dynamic>[];
                          return _ReportCard(
                            title: 'Monthly Savings',
                            accentColor: const Color(0xFF0EA5E9),
                            icon: Icons.calendar_month_outlined,
                            body: _MonthlyReportSummary(
                              data: data,
                              dayCount: daily.length,
                            ),
                            onViewDetail: () =>
                                _showMonthlyDetail(context, data),
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
  }

  Future<void> _exportDailyPdf(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    try {
      final bytes = await buildDailySavingsReportPdf(
        data: data,
        generatedAt: DateTime.now(),
      );
      final day = '${data['txDay'] ?? _txDay}'.replaceAll('-', '');
      if (!context.mounted) return;
      await Printing.sharePdf(bytes: bytes, filename: 'daily-savings-$day.pdf');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not build PDF: $e')),
      );
    }
  }

  Future<void> _exportMonthlyPdf(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    try {
      final bytes = await buildMonthlySavingsReportPdf(
        data: data,
        month: '${data['month'] ?? _month}',
        generatedAt: DateTime.now(),
      );
      final m = '${data['month'] ?? _month}'.replaceAll('-', '');
      if (!context.mounted) return;
      await Printing.sharePdf(bytes: bytes, filename: 'monthly-savings-$m.pdf');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not build PDF: $e')),
      );
    }
  }

  void _showDailyDetail(BuildContext context, Map<String, dynamic> data) {
    final saved = _mapList(data['savedBreakdown']);
    final pending = _mapList(data['pendingBreakdown']);
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
                      'Daily report',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Download PDF',
                    onPressed: () {
                      Navigator.pop(context);
                      _exportDailyPdf(sheetContext, data);
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                ],
              ),
              _DailyReportSummary(data: data, compact: true),
              const SizedBox(height: 16),
              Text(
                'Saved today (${saved.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 8),
              if (saved.isEmpty)
                Text(
                  'No wallets recorded for this day.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...saved.map((row) => _WalletBreakdownTile(row: row, saved: true)),
              const SizedBox(height: 20),
              Text(
                'Pending (${pending.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD97706),
                ),
              ),
              const SizedBox(height: 8),
              if (pending.isEmpty)
                Text(
                  'All active wallets have a saving for this day.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...pending.map(
                  (row) => _WalletBreakdownTile(row: row, saved: false),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showMonthlyDetail(BuildContext context, Map<String, dynamic> data) {
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
                      'Monthly report',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Download PDF',
                    onPressed: () {
                      Navigator.pop(context);
                      _exportMonthlyPdf(sheetContext, data);
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                ],
              ),
              _MonthlyReportSummary(
                data: data,
                dayCount: daily.length,
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
                  'No daily savings in this month.',
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
                            '${daily[i]['txDay']}',
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

class _DailyReportSummary extends StatelessWidget {
  const _DailyReportSummary({
    required this.data,
    this.compact = false,
  });

  final Map<String, dynamic> data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _reportIntFromJson(data['totalSavedCents']);
    final progress = (data['progressPct'] is num)
        ? (data['progressPct'] as num).toDouble().clamp(0, 100)
        : double.tryParse('${data['progressPct']}')?.clamp(0, 100) ?? 0.0;
    final pad = compact ? 12.0 : 0.0;

    final stats = <_StatItem>[
      _StatItem('Customers', '${data['activeCustomers'] ?? 0}', Icons.people_outline),
      _StatItem('Wallets', '${data['activeWallets'] ?? 0}', Icons.account_balance_wallet_outlined),
      _StatItem('Saved', '${data['savedWalletCount'] ?? 0}', Icons.check_circle_outline),
      _StatItem('Pending', '${data['pendingWalletCount'] ?? 0}', Icons.pending_outlined),
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
          'Total saved · ${progress.toStringAsFixed(1)}% of wallets',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: compact ? 8 : 10,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: const Color(0xFF10B981),
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
                  avatar: Icon(s.icon, size: 18, color: const Color(0xFF047857)),
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
    this.compact = false,
  });

  final Map<String, dynamic> data;
  final int dayCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _reportIntFromJson(data['totalSavedCents']);
    final month = '${data['month'] ?? ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          month,
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
          '$dayCount day${dayCount == 1 ? '' : 's'} with savings activity',
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

class _WalletBreakdownTile extends StatelessWidget {
  const _WalletBreakdownTile({
    required this.row,
    required this.saved,
  });

  final Map<String, dynamic> row;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = '${row['customerName'] ?? ''}'.trim();
    final company = '${row['companyName'] ?? ''}'.trim();
    final wallet = '${row['walletLabel'] ?? ''}'.trim();
    final amount = saved
        ? _reportIntFromJson(row['amountCents'])
        : _reportIntFromJson(row['dailyTargetCents']);
    final trailing = MoneyEtb.formatCents(amount);
    final sub = <String>[
      if (company.isNotEmpty) company,
      if (wallet.isNotEmpty) wallet,
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
            : Text(
                sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: Text(
          trailing,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: saved ? const Color(0xFF059669) : const Color(0xFFD97706),
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

class _CompanyWalletReportPage extends StatefulWidget {
  const _CompanyWalletReportPage();

  @override
  State<_CompanyWalletReportPage> createState() =>
      _CompanyWalletReportPageState();
}

class _CompanyWalletReportPageState extends State<_CompanyWalletReportPage> {
  final _repo = WalletRepo();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Wallet')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _repo.fetchCompanyWalletReport(limit: 60),
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
                              label: 'Status ${wallet['status'] ?? 'ACTIVE'}',
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
  }

  int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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
  });

  final String title;
  final Color accentColor;
  final IconData icon;
  final Widget body;
  final VoidCallback onViewDetail;
  final VoidCallback? onExportPdf;

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
                if (onExportPdf != null)
                  IconButton(
                    tooltip: 'Download PDF',
                    onPressed: onExportPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            body,
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onViewDetail,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('View detail'),
              ),
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
  const _ReportErrorCard({
    required this.message,
    required this.onRetry,
  });

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
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
