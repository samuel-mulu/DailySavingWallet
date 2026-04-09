import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../core/ui/date_selector.dart';
import '../../../data/wallet/models.dart';
import '../../../data/wallet/wallet_repo.dart';
import '../../wallet/widgets/transaction_tile.dart';

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  final _repo = WalletRepo();
  DateTime _selectedDate = DateTime.now();

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
                  onRefresh: () async => setState(() {}),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      FutureBuilder<Map<String, dynamic>>(
                        future: _repo.fetchDailySavingsReport(_txDay),
                        builder: (context, snap) {
                          final data = snap.data ?? const <String, dynamic>{};
                          return _ReportCard(
                            title: 'Daily Savings',
                            accentColor: const Color(0xFF10B981),
                            icon: Icons.calendar_today_outlined,
                            lines: [
                              'Active wallets: ${data['activeWallets'] ?? 0}',
                              'Saved wallets: ${data['savedWalletCount'] ?? 0}',
                              'Pending wallets: ${data['pendingWalletCount'] ?? 0}',
                              'Total saved: ${MoneyEtb.formatCents(_toInt(data['totalSavedCents']))}',
                              'Progress: ${data['progressPct'] ?? 0}%',
                            ],
                            onViewDetail: () => _showDailyDetail(context, data),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      FutureBuilder<Map<String, dynamic>>(
                        future: _repo.fetchMonthlySavingsReport(_month),
                        builder: (context, snap) {
                          final data = snap.data ?? const <String, dynamic>{};
                          return _ReportCard(
                            title: 'Monthly Savings',
                            accentColor: const Color(0xFF0EA5E9),
                            icon: Icons.calendar_month_outlined,
                            lines: [
                              'Total saved: ${MoneyEtb.formatCents(_toInt(data['totalSavedCents']))}',
                              'Saved days: ${((data['daily'] as List?) ?? const []).length}',
                            ],
                            onViewDetail: () =>
                                _showMonthlyDetail(context, data),
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

  void _showDailyDetail(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Report Detail',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Date: ${data['txDay'] ?? _txDay}'),
            Text('Active customers: ${data['activeCustomers'] ?? 0}'),
            Text('Active wallets: ${data['activeWallets'] ?? 0}'),
            Text('Saved wallets: ${data['savedWalletCount'] ?? 0}'),
            Text('Pending wallets: ${data['pendingWalletCount'] ?? 0}'),
            Text(
              'Total saved: ${MoneyEtb.formatCents(_toInt(data['totalSavedCents']))}',
            ),
            Text('Progress: ${data['progressPct'] ?? 0}%'),
          ],
        ),
      ),
    );
  }

  void _showMonthlyDetail(BuildContext context, Map<String, dynamic> data) {
    final daily = (data['daily'] as List?) ?? const [];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Monthly Report Detail',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Month: ${data['month'] ?? _month}'),
            Text(
              'Total saved: ${MoneyEtb.formatCents(_toInt(data['totalSavedCents']))}',
            ),
            const Divider(height: 20),
            for (final row in daily)
              ListTile(
                dense: true,
                title: Text('${row['txDay']}'),
                subtitle: Text('Saved wallets: ${row['savedWalletCount']}'),
                trailing: Text(
                  MoneyEtb.formatCents(_toInt(row['totalSavedCents'])),
                ),
              ),
          ],
        ),
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
          final history = (data['history'] as List?) ?? const [];
          final balanceCents = _toInt(wallet['balanceCents']);
          final isNegative = balanceCents < 0;
          final headerColor = isNegative
              ? const Color(0xFFEF5350)
              : const Color(0xFF0EA5E9);
          final accentColor = isNegative
              ? const Color(0xFFE57373)
              : const Color(0xFF2DD4BF);

          return ListView(
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
                      if ((wallet['code'] as String?)?.isNotEmpty == true) ...[
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
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'History',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
    required this.lines,
    required this.onViewDetail,
  });

  final String title;
  final Color accentColor;
  final IconData icon;
  final List<String> lines;
  final VoidCallback onViewDetail;

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
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line),
              ),
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
