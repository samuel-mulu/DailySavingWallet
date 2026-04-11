import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/money/money.dart';
import '../../../core/routing/routes.dart';
import '../../../core/ui/date_selector.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/filter_count_chip.dart';
import '../../../core/logging/app_logger.dart';
import '../../../data/customers/customer_model.dart';
import '../../../data/wallet/models.dart';
import '../../../data/wallet/wallet_repo.dart';
import '../../customers/customer_list_notifier.dart';
import '../../wallet/wallet_providers.dart';
import '../daily_saving/admin_bulk_daily_saving_sheet.dart';
import '../customers/customer_detail_screen.dart';
import '../customers/widgets/customer_profile_avatar.dart';

class AdminDailyCheckTab extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime>? onSelectedDateChanged;
  final AlphabetSortOrder sortOrder;
  final ValueChanged<AlphabetSortOrder>? onSortOrderChanged;
  final DailyCheckViewStyle viewStyle;
  final ValueChanged<DailyCheckViewStyle>? onViewStyleChanged;

  const AdminDailyCheckTab({
    super.key,
    required this.selectedDate,
    this.onSelectedDateChanged,
    this.sortOrder = AlphabetSortOrder.az,
    this.onSortOrderChanged,
    this.viewStyle = DailyCheckViewStyle.grouped,
    this.onViewStyleChanged,
  });

  @override
  ConsumerState<AdminDailyCheckTab> createState() => _AdminDailyCheckTabState();
}

class _AdminDailyCheckTabState extends ConsumerState<AdminDailyCheckTab> {
  static const String _unassignedGroupKey = '__unassigned__';
  final _searchCtrl = TextEditingController();
  final _uuid = const Uuid();
  String _searchQuery = '';
  late DateTime _selectedDate;
  Timer? _searchDebounce;
  _DailyCheckFilter _dailyFilter = _DailyCheckFilter.all;
  final Set<String> _expandedCustomerIds = <String>{};
  final Set<String> _expandedGroupKeys = <String>{};
  late AlphabetSortOrder _localSortOrder;
  late DailyCheckViewStyle _localViewStyle;

  AlphabetSortOrder get _sortOrder =>
      widget.onSortOrderChanged != null ? widget.sortOrder : _localSortOrder;

  DailyCheckViewStyle get _viewStyle =>
      widget.onViewStyleChanged != null ? widget.viewStyle : _localViewStyle;

  @override
  void initState() {
    super.initState();
    _localSortOrder = widget.sortOrder;
    _localViewStyle = widget.viewStyle;
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
    if (widget.onSortOrderChanged == null &&
        oldWidget.sortOrder != widget.sortOrder) {
      _localSortOrder = widget.sortOrder;
    }
    if (widget.onViewStyleChanged == null &&
        oldWidget.viewStyle != widget.viewStyle) {
      _localViewStyle = widget.viewStyle;
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

  bool _isCustomerExpanded(String customerId) {
    return _expandedCustomerIds.contains(customerId);
  }

  void _toggleCustomerExpanded(String customerId) {
    setState(() {
      if (!_expandedCustomerIds.remove(customerId)) {
        _expandedCustomerIds.add(customerId);
      }
    });
  }

  bool _isGroupExpanded(String groupKey) {
    return _expandedGroupKeys.contains(groupKey);
  }

  void _toggleGroupExpanded(String groupKey) {
    setState(() {
      if (!_expandedGroupKeys.remove(groupKey)) {
        _expandedGroupKeys.add(groupKey);
      }
    });
  }

  Widget _customerWalletGroup(
    BuildContext context,
    ColorScheme colorScheme,
    Customer customer,
    List<CustomerWallet> wallets,
    Set<String> recordedWalletIds, {
    required bool showGroupLineOnCustomer,
  }) {
    final walletSummary = _summarizeWallets(wallets, recordedWalletIds);
    final allSaved =
        walletSummary.totalWalletCount > 0 &&
        walletSummary.pendingWalletCount == 0;
    final multiWallet = wallets.length > 1;
    final isExpanded =
        multiWallet ? _isCustomerExpanded(customer.customerId) : true;

    final statusIcon = allSaved
        ? Icon(
            Icons.check_circle_outline,
            color: colorScheme.primary,
            size: 22,
          )
        : Icon(
            Icons.pending_outlined,
            color: colorScheme.tertiary,
            size: 22,
          );

    final subtitle = multiWallet
        ? '${customer.companyName} • ${walletSummary.totalWalletCount} wallets • ${walletSummary.savedWalletCount} saved • ${walletSummary.pendingWalletCount} pending'
        : (wallets.isEmpty
            ? '${customer.companyName} • No wallet'
            : '${customer.companyName} • ${wallets.first.label} • ${MoneyEtb.formatCents(wallets.first.balanceCents)}');

    Widget walletActionIcons(CustomerWallet w) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (recordedWalletIds.contains(w.id))
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  Icons.check_circle_outline,
                  color: colorScheme.primary,
                  size: 18,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  Icons.radio_button_unchecked,
                  color: colorScheme.outline,
                  size: 18,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.savings_outlined),
              iconSize: 22,
              color: colorScheme.primary,
              tooltip: 'Daily Saving',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
              iconSize: 22,
              color: colorScheme.secondary,
              tooltip: 'Deposit',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
        );

    Widget multiWalletRows() => Padding(
          padding: const EdgeInsets.only(left: 56, right: 4),
          child: Column(
            children: [
              for (var i = 0; i < wallets.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wallets[i].label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              MoneyEtb.formatCents(wallets[i].balanceCents),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      walletActionIcons(wallets[i]),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );

    final singleWallet = wallets.length == 1 ? wallets.first : null;

    final customerBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Material(
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
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                  subtitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (showGroupLineOnCustomer) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Group: ${customer.groupName}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (singleWallet != null) walletActionIcons(singleWallet),
              if (singleWallet == null) statusIcon,
              if (multiWallet) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () =>
                      _toggleCustomerExpanded(customer.customerId),
                  tooltip: isExpanded ? 'Hide wallets' : 'Show wallets',
                  icon: AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: isExpanded ? 0.5 : 0,
                    child: const Icon(Icons.expand_more_rounded),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ),
        if (multiWallet)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: multiWalletRows(),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
      ],
    );

    if (showGroupLineOnCustomer) {
      return customerBlock;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: customerBlock,
    );
  }

  Future<void> _showCustomerOverviewModal(
    BuildContext context,
    Customer customer, {
    required List<CustomerWallet> wallets,
    required Set<String> recordedWalletIds,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final allSaved =
        wallets.isNotEmpty &&
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
                      icon: allSaved
                          ? Icons.check_circle
                          : Icons.pending_actions,
                      onTap: null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Wallets',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
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
                  icon: Icons.group_work_outlined,
                  label: 'Group',
                  value: customer.groupName,
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
    if (type == 'DAILY_PAYMENT') {
      unawaited(
        showAdminBulkDailySavingSheet(
          context: context,
          customerId: customer.customerId,
          customerName: customer.fullName,
          wallet: wallet,
          onWalletUpdated: (snap) async {
            if (snap != null) {
              ref
                  .read(
                    walletStaleProvider((
                      customerId: customer.customerId,
                      walletId: wallet.id,
                    )).notifier,
                  )
                  .applyWallet(snap);
            }
          },
          onRefreshAfterBatch: () {
            ref.invalidate(walletsForCustomerListProvider);
            ref.invalidate(dailyWalletCountsProvider(_txDay(_selectedDate)));
            unawaited(ref.read(customerListNotifierProvider.notifier).refresh(force: true));
          },
          onOpenCustomerDetail: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerDetailScreen(customerId: customer.customerId),
              ),
            );
          },
        ),
      );
      return;
    }

    final amountCtrl = TextEditingController(
      text: type == 'DAILY_PAYMENT'
          ? MoneyEtb.formatCents(wallet.dailyTargetCents).replaceAll('ETB ', '')
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
                            AppLogger.debug(
                              '[AdminDailyCheckTab] Submit $type for '
                              'customer=${customer.customerId}, '
                              'wallet=${wallet.id}, '
                              'date=$modalSelectedDate',
                            );

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
                                AppLogger.debug(
                                  '[AdminDailyCheckTab] recordDailySaving '
                                  'wallet=${wallet.id}, cents=$cents, '
                                  'txDateMillis=$txDateMillis',
                                );

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
                                        walletStaleProvider((
                                          customerId: customer.customerId,
                                          walletId: wallet.id,
                                        )).notifier,
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
                                ref.invalidate(dailyWalletCountsProvider(td));
                                ref.invalidate(walletsForCustomerListProvider);
                                AppLogger.debug(
                                  '[AdminDailyCheckTab] Daily saving recorded '
                                  'for wallet=${wallet.id}',
                                );
                              } else {
                                AppLogger.debug(
                                  '[AdminDailyCheckTab] recordDeposit '
                                  'wallet=${wallet.id}, cents=$cents, '
                                  'txDateMillis=$txDateMillis',
                                );

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
                                        walletStaleProvider((
                                          customerId: customer.customerId,
                                          walletId: wallet.id,
                                        )).notifier,
                                      )
                                      .applyWallet(snapDep);
                                }
                                ref.invalidate(walletsForCustomerListProvider);
                                AppLogger.debug(
                                  '[AdminDailyCheckTab] Deposit recorded '
                                  'for wallet=${wallet.id}',
                                );
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
                              AppLogger.warn(
                                '[AdminDailyCheckTab] Invalid $type input',
                                e.message,
                              );

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
                              AppLogger.error(
                                '[AdminDailyCheckTab] Failed to record $type',
                                e,
                                stackTrace,
                              );

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
                    .read(recordedDailyWalletIdsProvider(_txDay(date)).notifier)
                    .ensureFresh(force: true);
                ref.invalidate(dailyWalletCountsProvider(_txDay(date)));
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
                final dailyWalletCountsAsync = ref.watch(
                  dailyWalletCountsProvider(txDay),
                );
                final listState = ref.watch(customerListNotifierProvider);
                final walletsMapAsync = ref.watch(
                  walletsForCustomerListProvider,
                );

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
                final customerWalletSummaries = <String, _DailyWalletSummary>{
                  for (final customer in customers)
                    customer.customerId: _summarizeWallets(
                      walletsMap[customer.customerId] ??
                          const <CustomerWallet>[],
                      recordedWalletIds,
                    ),
                };
                bool customerHasSavedWallet(Customer c) {
                  return (customerWalletSummaries[c.customerId]
                              ?.savedWalletCount ??
                          0) >
                      0;
                }

                bool customerHasPendingWallet(Customer c) {
                  return (customerWalletSummaries[c.customerId]
                              ?.pendingWalletCount ??
                          0) >
                      0;
                }

                final visibleWalletSummary = _combineWalletSummaries(
                  customerWalletSummaries.values,
                );
                final totalWalletCount =
                    dailyWalletCountsAsync.valueOrNull?.activeWalletCount ??
                    visibleWalletSummary.totalWalletCount;
                final savedWalletCount =
                    dailyWalletCountsAsync.valueOrNull?.savedWalletCount ??
                    visibleWalletSummary.savedWalletCount;
                final notSavedWalletCount =
                    dailyWalletCountsAsync.valueOrNull?.pendingWalletCount ??
                    visibleWalletSummary.pendingWalletCount;
                final filteredCustomers = _applyDailyFilter(
                  customers,
                  customerHasSavedWallet: customerHasSavedWallet,
                  customerHasPendingWallet: customerHasPendingWallet,
                );

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
                              label: 'All wallets',
                              count: totalWalletCount,
                              selected: _dailyFilter == _DailyCheckFilter.all,
                              icon: Icons.account_balance_wallet_outlined,
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
                                  ? 'No customers with saved wallets'
                                  : 'No customers with pending wallets',
                              message: _dailyFilter == _DailyCheckFilter.saved
                                  ? 'Switch back to All to see every customer for the selected date.'
                                  : 'Everyone in the current list is fully saved for the selected date.',
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
                                ref.invalidate(
                                  dailyWalletCountsProvider(txDay),
                                );
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
                                  ...(_viewStyle == DailyCheckViewStyle.sorted
                                      ? _buildSortedCustomerChildren(
                                          context,
                                          colorScheme,
                                          filteredCustomers,
                                          walletsMap,
                                          recordedWalletIds,
                                        )
                                      : _buildGroupedCustomerChildren(
                                          context,
                                          colorScheme,
                                          filteredCustomers,
                                          walletsMap,
                                          recordedWalletIds,
                                          customerWalletSummaries,
                                        )),
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
      return _sortOrder == AlphabetSortOrder.az ? compare : -compare;
    });
    return customers;
  }

  List<_DailyCustomerGroupSection> _groupedCustomerSections(
    List<Customer> customers,
  ) {
    final byKey = <String, List<Customer>>{};
    final byTitle = <String, String>{};

    for (final customer in customers) {
      final key = customer.group?.id ?? _unassignedGroupKey;
      byKey.putIfAbsent(key, () => <Customer>[]).add(customer);
      byTitle[key] = customer.group?.name ?? 'Not assigned';
    }

    final keys = byKey.keys.toList()
      ..sort((a, b) {
        final aUnassigned = a == _unassignedGroupKey;
        final bUnassigned = b == _unassignedGroupKey;
        if (aUnassigned != bUnassigned) {
          return aUnassigned ? 1 : -1;
        }
        final compare = byTitle[a]!.toLowerCase().compareTo(
          byTitle[b]!.toLowerCase(),
        );
        return _sortOrder == AlphabetSortOrder.az ? compare : -compare;
      });

    return keys
        .map(
          (key) => _DailyCustomerGroupSection(
            key: key,
            title: byTitle[key]!,
            customers: byKey[key]!,
            isUngrouped: key == _unassignedGroupKey,
          ),
        )
        .toList(growable: false);
  }

  List<Widget> _buildSortedCustomerChildren(
    BuildContext context,
    ColorScheme colorScheme,
    List<Customer> customers,
    Map<String, List<CustomerWallet>> walletsMap,
    Set<String> recordedWalletIds,
  ) {
    final children = <Widget>[];
    for (var index = 0; index < customers.length; index++) {
      if (index > 0) {
        children.add(const Divider(height: 1));
      }
      final customer = customers[index];
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _customerWalletGroup(
            context,
            colorScheme,
            customer,
            walletsMap[customer.customerId] ?? const <CustomerWallet>[],
            recordedWalletIds,
            showGroupLineOnCustomer: true,
          ),
        ),
      );
    }
    return children;
  }

  List<Widget> _buildGroupedCustomerChildren(
    BuildContext context,
    ColorScheme colorScheme,
    List<Customer> customers,
    Map<String, List<CustomerWallet>> walletsMap,
    Set<String> recordedWalletIds,
    Map<String, _DailyWalletSummary> customerWalletSummaries,
  ) {
    final sections = _groupedCustomerSections(customers);
    final children = <Widget>[];

    for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      final section = sections[sectionIndex];
      if (sectionIndex > 0) {
        children.add(const SizedBox(height: 16));
      }

      final sectionWalletSummary = _combineWalletSummaries(
        section.customers.map(
          (customer) =>
              customerWalletSummaries[customer.customerId] ??
              const _DailyWalletSummary(),
        ),
      );
      children.add(
        _DailyGroupSectionHeader(
          title: section.title,
          subtitle:
              '${section.customers.length} customer(s) • ${sectionWalletSummary.totalWalletCount} wallet(s)',
          icon: section.isUngrouped
              ? Icons.person_off_outlined
              : Icons.group_work_outlined,
          savedWalletCount: sectionWalletSummary.savedWalletCount,
          pendingWalletCount: sectionWalletSummary.pendingWalletCount,
          isExpanded: _isGroupExpanded(section.key),
          onTap: () => _toggleGroupExpanded(section.key),
        ),
      );
      if (_isGroupExpanded(section.key)) {
        children.add(const SizedBox(height: 8));
        for (
          var customerIndex = 0;
          customerIndex < section.customers.length;
          customerIndex++
        ) {
          if (customerIndex > 0) {
            children.add(const Divider(height: 1));
          }
          final customer = section.customers[customerIndex];
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _customerWalletGroup(
                context,
                colorScheme,
                customer,
                walletsMap[customer.customerId] ?? const <CustomerWallet>[],
                recordedWalletIds,
                showGroupLineOnCustomer: false,
              ),
            ),
          );
        }
      }
    }

    return children;
  }

  List<Customer> _applyDailyFilter(
    List<Customer> customers, {
    required bool Function(Customer) customerHasSavedWallet,
    required bool Function(Customer) customerHasPendingWallet,
  }) {
    switch (_dailyFilter) {
      case _DailyCheckFilter.all:
        return customers;
      case _DailyCheckFilter.saved:
        return customers.where(customerHasSavedWallet).toList();
      case _DailyCheckFilter.notSaved:
        return customers.where(customerHasPendingWallet).toList();
    }
  }

  _DailyWalletSummary _summarizeWallets(
    List<CustomerWallet> wallets,
    Set<String> recordedWalletIds,
  ) {
    final totalWalletCount = wallets.length;
    final savedWalletCount = wallets
        .where((wallet) => recordedWalletIds.contains(wallet.id))
        .length;
    return _DailyWalletSummary(
      totalWalletCount: totalWalletCount,
      savedWalletCount: savedWalletCount,
      pendingWalletCount: totalWalletCount - savedWalletCount,
    );
  }

  _DailyWalletSummary _combineWalletSummaries(
    Iterable<_DailyWalletSummary> summaries,
  ) {
    var totalWalletCount = 0;
    var savedWalletCount = 0;
    var pendingWalletCount = 0;

    for (final summary in summaries) {
      totalWalletCount += summary.totalWalletCount;
      savedWalletCount += summary.savedWalletCount;
      pendingWalletCount += summary.pendingWalletCount;
    }

    return _DailyWalletSummary(
      totalWalletCount: totalWalletCount,
      savedWalletCount: savedWalletCount,
      pendingWalletCount: pendingWalletCount,
    );
  }
}

enum AlphabetSortOrder { az, za }

enum DailyCheckViewStyle { sorted, grouped }

enum _DailyCheckFilter { all, saved, notSaved }

class _DailyCustomerGroupSection {
  const _DailyCustomerGroupSection({
    required this.key,
    required this.title,
    required this.customers,
    required this.isUngrouped,
  });

  final String key;
  final String title;
  final List<Customer> customers;
  final bool isUngrouped;
}

class _DailyGroupSectionHeader extends StatelessWidget {
  const _DailyGroupSectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.savedWalletCount,
    required this.pendingWalletCount,
    required this.isExpanded,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int savedWalletCount;
  final int pendingWalletCount;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DailySectionCountChip(
                        label: 'Saved',
                        count: savedWalletCount,
                        icon: Icons.check_circle_outline,
                        foregroundColor: colorScheme.primary,
                        backgroundColor:
                            colorScheme.primary.withValues(alpha: 0.09),
                      ),
                      _DailySectionCountChip(
                        label: 'Pending',
                        count: pendingWalletCount,
                        icon: Icons.schedule_outlined,
                        foregroundColor: colorScheme.onSurfaceVariant,
                        backgroundColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.65),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyWalletSummary {
  const _DailyWalletSummary({
    this.totalWalletCount = 0,
    this.savedWalletCount = 0,
    this.pendingWalletCount = 0,
  });

  final int totalWalletCount;
  final int savedWalletCount;
  final int pendingWalletCount;
}

class _DailySectionCountChip extends StatelessWidget {
  const _DailySectionCountChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            '$label $count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

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
