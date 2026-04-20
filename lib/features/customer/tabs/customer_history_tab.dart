import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/calendar_mode.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/error_state.dart';
import '../../../core/ui/ethiopian_date_picker.dart';
import '../../../data/wallet/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../../data/server_state_refresh.dart';
import '../../wallet/wallet_providers.dart';
import '../../wallet/wallet_status_utils.dart';
import '../../wallet/widgets/transaction_tile.dart';

class CustomerHistoryTab extends ConsumerStatefulWidget {
  /// Incremented by [CustomerShell] when the History tab is selected to refetch.
  final int refreshSignal;

  const CustomerHistoryTab({super.key, this.refreshSignal = 0});

  @override
  ConsumerState<CustomerHistoryTab> createState() => _CustomerHistoryTabState();
}

class _CustomerHistoryTabState extends ConsumerState<CustomerHistoryTab> {
  CalendarModeService? _calendarService;
  String? _selectedWalletId;
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  String _selectedFilter = CustomerHistoryFilterValues.all;

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

  @override
  void didUpdateWidget(CustomerHistoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal &&
        widget.refreshSignal > 0) {
      final query = _currentLedgerQuery();
      if (query == null) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        refreshCustomerHistoryScope(
          ref,
          customerId: query.customerId,
          query: query,
        );
      });
    }
  }

  CustomerLedgerPageQuery? _currentLedgerQuery() {
    final uid = ref.read(authUidProvider).valueOrNull;
    if (uid == null) return null;
    final profile = ref.read(appUserProfileProvider(uid)).valueOrNull;
    final customerId = profile?.customerId;
    if (customerId == null || customerId.isEmpty) return null;
    final walletsState = ref.read(customerWalletsStaleProvider(customerId));
    final wallets = walletsState.data ?? const <CustomerWallet>[];
    final selectedWalletId = _resolveSelectedWalletId(wallets);
    if (selectedWalletId == null) return null;
    return CustomerLedgerPageQuery.fromDate(
      customerId: customerId,
      walletId: selectedWalletId,
      month: _selectedDate,
      filter: _selectedFilter,
    );
  }

  Future<void> _selectMonth() async {
    final now = DateTime.now();
    DateTime? picked;

    final mode = _calendarService?.value ?? CalendarMode.gregorian;

    if (mode == CalendarMode.ethiopian) {
      final ethDate = _selectedDate.convertToEthiopian();
      final ethNow = now.convertToEthiopian();
      final ethPicked = await showEthiopianDatePicker(
        context: context,
        initialDate: ethDate,
        firstDate: DateTime(2023).convertToEthiopian(),
        lastDate: DateTime(
          ethNow.year,
          ethNow.month + 1,
          0,
        ).convertToEthiopian(),
      );
      if (ethPicked != null) {
        picked = ethPicked.convertToGregorian();
      }
    } else {
      picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2023),
        lastDate: DateTime(now.year, now.month + 1, 0),
        helpText: 'Select Month',
        initialDatePickerMode: DatePickerMode.year,
      );
    }

    if (picked != null &&
        (picked.year != _selectedDate.year ||
            picked.month != _selectedDate.month)) {
      setState(() {
        _selectedDate = DateTime(picked!.year, picked.month, 1);
      });
    }
  }

  String _formatMonthYear(DateTime date) {
    if (_calendarService?.value == CalendarMode.ethiopian) {
      final ethDate = date.convertToEthiopian();
      return ETDateFormat('MMMM yyyy', 'am').format(ethDate);
    }
    return DateFormat('MMM yyyy').format(date);
  }

  Future<void> _onRefresh({
    required String customerId,
    required CustomerLedgerPageQuery? query,
  }) async {
    if (query == null) {
      await ref
          .read(customerWalletsStaleProvider(customerId).notifier)
          .refresh(force: true);
      return;
    }

    await refreshCustomerHistoryScope(
      ref,
      customerId: customerId,
      query: query,
    );
  }

  bool _handleHistoryScroll(
    ScrollNotification notification,
    CustomerLedgerPageQuery? query,
  ) {
    if (query == null || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 200) {
      ref.read(ledgerPageNotifierProvider(query).notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_calendarService == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final uid = ref.watch(authUidProvider).valueOrNull;
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profileAsync = ref.watch(appUserProfileProvider(uid));

    return ValueListenableBuilder<CalendarMode>(
      valueListenable: _calendarService!,
      builder: (context, mode, _) {
        return profileAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load profile: $error'),
              ),
            ),
          ),
          data: (profile) {
            final customerId = profile.customerId;
            if (customerId == null || customerId.isEmpty) {
              return const Scaffold(
                backgroundColor: Color(0xFFF9FAFB),
                body: Padding(
                  padding: EdgeInsets.all(16),
                  child: _HistoryInfoCard(
                    icon: Icons.info_outline,
                    message: 'Unable to load history right now.',
                  ),
                ),
              );
            }

            final walletsStale = ref.watch(
              customerWalletsStaleProvider(customerId),
            );
            final wallets = walletsStale.data ?? const <CustomerWallet>[];
            final selectedWalletId = _resolveSelectedWalletId(wallets);
            final query = selectedWalletId == null
                ? null
                : CustomerLedgerPageQuery.fromDate(
                    customerId: customerId,
                    walletId: selectedWalletId,
                    month: _selectedDate,
                    filter: _selectedFilter,
                  );
            final ledgerState = query == null
                ? null
                : ref.watch(ledgerPageNotifierProvider(query));

            return Scaffold(
              backgroundColor: const Color(0xFFF9FAFB),
              appBar: AppBar(
                title: const Text('History'),
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1F2937),
                actions: [
                  TextButton.icon(
                    onPressed: _selectMonth,
                    icon: const Icon(Icons.calendar_month_rounded, size: 20),
                    label: Text(_formatMonthYear(_selectedDate)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8B5CF6),
                    ),
                  ),
                  if (wallets.length > 1)
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedWalletId,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedWalletId = value);
                        },
                        items: wallets
                            .map(
                              (wallet) => DropdownMenuItem<String>(
                                value: wallet.id,
                                child: Text(
                                  wallet.displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
              body: Column(
                children: [
                  if (profile.status != 'active' ||
                      _isSelectedWalletBlocked(wallets, selectedWalletId))
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: profile.status != 'active'
                            ? Colors.red.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: profile.status != 'active'
                              ? Colors.red.shade300
                              : Colors.orange.shade300,
                        ),
                      ),
                      child: Text(
                        profile.status != 'active'
                            ? 'Your account is deactivated. Please contact your administrator.'
                            : 'This wallet is frozen/closed. History access is limited.',
                      ),
                    ),
                  Container(
                    height: 60,
                    color: Colors.white,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      children: CustomerHistoryFilterValues.allValues.map((
                        filter,
                      ) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() => _selectedFilter = filter);
                            },
                            selectedColor: const Color(
                              0xFF8B5CF6,
                            ).withOpacity(0.15),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF8B5CF6)
                                  : const Color(0xFF6B7280),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            backgroundColor: const Color(0xFFF3F4F6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF8B5CF6).withOpacity(0.2)
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () =>
                          _onRefresh(customerId: customerId, query: query),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) =>
                            _handleHistoryScroll(notification, query),
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            if (walletsStale.data == null &&
                                walletsStale.isRefreshing)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (walletsStale.error != null &&
                                wallets.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: ErrorState(
                                  title: 'Could not load wallets',
                                  message: walletsStale.error.toString(),
                                  onRetry: () => ref
                                      .read(
                                        customerWalletsStaleProvider(
                                          customerId,
                                        ).notifier,
                                      )
                                      .refresh(force: true),
                                ),
                              )
                            else if (query == null || ledgerState == null)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 36),
                                child: _HistoryInfoCard(
                                  icon: Icons.info_outline,
                                  message:
                                      'Unable to load wallet history right now.',
                                ),
                              )
                            else ...[
                              if (ledgerState.isRefreshing &&
                                  ledgerState.items.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: LinearProgressIndicator(minHeight: 2),
                                ),
                              if (ledgerState.items.isEmpty &&
                                  ledgerState.isRefreshing)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (ledgerState.error != null &&
                                  ledgerState.items.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: ErrorState(
                                    title: 'Could not load history',
                                    message: ledgerState.error.toString(),
                                    onRetry: () => ref
                                        .read(
                                          ledgerPageNotifierProvider(
                                            query,
                                          ).notifier,
                                        )
                                        .refresh(force: true),
                                  ),
                                )
                              else if (ledgerState.items.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 48,
                                  ),
                                  child: EmptyState(
                                    icon: Icons.history_rounded,
                                    title: 'No matches for "$_selectedFilter"',
                                    message:
                                        'No activity found in ${_formatMonthYear(_selectedDate)}.',
                                  ),
                                )
                              else
                                Card(
                                  elevation: 2,
                                  shadowColor: Colors.black.withOpacity(0.05),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      for (final tx in ledgerState.items)
                                        TransactionTile(
                                          tx: tx,
                                          calendarMode: mode,
                                        ),
                                    ],
                                  ),
                                ),
                              if (ledgerState.error != null &&
                                  ledgerState.items.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    ledgerState.error.toString(),
                                    style: const TextStyle(color: Colors.red),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              if (ledgerState.loadingMore)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              if (!ledgerState.loadingMore &&
                                  ledgerState.nextCursor != null &&
                                  ledgerState.nextCursor!.isNotEmpty)
                                Center(
                                  child: TextButton.icon(
                                    onPressed: () => ref
                                        .read(
                                          ledgerPageNotifierProvider(
                                            query,
                                          ).notifier,
                                        )
                                        .loadMore(),
                                    icon: const Icon(Icons.expand_more_rounded),
                                    label: const Text('Load more'),
                                  ),
                                ),
                            ],
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
        .firstWhere((wallet) => wallet.isPrimary, orElse: () => wallets.first)
        .id;
  }

  bool _isSelectedWalletBlocked(
    List<CustomerWallet> wallets,
    String? selectedWalletId,
  ) {
    for (final wallet in wallets) {
      if (wallet.id == selectedWalletId) {
        return !walletAllowsMoneyMovement(wallet.status);
      }
    }
    return false;
  }
}

class _HistoryInfoCard extends StatelessWidget {
  const _HistoryInfoCard({required this.icon, required this.message});

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
