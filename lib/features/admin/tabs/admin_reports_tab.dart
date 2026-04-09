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
              onDateChanged: (v) => setState(() => _selectedDate = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: ListTile(
                title: const Text('Company Wallet'),
                subtitle: const Text('Open full balance, details, and history'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _CompanyWalletReportPage()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const TabBar(tabs: [Tab(text: 'Daily'), Tab(text: 'Monthly')]),
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
                          final d = snap.data ?? const <String, dynamic>{};
                          return _ReportCard(
                            title: 'Daily Savings',
                            lines: [
                              'Date: ${d['txDay'] ?? _txDay}',
                              'Active wallets: ${d['activeWallets'] ?? 0}',
                              'Saved wallets: ${d['savedWalletCount'] ?? 0}',
                              'Pending wallets: ${d['pendingWalletCount'] ?? 0}',
                              'Total saved: ${MoneyEtb.formatCents(_toInt(d['totalSavedCents']))}',
                              'Progress: ${d['progressPct'] ?? 0}%',
                            ],
                            onViewDetail: () => _showDailyDetail(context, d),
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
                          final m = snap.data ?? const <String, dynamic>{};
                          return _ReportCard(
                            title: 'Monthly Savings',
                            lines: [
                              'Month: ${m['month'] ?? _month}',
                              'Total saved: ${MoneyEtb.formatCents(_toInt(m['totalSavedCents']))}',
                              'Saved days: ${((m['daily'] as List?) ?? const []).length}',
                            ],
                            onViewDetail: () => _showMonthlyDetail(context, m),
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

  void _showDailyDetail(BuildContext context, Map<String, dynamic> d) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Report Detail', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Date: ${d['txDay']}'),
            Text('Active customers: ${d['activeCustomers']}'),
            Text('Active wallets: ${d['activeWallets']}'),
            Text('Saved wallets: ${d['savedWalletCount']}'),
            Text('Pending wallets: ${d['pendingWalletCount']}'),
            Text('Total saved: ${MoneyEtb.formatCents(_toInt(d['totalSavedCents']))}'),
            Text('Progress: ${d['progressPct']}%'),
          ],
        ),
      ),
    );
  }

  void _showMonthlyDetail(BuildContext context, Map<String, dynamic> m) {
    final daily = (m['daily'] as List?) ?? const [];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Monthly Report Detail', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Month: ${m['month']}'),
            Text('Total saved: ${MoneyEtb.formatCents(_toInt(m['totalSavedCents']))}'),
            const Divider(height: 20),
            for (final row in daily)
              ListTile(
                dense: true,
                title: Text('${row['txDay']}'),
                subtitle: Text('Saved wallets: ${row['savedWalletCount']}'),
                trailing: Text(MoneyEtb.formatCents(_toInt(row['totalSavedCents']))),
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

class _CompanyWalletReportPage extends StatefulWidget {
  const _CompanyWalletReportPage();

  @override
  State<_CompanyWalletReportPage> createState() => _CompanyWalletReportPageState();
}

class _CompanyWalletReportPageState extends State<_CompanyWalletReportPage> {
  final _repo = WalletRepo();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Wallet Report')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _repo.fetchCompanyWalletReport(limit: 60),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          final wallet = (data['wallet'] as Map?) ?? const {};
          final history = (data['history'] as List?) ?? const [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${wallet['displayName'] ?? 'Company Wallet'} (${wallet['code'] ?? ''})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Balance: ${MoneyEtb.formatCents(_toInt(wallet['balanceCents']))}'),
                      Text('Status: ${wallet['status'] ?? 'ACTIVE'}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('History', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: history
                      .map(
                        (e) => TransactionTile(
                          tx: LedgerTx.fromBackendMap(Map<String, dynamic>.from(e as Map)),
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

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.lines,
    required this.onViewDetail,
  });

  final String title;
  final List<String> lines;
  final VoidCallback onViewDetail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final l in lines) Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l),
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
