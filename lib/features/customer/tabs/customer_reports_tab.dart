import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates/date_formatters.dart';
import '../../../core/settings/calendar_mode.dart';
import '../../../core/ui/ethiopian_date_picker.dart';
import '../../../data/wallet/models.dart';
import '../../../data/wallet/recorded_daily_days_month.dart';
import '../../auth/providers/auth_providers.dart';
import '../../data/server_state_refresh.dart';
import '../../wallet/wallet_providers.dart';

class CustomerReportsTab extends ConsumerStatefulWidget {
  const CustomerReportsTab({super.key});

  @override
  ConsumerState<CustomerReportsTab> createState() => _CustomerReportsTabState();
}

class _CustomerReportsTabState extends ConsumerState<CustomerReportsTab> {
  CalendarModeService? _calendarService;
  String? _selectedWalletId;
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  @override
  void initState() {
    super.initState();
    _initCalendarService();
  }

  Future<void> _initCalendarService() async {
    final service = await CalendarModeService.getInstance();
    if (mounted) {
      setState(() => _calendarService = service);
    }
  }

  Future<void> _selectMonth(CalendarMode mode) async {
    DateTime? picked;
    final now = DateTime.now();
    if (mode == CalendarMode.ethiopian) {
      final initialEth = _selectedMonth.convertToEthiopian();
      final firstEth = DateTime(2023, 1, 1).convertToEthiopian();
      final lastEth = DateTime(now.year, now.month + 1, 0).convertToEthiopian();
      final eth = await showEthiopianDatePicker(
        context: context,
        initialDate: initialEth,
        firstDate: firstEth,
        lastDate: lastEth,
      );
      if (eth != null) {
        picked = eth.convertToGregorian();
      }
    } else {
      picked = await showDatePicker(
        context: context,
        initialDate: _selectedMonth,
        firstDate: DateTime(2023, 1, 1),
        lastDate: DateTime(now.year, now.month + 1, 0),
        helpText: 'Select month',
        initialDatePickerMode: DatePickerMode.year,
      );
    }

    if (picked == null) return;
    setState(() {
      _selectedMonth = DateTime(picked!.year, picked.month, 1);
    });
  }

  void _goMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
        1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authUidProvider).valueOrNull;
    if (uid == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_calendarService == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final profileAsync = ref.watch(appUserProfileProvider(uid));

    return ValueListenableBuilder<CalendarMode>(
      valueListenable: _calendarService!,
      builder: (context, mode, _) {
        return profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load profile: $error'),
            ),
          ),
          data: (profile) {
            final customerId = profile.customerId;
            final monthKey = _monthKey(_selectedMonth);
            if (customerId == null || customerId.isEmpty) {
              return const Scaffold(
                backgroundColor: Color(0xFFF9FAFB),
                body: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: _ReportsInfoCard(
                    icon: Icons.info_outline,
                    message: 'Unable to load wallet report right now.',
                  ),
                ),
              );
            }

            final walletsStale = ref.watch(
              customerWalletsStaleProvider(customerId),
            );
            final wallets = walletsStale.data ?? const <CustomerWallet>[];
            final walletId = _resolveSelectedWalletId(wallets);
            final selectedWallet = _findWallet(wallets, walletId);
            final targetDays = DateTime(
              _selectedMonth.year,
              _selectedMonth.month + 1,
              0,
            ).day;

            AsyncValue<RecordedDailyDaysMonth>? recordedAsync;
            if (walletId != null) {
              recordedAsync = ref.watch(
                recordedDailyDaysByMonthProvider((
                  customerId: customerId,
                  walletId: walletId,
                  month: monthKey,
                )),
              );
            }

            return Scaffold(
              backgroundColor: const Color(0xFFF9FAFB),
              body: RefreshIndicator(
                onRefresh: () => refreshCustomerReportScope(
                  ref,
                  customerId: customerId,
                  walletId: walletId,
                  month: monthKey,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _MonthAndWalletHeader(
                      mode: mode,
                      monthKey: monthKey,
                      selectedWalletId: walletId,
                      wallets: wallets,
                      onWalletChanged: (v) =>
                          setState(() => _selectedWalletId = v),
                      onPickMonth: () => _selectMonth(mode),
                      onPrevMonth: () => _goMonth(-1),
                      onNextMonth: () => _goMonth(1),
                    ),
                    const SizedBox(height: 12),
                    if (walletsStale.data == null && walletsStale.isRefreshing)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (walletsStale.error != null && wallets.isEmpty)
                      _ReportsInfoCard(
                        icon: Icons.error_outline,
                        message:
                            'Could not load wallets: ${walletsStale.error}',
                      )
                    else if (walletId == null || selectedWallet == null)
                      const _ReportsInfoCard(
                        icon: Icons.info_outline,
                        message: 'Unable to load wallet report right now.',
                      )
                    else if (recordedAsync == null)
                      const Center(child: CircularProgressIndicator())
                    else
                      recordedAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 36),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, _) => _ReportsInfoCard(
                          icon: Icons.error_outline,
                          message: 'Could not load report data: $error',
                        ),
                        data: (recordedData) {
                          final savedDays = recordedData.recordedTxDays.length;
                          final remainingDays = (targetDays - savedDays).clamp(
                            0,
                            targetDays,
                          );
                          final progress = targetDays == 0
                              ? 0.0
                              : savedDays / targetDays;
                          return Column(
                            children: [
                              _ProgressCard(
                                savedDays: savedDays,
                                remainingDays: remainingDays,
                                percent: (progress * 100).round(),
                                progress: progress.clamp(0.0, 1.0),
                              ),
                              const SizedBox(height: 12),
                              _SavedDaysCalendarCard(
                                mode: mode,
                                month: _selectedMonth,
                                recordedTxDays: recordedData.recordedTxDays,
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String? _resolveSelectedWalletId(List<CustomerWallet> wallets) {
    final selectedWalletId = _selectedWalletId;
    if (selectedWalletId != null &&
        wallets.any((wallet) => wallet.id == selectedWalletId)) {
      return selectedWalletId;
    }
    if (wallets.isEmpty) {
      return null;
    }
    return wallets
        .firstWhere((w) => w.isPrimary, orElse: () => wallets.first)
        .id;
  }

  CustomerWallet? _findWallet(List<CustomerWallet> wallets, String? walletId) {
    for (final wallet in wallets) {
      if (wallet.id == walletId) {
        return wallet;
      }
    }
    return null;
  }
}

class _MonthAndWalletHeader extends StatelessWidget {
  const _MonthAndWalletHeader({
    required this.mode,
    required this.monthKey,
    required this.selectedWalletId,
    required this.wallets,
    required this.onWalletChanged,
    required this.onPickMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final CalendarMode mode;
  final String monthKey;
  final String? selectedWalletId;
  final List<CustomerWallet> wallets;
  final ValueChanged<String> onWalletChanged;
  final VoidCallback onPickMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly report',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: onPrevMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: InkWell(
                    onTap: onPickMonth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: const Color(0xFFF3F4F6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_month, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            formatApiMonth(monthKey, mode, locale: 'am'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (wallets.length > 1) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedWalletId,
                decoration: const InputDecoration(
                  labelText: 'Wallet',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: wallets
                    .map(
                      (w) => DropdownMenuItem<String>(
                        value: w.id,
                        child: Text(w.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  onWalletChanged(v);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.savedDays,
    required this.remainingDays,
    required this.percent,
    required this.progress,
  });

  final int savedDays;
  final int remainingDays;
  final int percent;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(label: 'Saved days', value: '$savedDays'),
                ),
                Expanded(
                  child: _MetricTile(
                    label: 'Remaining',
                    value: '$remainingDays',
                  ),
                ),
                Expanded(
                  child: _MetricTile(label: 'Complete', value: '$percent%'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}

class _SavedDaysCalendarCard extends StatelessWidget {
  const _SavedDaysCalendarCard({
    required this.mode,
    required this.month,
    required this.recordedTxDays,
  });

  final CalendarMode mode;
  final DateTime month;
  final Set<String> recordedTxDays;

  @override
  Widget build(BuildContext context) {
    final days = _monthGridDays(month);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    const labels = <String>['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved dates',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: labels
                  .map(
                    (label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.08,
              ),
              itemBuilder: (context, index) {
                final date = days[index];
                if (date == null) {
                  return const SizedBox.shrink();
                }
                final dayOnly = DateTime(date.year, date.month, date.day);
                final isToday = dayOnly == todayDate;
                final isFuture = dayOnly.isAfter(todayDate);
                final iso = _isoDay(date);
                final isSaved = recordedTxDays.contains(iso);
                final bgColor = isSaved
                    ? const Color(0xFFDCFCE7)
                    : (isFuture ? const Color(0xFFF3F4F6) : Colors.white);
                final borderColor = isToday
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFFE5E7EB);
                final textColor = isSaved
                    ? const Color(0xFF166534)
                    : (isFuture
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF111827));

                return Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: borderColor,
                        width: isToday ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        mode == CalendarMode.ethiopian
                            ? '${date.convertToEthiopian().day}'
                            : '${date.day}',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: isSaved || isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Green days are saved dates.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}

class _ReportsInfoCard extends StatelessWidget {
  const _ReportsInfoCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6B7280)),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
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
