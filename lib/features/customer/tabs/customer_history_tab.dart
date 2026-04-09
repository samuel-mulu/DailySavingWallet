import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/calendar_mode.dart';
import '../../../core/ui/ethiopian_date_picker.dart';
import '../../../data/wallet/models.dart';
import '../../../data/wallet/wallet_repo.dart';
import '../../auth/providers/auth_providers.dart';
import '../../data/repository_providers.dart';
import '../../wallet/widgets/transaction_tile.dart';

class CustomerHistoryTab extends ConsumerStatefulWidget {
  /// Incremented by [CustomerShell] when the History tab is selected to refetch.
  final int refreshSignal;

  const CustomerHistoryTab({super.key, this.refreshSignal = 0});

  @override
  ConsumerState<CustomerHistoryTab> createState() => _CustomerHistoryTabState();
}

class _CustomerHistoryTabState extends ConsumerState<CustomerHistoryTab> {
  final _repo = WalletRepo();
  final _scroll = ScrollController();
  CalendarModeService? _calendarService;

  final List<LedgerTx> _ledger = [];
  Object? _lastDoc;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _customerId;
  String _profileStatus = 'active';
  List<CustomerWallet> _wallets = const [];
  String? _selectedWalletId;

  DateTime _selectedDate = DateTime.now();

  String _selectedFilter = 'All';
  final Map<String, List<String>> _filterMap = {
    'All': [],
    'Withdrawals': ['WITHDRAW_REQUEST', 'WITHDRAW_APPROVE'],
    'Deposits': ['DEPOSIT', 'ADJUSTMENT'],
    'Saving': ['DAILY_PAYMENT'],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCustomerId());
    _initCalendarService();
    _scroll.addListener(_onScroll);
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
      final id = _customerId;
      if (id != null && id.isNotEmpty) {
        _loadFirstPage();
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _initCustomerId() async {
    final uid = ref.read(authUidProvider).valueOrNull;
    if (uid == null) return;
    final profile = await ref.read(appUserProfileProvider(uid).future);
    final customerId = profile.customerId;
    if (mounted) {
      setState(() {
        _customerId = customerId;
        _profileStatus = profile.status;
      });
      if (customerId != null && customerId.isNotEmpty) {
        try {
          final wallets =
              await ref.read(customerRepoProvider).fetchCustomerWallets(customerId);
          if (mounted) {
            setState(() {
              _wallets = wallets;
              _selectedWalletId = wallets
                  .firstWhere((w) => w.isPrimary, orElse: () => wallets.first)
                  .id;
            });
          }
        } catch (_) {}
        _loadFirstPage();
      }
    }
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    if (_customerId == null) return;

    final keptLedger = List<LedgerTx>.from(_ledger);
    setState(() {
      _loading = true;
      _error = null;
      _lastDoc = null;
      _hasMore = true;
    });

    try {
      final start = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final end = DateTime(
        _selectedDate.year,
        _selectedDate.month + 1,
        0,
        23,
        59,
        59,
      );

      final page = await _repo.fetchLedgerPage(
        _customerId!,
        startDate: start,
        endDate: end,
        types: _filterMap[_selectedFilter],
        walletId: _selectedWalletId,
      );
      if (mounted) {
        setState(() {
          _ledger
            ..clear()
            ..addAll(page.items);
          _lastDoc = page.lastDoc;
          _hasMore = page.hasMore;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _ledger
            ..clear()
            ..addAll(keptLedger);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_customerId == null) return;
    final startAfter = _lastDoc;
    if (startAfter == null) return;

    setState(() => _loadingMore = true);
    try {
      final start = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final end = DateTime(
        _selectedDate.year,
        _selectedDate.month + 1,
        0,
        23,
        59,
        59,
      );

      final page = await _repo.fetchLedgerPage(
        _customerId!,
        startAfter: startAfter,
        startDate: start,
        endDate: end,
        types: _filterMap[_selectedFilter],
        walletId: _selectedWalletId,
      );
      setState(() {
        _ledger.addAll(page.items);
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      setState(() => _error ??= e.toString());
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
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
        _selectedDate = picked!;
      });
      _loadFirstPage();
    }
  }

  String _formatMonthYear(DateTime date) {
    if (_calendarService?.value == CalendarMode.ethiopian) {
      final ethDate = date.convertToEthiopian();
      return ETDateFormat('MMMM yyyy', 'am').format(ethDate);
    }
    return DateFormat('MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (_calendarService == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ValueListenableBuilder<CalendarMode>(
      valueListenable: _calendarService!,
      builder: (context, mode, _) {
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
              if (_wallets.length > 1)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedWalletId,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedWalletId = v);
                      _loadFirstPage();
                    },
                    items: _wallets
                        .map(
                          (w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(
                              w.displayName,
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
              if (_profileStatus != 'active' || _isSelectedWalletBlocked())
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _profileStatus != 'active'
                        ? Colors.red.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _profileStatus != 'active'
                          ? Colors.red.shade300
                          : Colors.orange.shade300,
                    ),
                  ),
                  child: Text(
                    _profileStatus != 'active'
                        ? 'Your account is deactivated. Please contact your administrator.'
                        : 'This wallet is frozen/closed. History access is limited.',
                  ),
                ),
              // Filter Chips
              Container(
                height: 60,
                color: Colors.white,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  children: _filterMap.keys.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedFilter = filter);
                            _loadFirstPage();
                          }
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
                  onRefresh: _loadFirstPage,
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (!_loading && _ledger.isEmpty && _error == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Column(
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 64,
                                color: Colors.grey.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No matches for "$_selectedFilter"',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'in ${_formatMonthYear(_selectedDate)}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_ledger.isNotEmpty)
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              for (final tx in _ledger)
                                TransactionTile(
                                  tx: tx,
                                  calendarMode: _calendarService?.value,
                                ),
                            ],
                          ),
                        ),
                      if (_loadingMore)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isSelectedWalletBlocked() {
    for (final w in _wallets) {
      if (w.id == _selectedWalletId) {
        return w.status != 'active';
      }
    }
    return false;
  }
}
