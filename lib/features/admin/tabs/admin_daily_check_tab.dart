import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/money/money.dart';
import '../../../core/routing/routes.dart';
import '../../../core/ui/date_selector.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/filter_count_chip.dart';
import '../../../data/customers/customer_model.dart';
import '../../../data/wallet/models.dart';
import '../../../data/wallet/wallet_repo.dart';
import '../../customers/customer_list_notifier.dart';
import '../../wallet/wallet_providers.dart';
import '../customers/customer_detail_screen.dart';
import '../customers/widgets/customer_profile_avatar.dart';

class AdminDailyCheckTab extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime>? onSelectedDateChanged;

  const AdminDailyCheckTab({
    super.key,
    required this.selectedDate,
    this.onSelectedDateChanged,
  });

  @override
  ConsumerState<AdminDailyCheckTab> createState() => _AdminDailyCheckTabState();
}

class _AdminDailyCheckTabState extends ConsumerState<AdminDailyCheckTab> {
  final _searchCtrl = TextEditingController();
  final _uuid = const Uuid();
  String _searchQuery = '';
  late DateTime _selectedDate;
  Timer? _searchDebounce;
  _AlphabetSortOrder _sortOrder = _AlphabetSortOrder.az;
  _DailyCheckFilter _dailyFilter = _DailyCheckFilter.all;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerListNotifierProvider.notifier).loadInitial();
    });
  }

  @override
  void didUpdateWidget(covariant AdminDailyCheckTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _selectedDate = widget.selectedDate;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _txDay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _customerWalletGroup(
    BuildContext context,
    ColorScheme colorScheme,
    Customer customer,
    List<CustomerWallet> wallets,
    Set<String> recordedWalletIds,
  ) {
    final allSaved = wallets.isNotEmpty &&
        wallets.every((w) => recordedWalletIds.contains(w.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showCustomerOverviewModal(
              context,
              customer,
              wallets: wallets,
              recordedWalletIds: recordedWalletIds,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  CustomerProfileAvatar(
                    customer: customer,
                    radius: 22,
                    enablePreview: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${customer.companyName} • ${wallets.length} wallet(s)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (allSaved)
                    const Icon(Icons.check_circle, color: Colors.green, size: 22)
                  else
                    Icon(Icons.pending_actions, color: Colors.orange.shade700),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 56, right: 4),
          child: Column(
            children: [
              for (final w in wallets) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              w.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              MoneyEtb.formatCents(w.balanceCents),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (recordedWalletIds.contains(w.id))
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        )
                      else
                        Icon(
                          Icons.radio_button_unchecked,
                          color: Colors.grey.shade500,
                          size: 18,
                        ),
                      IconButton(
                        icon: const Icon(Icons.savings_outlined),
                        iconSize: 20,
                        color: Colors.green.shade700,
                        tooltip: 'Daily Saving',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () => _showPaymentModal(
                          context,
                          ref,
                          customer,
                          w,
                          'DAILY_PAYMENT',
                          _selectedDate,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 20,
                        color: Colors.blue.shade700,
                        tooltip: 'Deposit',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () => _showPaymentModal(
                          context,
                          ref,
                          customer,
                          w,
                          'DEPOSIT',
                          _selectedDate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showCustomerOverviewModal(
    BuildContext context,
    Customer customer, {
    required List<CustomerWallet> wallets,
    required Set<String> recordedWalletIds,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final allSaved = wallets.isNotEmpty &&
        wallets.every((w) => recordedWalletIds.contains(w.id));
    final createdAt = customer.createdAt;
    final createdLabel = createdAt == null
        ? 'Not available'
        : MaterialLocalizations.of(context).formatMediumDate(createdAt);

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CustomerProfileAvatar(
                      customer: customer,
                      radius: 30,
                      enablePreview: true,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.fullName,
                            style: Theme.of(sheetContext).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer.companyName,
                            style: Theme.of(sheetContext).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    FilterCountChip(
                      label: allSaved ? 'All saved' : 'Needs save',
                      count: null,
                      selected: true,
                      icon: allSaved ? Icons.check_circle : Icons.pending_actions,
                      onTap: null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Wallets',
                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                for (final w in wallets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${MoneyEtb.formatCents(w.balanceCents)} • daily ${MoneyEtb.formatCents(w.dailyTargetCents)}',
                                style: Theme.of(sheetContext).textTheme.bodySmall
                                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          recordedWalletIds.contains(w.id)
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: recordedWalletIds.contains(w.id)
                              ? Colors.green
                              : colorScheme.outline,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                _CustomerDetailLine(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: customer.phone,
                ),
                _CustomerDetailLine(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: customer.email,
                ),
                _CustomerDetailLine(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: customer.address,
                ),
                _CustomerDetailLine(
                  icon: Icons.calendar_today_outlined,
                  label: 'Created',
                  value: createdLabel,
                ),
                _CustomerDetailLine(
                  icon: Icons.verified_user_outlined,
                  label: 'Status',
                  value: CustomerLifecycleStatus.displayLabel(customer.status),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerDetailScreen(
                            customerId: customer.customerId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Full Customer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPaymentModal(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
    CustomerWallet wallet,
    String type,
    DateTime initialDate,
  ) {
    final amountCtrl = TextEditingController(
      text: type == 'DAILY_PAYMENT'
          ? MoneyEtb.formatCents(
              wallet.dailyTargetCents,
            ).replaceAll('ETB ', '')
          : '',
    );
    final noteCtrl = TextEditingController();
    DateTime modalSelectedDate = initialDate;
    bool busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: type == 'DAILY_PAYMENT'
                            ? Colors.green.shade100
                            : Colors.blue.shade100,
                        child: Icon(
                          type == 'DAILY_PAYMENT'
                              ? Icons.savings
                              : Icons.add_circle,
                          color: type == 'DAILY_PAYMENT'
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type == 'DAILY_PAYMENT'
                                  ? 'Daily Saving'
                                  : 'Deposit',
                              style: Theme.of(sheetContext).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${customer.fullName} • ${wallet.label}',
                              style: Theme.of(sheetContext).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      sheetContext,
                                    ).colorScheme.secondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Date Selector
                  DateSelector(
                    selectedDate: modalSelectedDate,
                    onDateChanged: (date) =>
                        setSheetState(() => modalSelectedDate = date),
                    showQuickSelect: true,
                  ),
                  const SizedBox(height: 20),

                  // Amount
                  TextField(
                    controller: amountCtrl,
                    decoration: InputDecoration(
                      labelText: 'Amount (ETB)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.attach_money),
                      helperText: type == 'DAILY_PAYMENT'
                          ? 'Daily target: ${MoneyEtb.formatCents(wallet.dailyTargetCents)}'
                          : null,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),

                  // Note
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            setSheetState(() => busy = true);

                            // Debug logging for daily saving and deposit
                            if (type == 'DAILY_PAYMENT') {
                              print('🟢 [Daily Saving] Starting submission...');
                              print('   Customer ID: ${customer.customerId}');
                              print('   Customer Name: ${customer.fullName}');
                              print('   Amount Text: ${amountCtrl.text}');
                              print('   Selected Date: $modalSelectedDate');
                              print('   Note: ${noteCtrl.text}');
                            } else {
                              print('🔵 [Deposit] Starting submission...');
                              print('   Customer ID: ${customer.customerId}');
                              print('   Customer Name: ${customer.fullName}');
                              print('   Amount Text: ${amountCtrl.text}');
                              print('   Selected Date: $modalSelectedDate');
                              print('   Note: ${noteCtrl.text}');
                            }

                            try {
                              // Validate amount
                              if (amountCtrl.text.trim().isEmpty) {
                                throw const FormatException(
                                  'Amount is required',
                                );
                              }

                              final cents = MoneyEtb.parseEtbToCents(
                                amountCtrl.text,
                              );
                              final note = noteCtrl.text.trim().isEmpty
                                  ? null
                                  : noteCtrl.text.trim();
                              final txDateMillis = dateToTxMillis(
                                modalSelectedDate,
                              );

                              if (type == 'DAILY_PAYMENT') {
                                print('   Amount in cents: $cents');
                                print('   TxDate millis: $txDateMillis');
                                print('   Calling recordDailySaving...');

                                final snap = await WalletRepo()
                                    .recordDailySaving(
                                      customerId: customer.customerId,
                                      walletId: wallet.id,
                                      amountCents: cents,
                                      txDateMillis: txDateMillis,
                                      note: note,
                                      idempotencyKey: _uuid.v4(),
                                    );

                                if (snap != null) {
                                  ref
                                      .read(
                                        walletStaleProvider(
                                          (
                                            customerId: customer.customerId,
                                            walletId: wallet.id,
                                          ),
                                        ).notifier,
                                      )
                                      .applyWallet(snap);
                                }
                                final d = modalSelectedDate;
                                final td =
                                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                                ref
                                    .read(
                                      recordedDailyWalletIdsProvider(
                                        td,
                                      ).notifier,
                                    )
                                    .addRecordedLocally(wallet.id);
                                ref.invalidate(dailyPendingSummaryProvider(td));
                                ref.invalidate(walletsForCustomerListProvider);

                                print(
                                  '✅ [Daily Saving] Successfully recorded!',
                                );
                              } else {
                                print('   Amount in cents: $cents');
                                print('   TxDate millis: $txDateMillis');
                                print('   Calling recordDeposit...');

                                final snapDep = await WalletRepo()
                                    .recordDeposit(
                                      customerId: customer.customerId,
                                      walletId: wallet.id,
                                      amountCents: cents,
                                      txDateMillis: txDateMillis,
                                      note: note,
                                      idempotencyKey: _uuid.v4(),
                                    );

                                if (snapDep != null) {
                                  ref
                                      .read(
                                        walletStaleProvider(
                                          (
                                            customerId: customer.customerId,
                                            walletId: wallet.id,
                                          ),
                                        ).notifier,
                                      )
                                      .applyWallet(snapDep);
                                }
                                ref.invalidate(walletsForCustomerListProvider);

                                print('✅ [Deposit] Successfully recorded!');
                              }

                              unawaited(
                                ref
                                    .read(customerListNotifierProvider.notifier)
                                    .refresh(force: true),
                              );

                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          type == 'DAILY_PAYMENT'
                                              ? '✓ Daily saving recorded for ${customer.fullName}'
                                              : '✓ Deposit recorded for ${customer.fullName}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.green.shade600,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            } on FormatException catch (e) {
                              setSheetState(() => busy = false);

                              if (type == 'DAILY_PAYMENT') {
                                print(
                                  '❌ [Daily Saving] FormatException: ${e.message}',
                                );
                              } else {
                                print(
                                  '❌ [Deposit] FormatException: ${e.message}',
                                );
                              }

                              if (!sheetContext.mounted) return;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Invalid input: ${e.message}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.orange.shade700,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            } catch (e, stackTrace) {
                              setSheetState(() => busy = false);

                              if (type == 'DAILY_PAYMENT') {
                                print('❌ [Daily Saving] Error occurred:');
                                print('   Error: $e');
                                print('   Stack trace: $stackTrace');
                              } else {
                                print('❌ [Deposit] Error occurred:');
                                print('   Error: $e');
                                print('   Stack trace: $stackTrace');
                              }

                              if (!sheetContext.mounted) return;

                              // Parse error message
                              String errorMessage = e.toString();
                              if (errorMessage.contains('permission-denied')) {
                                errorMessage =
                                    '🔒 Access denied. Admin permission required.';
                              } else if (errorMessage.contains(
                                'unauthenticated',
                              )) {
                                errorMessage = '🔑 Please log in again.';
                              } else if (errorMessage.contains('INTERNAL')) {
                                errorMessage =
                                    '⚠️ Server error. Please try again or contact support.';
                              } else if (errorMessage.length > 100) {
                                errorMessage =
                                    '❌ Operation failed. Check console for details.';
                              }

                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.error,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Error',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(errorMessage),
                                    ],
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                  duration: const Duration(seconds: 6),
                                  action: SnackBarAction(
                                    label: 'Dismiss',
                                    textColor: Colors.white,
                                    onPressed: () {},
                                  ),
                                ),
                              );
                            }
                          },
                    icon: busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            type == 'DAILY_PAYMENT'
                                ? Icons.savings
                                : Icons.add_circle,
                          ),
                    label: Text(
                      type == 'DAILY_PAYMENT'
                          ? 'Record Daily Saving'
                          : 'Record Deposit',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: type == 'DAILY_PAYMENT'
                          ? Colors.green.shade600
                          : Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Check'),
        actions: [
          PopupMenuButton<_AlphabetSortOrder>(
            tooltip: 'Sort customers',
            initialValue: _sortOrder,
            onSelected: (value) => setState(() => _sortOrder = value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _AlphabetSortOrder.az,
                child: Text('Sort A-Z'),
              ),
              PopupMenuItem(
                value: _AlphabetSortOrder.za,
                child: Text('Sort Z-A'),
              ),
            ],
            icon: Icon(
              _sortOrder == _AlphabetSortOrder.az
                  ? Icons.sort_by_alpha
                  : Icons.sort_by_alpha_outlined,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Selector at the top - Static, doesn't reload heavily
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DateSelector(
              selectedDate: _selectedDate,
              onDateChanged: (date) {
                setState(() => _selectedDate = date);
                widget.onSelectedDateChanged?.call(date);
                ref
                    .read(
                      recordedDailyWalletIdsProvider(_txDay(date)).notifier,
                    )
                    .ensureFresh(force: true);
                ref.invalidate(dailyPendingSummaryProvider(_txDay(date)));
              },
            ),
          ),

          // Search Bar - Static
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                  ref
                      .read(customerListNotifierProvider.notifier)
                      .loadInitial(search: v.trim());
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or company...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          ref
                              .read(customerListNotifierProvider.notifier)
                              .loadInitial(search: '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Content Area
          Expanded(
            child: Builder(
              builder: (context) {
                final txDay = _txDay(_selectedDate);
                final recordedStale = ref.watch(
                  recordedDailyWalletIdsProvider(txDay),
                );
                final listState = ref.watch(customerListNotifierProvider);
                final walletsMapAsync = ref.watch(walletsForCustomerListProvider);

                if (recordedStale.error != null &&
                    (recordedStale.data == null ||
                        recordedStale.data!.isEmpty)) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        'Error loading checkmarks:\n\n${recordedStale.error}',
                      ),
                    ),
                  );
                }

                if (listState.error != null && listState.items.isEmpty) {
                  return Center(child: Text('Error: ${listState.error}'));
                }

                if (listState.items.isEmpty &&
                    listState.isRefreshing &&
                    !listState.loadingMore) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (walletsMapAsync.isLoading && !walletsMapAsync.hasValue) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (walletsMapAsync.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        'Error loading wallets:\n\n${walletsMapAsync.error}',
                      ),
                    ),
                  );
                }

                final recordedWalletIds =
                    recordedStale.data ?? const <String>{};
                final walletsMap = walletsMapAsync.value ?? {};
                final customers = _sortedCustomers(listState.items);
                bool customerFullySaved(Customer c) {
                  final ws = walletsMap[c.customerId] ?? const <CustomerWallet>[];
                  if (ws.isEmpty) return false;
                  return ws.every((w) => recordedWalletIds.contains(w.id));
                }

                final allWallets = walletsMap.values.expand((ws) => ws);
                final totalWalletCount = allWallets.length;
                final savedWalletCount = allWallets
                    .where((w) => recordedWalletIds.contains(w.id))
                    .length;
                final notSavedWalletCount = totalWalletCount - savedWalletCount;
                final filteredCustomers =
                    _applyDailyFilter(customers, customerFullySaved);

                if (customers.isEmpty) {
                  final hasSearch = _searchQuery.isNotEmpty;

                  return EmptyState(
                    icon: hasSearch
                        ? Icons.person_search
                        : Icons.playlist_add_circle_outlined,
                    title: hasSearch
                        ? 'No customers found'
                        : 'No customers to check today',
                    message: hasSearch
                        ? 'Try a different search term or clear the filter.'
                        : 'Create a customer first, then daily savings and deposits will appear here.',
                    action: FilledButton.icon(
                      onPressed: () async {
                        if (hasSearch) {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          ref
                              .read(customerListNotifierProvider.notifier)
                              .loadInitial(search: '');
                          return;
                        }

                        await AppRoutes.goToAdminCreateCustomer(context);
                      },
                      icon: Icon(
                        hasSearch ? Icons.clear : Icons.person_add_alt_1,
                      ),
                      label: Text(
                        hasSearch ? 'Clear Search' : 'Create Customer',
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterCountChip(
                              label: 'All',
                              count: totalWalletCount,
                              selected: _dailyFilter == _DailyCheckFilter.all,
                              icon: Icons.people_alt_outlined,
                              onTap: () => setState(
                                () => _dailyFilter = _DailyCheckFilter.all,
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilterCountChip(
                              label: 'Saved',
                              count: savedWalletCount,
                              selected: _dailyFilter == _DailyCheckFilter.saved,
                              icon: Icons.check_circle_outline,
                              onTap: () => setState(
                                () => _dailyFilter = _DailyCheckFilter.saved,
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilterCountChip(
                              label: 'Not saved',
                              count: notSavedWalletCount,
                              selected:
                                  _dailyFilter == _DailyCheckFilter.notSaved,
                              icon: Icons.pending_actions_outlined,
                              onTap: () => setState(
                                () => _dailyFilter = _DailyCheckFilter.notSaved,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: filteredCustomers.isEmpty
                          ? EmptyState(
                              icon: _dailyFilter == _DailyCheckFilter.saved
                                  ? Icons.check_circle_outline
                                  : Icons.pending_actions_outlined,
                              title: _dailyFilter == _DailyCheckFilter.saved
                                  ? 'No saved customers for this date'
                                  : 'No pending customers for this date',
                              message: _dailyFilter == _DailyCheckFilter.saved
                                  ? 'Switch back to All to see every customer for the selected day.'
                                  : 'Everyone in the current list is already marked as saved for this date.',
                              action: FilledButton.icon(
                                onPressed: () => setState(
                                  () => _dailyFilter = _DailyCheckFilter.all,
                                ),
                                icon: const Icon(Icons.filter_alt_off),
                                label: const Text('Show All'),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () async {
                                await ref
                                    .read(
                                      recordedDailyWalletIdsProvider(
                                        txDay,
                                      ).notifier,
                                    )
                                    .refresh(force: true);
                                await ref
                                    .read(customerListNotifierProvider.notifier)
                                    .refresh(force: true);
                                ref.invalidate(walletsForCustomerListProvider);
                                ref.invalidate(dailyPendingSummaryProvider(txDay));
                              },
                              child: ListView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                children: [
                                  if (listState.isRefreshing ||
                                      recordedStale.isRefreshing)
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: LinearProgressIndicator(
                                        minHeight: 2,
                                      ),
                                    ),
                                  for (
                                    var i = 0;
                                    i < filteredCustomers.length;
                                    i++
                                  ) ...[
                                    if (i > 0) const Divider(height: 1),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: _customerWalletGroup(
                                        context,
                                        colorScheme,
                                        filteredCustomers[i],
                                        walletsMap[filteredCustomers[i]
                                                .customerId] ??
                                            const <CustomerWallet>[],
                                        recordedWalletIds,
                                      ),
                                    ),
                                  ],
                                  if (listState.nextCursor != null) ...[
                                    const Divider(height: 1),
                                    if (listState.loadingMore)
                                      const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    else
                                      Center(
                                        child: TextButton(
                                          onPressed: () => ref
                                              .read(
                                                customerListNotifierProvider
                                                    .notifier,
                                              )
                                              .loadMore(),
                                          child: const Text('Load more'),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Customer> _sortedCustomers(List<Customer> input) {
    final customers = [...input];
    customers.sort((a, b) {
      final compare = a.fullName.toLowerCase().compareTo(
        b.fullName.toLowerCase(),
      );
      return _sortOrder == _AlphabetSortOrder.az ? compare : -compare;
    });
    return customers;
  }

  List<Customer> _applyDailyFilter(
    List<Customer> customers,
    bool Function(Customer) customerFullySaved,
  ) {
    switch (_dailyFilter) {
      case _DailyCheckFilter.all:
        return customers;
      case _DailyCheckFilter.saved:
        return customers.where(customerFullySaved).toList();
      case _DailyCheckFilter.notSaved:
        return customers
            .where((c) => !customerFullySaved(c))
            .toList();
    }
  }
}

enum _AlphabetSortOrder { az, za }

enum _DailyCheckFilter { all, saved, notSaved }

class _CustomerDetailLine extends StatelessWidget {
  const _CustomerDetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Not available' : value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
