import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/paged_list_state.dart';
import '../../core/money/money.dart';
import '../../core/ui/empty_state.dart';
import '../../core/ui/filter_count_chip.dart';
import '../../data/api/api_client.dart';
import '../../data/customers/customer_model.dart';
import '../../data/wallet/models.dart';
import '../data/repository_providers.dart';
import '../wallet/wallet_providers.dart';
import 'customers/customer_detail_screen.dart';
import 'customers/widgets/customer_profile_avatar.dart';

class WithdrawApprovalsScreen extends ConsumerStatefulWidget {
  const WithdrawApprovalsScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  ConsumerState<WithdrawApprovalsScreen> createState() =>
      _WithdrawApprovalsScreenState();
}

enum _ApprovalQueue { pending, approved, rejected }

class _WithdrawApprovalsScreenState
    extends ConsumerState<WithdrawApprovalsScreen> {
  _ApprovalQueue _queue = _ApprovalQueue.pending;

  Future<void> _refreshAll() async {
    await Future.wait([
      ref
          .read(withdrawRequestListProvider(pendingWithdrawListQuery).notifier)
          .refresh(force: true),
      ref
          .read(withdrawRequestListProvider(approvedWithdrawListQuery).notifier)
          .refresh(force: true),
      ref
          .read(withdrawRequestListProvider(rejectedWithdrawListQuery).notifier)
          .refresh(force: true),
    ]);
    ref.read(withdrawReviewMutationProvider.notifier).clear();
  }

  Future<int?> _confirmApprove(WithdrawRequest request) async {
    final customer = await ref.read(
      customerByIdProvider(request.customerId).future,
    );
    WalletSnapshot? wallet;
    final walletId = request.walletId;
    if (walletId != null && walletId.isNotEmpty) {
      wallet = await ref.read(
        requestWalletLookupProvider((
          customerId: request.customerId,
          walletId: walletId,
        )).future,
      );
    }
    if (!mounted) return null;

    return showDialog<int>(
      context: context,
      builder: (context) => _ApproveWithdrawDialog(
        request: request,
        customer: customer,
        wallet: wallet,
      ),
    );
  }

  Future<String?> _askRejectNote() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject request'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<bool> _confirmReject(WithdrawRequest request, String? note) async {
    final customer = await ref.read(
      customerByIdProvider(request.customerId).future,
    );
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm reject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${customer?.fullName ?? request.customerId}'),
            const SizedBox(height: 8),
            Text('Amount: ${MoneyEtb.formatCents(request.amountCents)}'),
            const SizedBox(height: 8),
            Text('Reason: ${request.reason}'),
            if (note != null && note.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Note: ${note.trim()}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _approveRequest(
    WithdrawRequest request, {
    VoidCallback? onCompleted,
  }) async {
    final approvedAmountCents = await _confirmApprove(request);
    if (!mounted || approvedAmountCents == null) return;
    try {
      await ref.read(withdrawReviewMutationProvider.notifier).submit((
        requestId: request.id,
        approve: true,
        amountCents: approvedAmountCents,
        note: null,
      ));
      final actionState = ref.read(withdrawReviewMutationProvider);
      if (actionState.error != null) {
        _snack(describeBackendError(actionState.error!));
        return;
      }
      _snack('Approved.');
      onCompleted?.call();
    } catch (e) {
      _snack(describeBackendError(e));
    }
  }

  Future<void> _rejectRequest(
    WithdrawRequest request, {
    VoidCallback? onCompleted,
  }) async {
    final note = await _askRejectNote();
    if (!mounted || note == null) return;
    final ok = await _confirmReject(request, note);
    if (!mounted || !ok) return;
    try {
      await ref.read(withdrawReviewMutationProvider.notifier).submit((
        requestId: request.id,
        approve: false,
        amountCents: null,
        note: note,
      ));
      final actionState = ref.read(withdrawReviewMutationProvider);
      if (actionState.error != null) {
        _snack(describeBackendError(actionState.error!));
        return;
      }
      _snack('Rejected.');
      onCompleted?.call();
    } catch (e) {
      _snack(describeBackendError(e));
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  Color _statusColor(String status, ThemeData theme) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return const Color(0xFF10B981);
      case 'REJECTED':
        return theme.colorScheme.error;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _formatDate(BuildContext context, DateTime? value) {
    if (value == null) return 'Not available';
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(value)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  Future<void> _showRequestModal(WithdrawRequest request) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.88,
          child: Consumer(
            builder: (context, ref, _) {
              final customerAsync = ref.watch(
                customerByIdProvider(request.customerId),
              );
              final walletId = request.walletId;
              final walletAsync = walletId == null || walletId.isEmpty
                  ? const AsyncValue<WalletSnapshot?>.data(null)
                  : ref.watch(
                      requestWalletLookupProvider((
                        customerId: request.customerId,
                        walletId: walletId,
                      )),
                    );
              final customer = customerAsync.valueOrNull;
              final wallet = walletAsync.valueOrNull;
              final actionState = ref.watch(withdrawReviewMutationProvider);
              final isBusy =
                  actionState.isLoading && actionState.data == request.id;
              final statusColor = _statusColor(
                request.status,
                Theme.of(context),
              );

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (customer != null)
                            CustomerProfileAvatar(
                              customer: customer,
                              radius: 28,
                              enablePreview: true,
                            )
                          else
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: statusColor.withValues(
                                alpha: 0.12,
                              ),
                              child: Icon(
                                Icons.person_outline,
                                color: statusColor,
                              ),
                            ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer?.fullName ?? request.customerId,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  customer == null
                                      ? 'Customer details unavailable'
                                      : '${customer.companyName} - ${customer.phone}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          _StatusChip(
                            label: _statusLabel(request.status),
                            color: statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              label: 'Requested debit',
                              value: MoneyEtb.formatCents(request.amountCents),
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              label: 'Fee deducted',
                              value: MoneyEtb.formatCents(request.feeCents),
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              label: 'Net payout',
                              value: MoneyEtb.formatCents(
                                request.netPayoutCents,
                              ),
                              color: const Color(0xFF0EA5E9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SheetSection(
                        title: 'Request Note',
                        child: Text(request.reason),
                      ),
                      const SizedBox(height: 12),
                      _SheetSection(
                        title: 'Request Details',
                        child: Column(
                          children: [
                            _DetailRow(
                              label: 'Requested on',
                              value: _formatDate(context, request.createdAt),
                            ),
                            _DetailRow(
                              label: 'Updated on',
                              value: _formatDate(context, request.updatedAt),
                            ),
                            _DetailRow(
                              label: 'Wallet',
                              value:
                                  wallet?.label ?? 'Primary / default wallet',
                            ),
                            if (wallet != null)
                              _DetailRow(
                                label: 'Wallet balance',
                                value: MoneyEtb.formatCents(
                                  wallet.balanceCents,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (customer != null) ...[
                        const SizedBox(height: 12),
                        _SheetSection(
                          title: 'Customer Snapshot',
                          child: Column(
                            children: [
                              _DetailRow(
                                label: 'Balance',
                                value: MoneyEtb.formatCents(
                                  customer.balanceCents,
                                ),
                              ),
                              _DetailRow(
                                label: 'Daily target',
                                value: MoneyEtb.formatCents(
                                  customer.dailyTargetCents,
                                ),
                              ),
                              _DetailRow(
                                label: 'Credit limit',
                                value: MoneyEtb.formatCents(
                                  customer.creditLimitCents,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (_queue == _ApprovalQueue.pending) ...[
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: isBusy
                                    ? null
                                    : () => _approveRequest(
                                        request,
                                        onCompleted: () =>
                                            Navigator.of(sheetContext).pop(),
                                      ),
                                icon: const Icon(Icons.check),
                                label: const Text('Approve'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isBusy
                                    ? null
                                    : () => _rejectRequest(
                                        request,
                                        onCompleted: () =>
                                            Navigator.of(sheetContext).pop(),
                                      ),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: customer == null
                              ? null
                              : () {
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
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingState = ref.watch(
      withdrawRequestListProvider(pendingWithdrawListQuery),
    );
    final approvedState = ref.watch(
      withdrawRequestListProvider(approvedWithdrawListQuery),
    );
    final rejectedState = ref.watch(
      withdrawRequestListProvider(rejectedWithdrawListQuery),
    );
    final pendingItems = pendingState.items;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Withdraw Approvals'))
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterCountChip(
                    label: 'Pending',
                    count: pendingItems.length,
                    selected: _queue == _ApprovalQueue.pending,
                    icon: Icons.pending_actions_outlined,
                    onTap: () =>
                        setState(() => _queue = _ApprovalQueue.pending),
                  ),
                  const SizedBox(width: 8),
                  FilterCountChip(
                    label: 'Approved',
                    count: approvedState.items.length,
                    selected: _queue == _ApprovalQueue.approved,
                    icon: Icons.check_circle_outline,
                    onTap: () =>
                        setState(() => _queue = _ApprovalQueue.approved),
                  ),
                  const SizedBox(width: 8),
                  FilterCountChip(
                    label: 'Rejected',
                    count: rejectedState.items.length,
                    selected: _queue == _ApprovalQueue.rejected,
                    icon: Icons.cancel_outlined,
                    onTap: () =>
                        setState(() => _queue = _ApprovalQueue.rejected),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: switch (_queue) {
              _ApprovalQueue.pending => _buildPendingView(pendingState),
              _ApprovalQueue.approved => _buildReviewedView(
                state: approvedState,
                emptyTitle: 'No approved requests yet',
                emptyMessage:
                    'Approved withdrawals will appear here after review.',
              ),
              _ApprovalQueue.rejected => _buildReviewedView(
                state: rejectedState,
                emptyTitle: 'No rejected requests yet',
                emptyMessage:
                    'Rejected withdrawals will appear here after review.',
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPendingView(PagedListState<WithdrawRequest> state) {
    final items = state.items;
    if (state.isRefreshing && items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (state.error != null && items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(state.error.toString())),
        ],
      );
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyState(
              icon: Icons.task_alt_outlined,
              title: 'No pending requests',
              message: 'New withdrawal requests will appear here for approval.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (state.isRefreshing)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          _QueueSummaryCard(
            title: 'Pending approvals',
            subtitle:
                '${items.length} request${items.length == 1 ? '' : 's'} waiting for review',
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 12),
          ..._buildRequestCards(items, showActions: true),
        ],
      ),
    );
  }

  Widget _buildReviewedView({
    required PagedListState<WithdrawRequest> state,
    required String emptyTitle,
    required String emptyMessage,
  }) {
    final items = state.items;
    if (state.isRefreshing && items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (state.error != null && items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text('${state.error}')),
        ],
      );
    }
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            EmptyState(
              icon: _queue == _ApprovalQueue.approved
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
              title: emptyTitle,
              message: emptyMessage,
            ),
          ],
        ),
      );
    }
    final summaryColor = _queue == _ApprovalQueue.approved
        ? const Color(0xFF10B981)
        : Theme.of(context).colorScheme.error;
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (state.isRefreshing)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          _QueueSummaryCard(
            title: _queue == _ApprovalQueue.approved
                ? 'Approved withdrawals'
                : 'Rejected withdrawals',
            subtitle:
                '${items.length} request${items.length == 1 ? '' : 's'} in this queue',
            color: summaryColor,
          ),
          const SizedBox(height: 12),
          ..._buildRequestCards(items, showActions: false),
        ],
      ),
    );
  }

  List<Widget> _buildRequestCards(
    List<WithdrawRequest> items, {
    required bool showActions,
  }) {
    final actionState = ref.watch(withdrawReviewMutationProvider);
    return [
      for (var index = 0; index < items.length; index++) ...[
        _RequestCard(
          request: items[index],
          busy: actionState.isLoading && actionState.data == items[index].id,
          statusColor: _statusColor(items[index].status, Theme.of(context)),
          statusLabel: _statusLabel(items[index].status),
          showActions: showActions,
          onTap: () => _showRequestModal(items[index]),
          onApprove: showActions ? () => _approveRequest(items[index]) : null,
          onReject: showActions ? () => _rejectRequest(items[index]) : null,
        ),
        if (index != items.length - 1) const SizedBox(height: 12),
      ],
    ];
  }
}

class _ApproveWithdrawDialog extends ConsumerStatefulWidget {
  const _ApproveWithdrawDialog({
    required this.request,
    required this.customer,
    required this.wallet,
  });

  final WithdrawRequest request;
  final Customer? customer;
  final WalletSnapshot? wallet;

  @override
  ConsumerState<_ApproveWithdrawDialog> createState() =>
      _ApproveWithdrawDialogState();
}

class _ApproveWithdrawDialogState
    extends ConsumerState<_ApproveWithdrawDialog> {
  late final TextEditingController _amountCtrl;
  Timer? _previewDebounce;
  late WithdrawPreview _preview;
  bool _previewBusy = false;

  @override
  void initState() {
    super.initState();
    _preview = widget.request.preview;
    _amountCtrl = TextEditingController(
      text: _formatEditableEtb(widget.request.amountCents),
    );
    _amountCtrl.addListener(_handleAmountChanged);
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _amountCtrl.dispose();
    super.dispose();
  }

  int? _tryParseAmountCents() {
    final text = _amountCtrl.text.trim();
    if (text.isEmpty) return null;
    try {
      return MoneyEtb.parseEtbToCents(text);
    } on FormatException {
      return null;
    }
  }

  void _handleAmountChanged() {
    _previewDebounce?.cancel();

    final amountCents = _tryParseAmountCents();
    if (amountCents == null) {
      setState(() => _previewBusy = false);
      return;
    }

    setState(() {
      _preview = WithdrawPreview.calculate(amountCents);
      _previewBusy = true;
    });

    _previewDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _syncPreview(amountCents),
    );
  }

  Future<void> _syncPreview(int amountCents) async {
    try {
      final preview = await ref
          .read(walletRepoProvider)
          .previewWithdraw(amountCents: amountCents);
      if (!mounted || _tryParseAmountCents() != amountCents) return;
      setState(() {
        _preview = preview;
        _previewBusy = false;
      });
    } catch (_) {
      if (!mounted || _tryParseAmountCents() != amountCents) return;
      setState(() => _previewBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final wallet = widget.wallet;
    final amountCents = _tryParseAmountCents();
    final amountIsValid = amountCents != null;
    final currentBalance = wallet?.balanceCents ?? 0;
    final approvedDebitCents = amountIsValid
        ? _preview.requestedAmountCents
        : 0;
    final afterBalance = currentBalance - approvedDebitCents;
    final limitCents = wallet?.creditLimitCents ?? 0;
    final debtCents = afterBalance < 0 ? -afterBalance : 0;
    final exceedsLimit =
        amountIsValid && limitCents > 0 && debtCents > limitCents;

    return AlertDialog(
      title: const Text('Approve Withdraw'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer != null) ...[
              Text(
                customer.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(customer.companyName),
              const Divider(height: 20),
            ],
            Text(
              'Requested: ${MoneyEtb.formatCents(widget.request.amountCents)}',
            ),
            if (wallet != null) ...[
              const SizedBox(height: 6),
              Text('Wallet: ${wallet.label}'),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Approve amount (ETB)',
                helperText:
                    'Fee uses the exact 1/30 rule and is deducted from approved amount.',
                border: OutlineInputBorder(),
              ),
            ),
            if (!amountIsValid) ...[
              const SizedBox(height: 8),
              Text(
                'Enter a valid amount',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Approval summary',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DialogPreviewRow(
                    label: 'Approved debit',
                    value: amountIsValid
                        ? MoneyEtb.formatCents(_preview.requestedAmountCents)
                        : 'Enter amount',
                  ),
                  const SizedBox(height: 8),
                  _DialogPreviewRow(
                    label: 'Fee',
                    value: amountIsValid
                        ? MoneyEtb.formatCents(_preview.feeCents)
                        : 'Enter amount',
                  ),
                  const SizedBox(height: 8),
                  _DialogPreviewRow(
                    label: 'Net payout',
                    value: amountIsValid
                        ? MoneyEtb.formatCents(_preview.netPayoutCents)
                        : 'Enter amount',
                    emphasize: true,
                  ),
                  const SizedBox(height: 8),
                  _DialogPreviewRow(
                    label: 'After balance',
                    value: amountIsValid
                        ? MoneyEtb.formatCents(afterBalance)
                        : 'Enter amount',
                  ),
                  if (_previewBusy) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                ],
              ),
            ),
            if (amountIsValid && afterBalance < 0) ...[
              const SizedBox(height: 10),
              Text(
                limitCents > 0
                    ? exceedsLimit
                          ? 'Exceeds limit by ${MoneyEtb.formatCents(debtCents - limitCents)}'
                          : 'Within credit limit'
                    : 'Uses open credit balance',
                style: TextStyle(
                  color: exceedsLimit ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: !amountIsValid || exceedsLimit
              ? null
              : () => Navigator.pop(context, amountCents),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({
    required this.request,
    required this.busy,
    required this.statusColor,
    required this.statusLabel,
    required this.showActions,
    required this.onTap,
    this.onApprove,
    this.onReject,
  });

  final WithdrawRequest request;
  final bool busy;
  final Color statusColor;
  final String statusLabel;
  final bool showActions;
  final VoidCallback onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final customerAsync = ref.watch(customerByIdProvider(request.customerId));
    final customer = customerAsync.valueOrNull;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: statusColor.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (customer != null)
                      CustomerProfileAvatar(
                        customer: customer,
                        radius: 22,
                        enablePreview: true,
                      )
                    else
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: statusColor.withValues(alpha: 0.12),
                        child: Icon(Icons.person_outline, color: statusColor),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer?.fullName ?? 'Loading customer...',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer == null
                                ? request.customerId
                                : '${customer.companyName} - ${customer.phone}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(label: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        request.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          MoneyEtb.formatCents(request.amountCents),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                        ),
                        if (busy)
                          const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Text(
                            request.walletId == null
                                ? 'Primary wallet'
                                : 'Wallet request',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      label: 'Fee ${MoneyEtb.formatCents(request.feeCents)}',
                    ),
                    _InfoPill(
                      label:
                          'Net ${MoneyEtb.formatCents(request.netPayoutCents)}',
                    ),
                  ],
                ),
                if (showActions) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy ? null : onApprove,
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : onReject,
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogPreviewRow extends StatelessWidget {
  const _DialogPreviewRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

String _formatEditableEtb(int cents) {
  final whole = cents ~/ 100;
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return '$whole.$fraction';
}

class _QueueSummaryCard extends StatelessWidget {
  const _QueueSummaryCard({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.layers_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
