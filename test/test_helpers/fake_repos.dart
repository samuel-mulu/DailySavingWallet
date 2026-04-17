import 'package:mahtot/data/customers/customer_repo.dart';
import 'package:mahtot/data/wallet/models.dart';
import 'package:mahtot/data/wallet/recorded_daily_days_month.dart';
import 'package:mahtot/data/wallet/wallet_repo.dart';

class FakeCustomerRepo extends CustomerRepo {
  FakeCustomerRepo({Map<String, List<CustomerWallet>>? walletsByCustomerId})
    : walletsByCustomerId = Map<String, List<CustomerWallet>>.from(
        walletsByCustomerId ?? const {},
      );

  final Map<String, List<CustomerWallet>> walletsByCustomerId;
  int fetchCustomerWalletsCallCount = 0;
  bool throwOnFetchCustomerWallets = false;

  @override
  Future<List<CustomerWallet>> fetchCustomerWallets(String customerId) async {
    fetchCustomerWalletsCallCount += 1;
    if (throwOnFetchCustomerWallets) {
      throw StateError('customer wallets failed');
    }
    return walletsByCustomerId[customerId] ?? const <CustomerWallet>[];
  }
}

class FakeWalletRepo extends WalletRepo {
  FakeWalletRepo({
    Map<String, WalletSnapshot>? walletSnapshotsByWalletId,
    Map<String, String>? primaryWalletIdsByCustomerId,
    Map<String, List<LedgerTx>>? recentLedgerByWalletId,
    Map<String, LedgerPage>? ledgerPagesByKey,
    Map<String, RecordedDailyDaysMonth>? recordedDailyByMonthKey,
    Map<int, WithdrawPreview>? previewByAmountCents,
    Map<String, List<WithdrawRequest>>? withdrawRequestsByStatus,
  }) : walletSnapshotsByWalletId = Map<String, WalletSnapshot>.from(
         walletSnapshotsByWalletId ?? const {},
       ),
       primaryWalletIdsByCustomerId = Map<String, String>.from(
         primaryWalletIdsByCustomerId ?? const {},
       ),
       recentLedgerByWalletId = Map<String, List<LedgerTx>>.from(
         recentLedgerByWalletId ?? const {},
       ),
       ledgerPagesByKey = Map<String, LedgerPage>.from(
         ledgerPagesByKey ?? const {},
       ),
       recordedDailyByMonthKey = Map<String, RecordedDailyDaysMonth>.from(
         recordedDailyByMonthKey ?? const {},
       ),
       previewByAmountCents = Map<int, WithdrawPreview>.from(
         previewByAmountCents ?? const {},
       ),
       withdrawRequestsByStatus = Map<String, List<WithdrawRequest>>.from(
         withdrawRequestsByStatus ?? const {},
       );

  final Map<String, WalletSnapshot> walletSnapshotsByWalletId;
  final Map<String, String> primaryWalletIdsByCustomerId;
  final Map<String, List<LedgerTx>> recentLedgerByWalletId;
  final Map<String, LedgerPage> ledgerPagesByKey;
  final Map<String, RecordedDailyDaysMonth> recordedDailyByMonthKey;
  final Map<int, WithdrawPreview> previewByAmountCents;
  final Map<String, List<WithdrawRequest>> withdrawRequestsByStatus;

  int fetchWalletCallCount = 0;
  int fetchRecentLedgerCallCount = 0;
  int fetchLedgerPageCallCount = 0;
  int fetchRecordedDailyDaysByMonthCallCount = 0;
  int previewWithdrawCallCount = 0;
  int requestWithdrawCallCount = 0;
  int requestWithdrawForCustomerCallCount = 0;
  int fetchWithdrawRequestsCallCount = 0;
  int approveWithdrawCallCount = 0;
  int rejectWithdrawCallCount = 0;
  bool throwOnFetchLedgerPage = false;
  bool throwOnPreviewWithdraw = false;
  bool throwOnRequestWithdraw = false;
  bool throwOnFetchWithdrawRequests = false;
  bool throwOnApproveWithdraw = false;
  bool throwOnRejectWithdraw = false;
  Duration previewWithdrawDelay = Duration.zero;
  Duration requestWithdrawDelay = Duration.zero;
  String requestWithdrawForCustomerResult = 'request-1';

  @override
  Future<WalletSnapshot?> fetchWallet(
    String customerId, {
    String? walletId,
  }) async {
    fetchWalletCallCount += 1;
    final resolvedWalletId =
        walletId ?? primaryWalletIdsByCustomerId[customerId];
    if (resolvedWalletId != null) {
      final exact = walletSnapshotsByWalletId[resolvedWalletId];
      if (exact != null && exact.customerId == customerId) {
        return exact;
      }
    }

    for (final snapshot in walletSnapshotsByWalletId.values) {
      if (snapshot.customerId == customerId) {
        return snapshot;
      }
    }
    return null;
  }

  @override
  Future<List<LedgerTx>> fetchRecentLedger(
    String customerId, {
    int limit = 5,
    String? walletId,
  }) async {
    fetchRecentLedgerCallCount += 1;
    final resolvedWalletId =
        walletId ?? primaryWalletIdsByCustomerId[customerId];
    if (resolvedWalletId != null) {
      final exact = recentLedgerByWalletId[resolvedWalletId];
      if (exact != null) {
        return exact.take(limit).toList(growable: false);
      }
    }

    for (final entry in recentLedgerByWalletId.entries) {
      final snapshot = walletSnapshotsByWalletId[entry.key];
      if (snapshot != null && snapshot.customerId == customerId) {
        return entry.value.take(limit).toList(growable: false);
      }
    }
    return const <LedgerTx>[];
  }

  @override
  Future<LedgerPage> fetchLedgerPage(
    String customerId, {
    Object? startAfter,
    int limit = 20,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? types,
    String? walletId,
  }) async {
    fetchLedgerPageCallCount += 1;
    if (throwOnFetchLedgerPage) {
      throw StateError('ledger page failed');
    }
    final key = _ledgerPageKey(
      customerId: customerId,
      walletId: walletId,
      startAfter: startAfter is String ? startAfter : null,
      limit: limit,
      startDate: startDate,
      endDate: endDate,
      types: types,
    );
    return ledgerPagesByKey[key] ??
        const LedgerPage(items: <LedgerTx>[], lastDoc: null, hasMore: false);
  }

  @override
  Future<RecordedDailyDaysMonth> fetchRecordedDailyPaymentDaysByMonth({
    required String customerId,
    required String walletId,
    required String month,
  }) async {
    fetchRecordedDailyDaysByMonthCallCount += 1;
    return recordedDailyByMonthKey[_monthKey(customerId, walletId, month)] ??
        RecordedDailyDaysMonth(
          customerId: customerId,
          walletId: walletId,
          month: month,
          recordedTxDays: const <String>{},
        );
  }

  @override
  Future<WithdrawPreview> previewWithdraw({required int amountCents}) async {
    previewWithdrawCallCount += 1;
    if (previewWithdrawDelay > Duration.zero) {
      await Future<void>.delayed(previewWithdrawDelay);
    }
    if (throwOnPreviewWithdraw) {
      throw StateError('preview failed');
    }
    return previewByAmountCents[amountCents] ??
        WithdrawPreview.calculate(amountCents);
  }

  @override
  Future<void> requestWithdraw({
    required int amountCents,
    required String reason,
    String? idempotencyKey,
    String? logicalActionId,
  }) async {
    requestWithdrawCallCount += 1;
    if (requestWithdrawDelay > Duration.zero) {
      await Future<void>.delayed(requestWithdrawDelay);
    }
    if (throwOnRequestWithdraw) {
      throw StateError('request withdraw failed');
    }
  }

  @override
  Future<String> requestWithdrawForCustomer({
    required String customerId,
    String? walletId,
    required int amountCents,
    required String reason,
    String? idempotencyKey,
    String? logicalActionId,
  }) async {
    requestWithdrawForCustomerCallCount += 1;
    if (requestWithdrawDelay > Duration.zero) {
      await Future<void>.delayed(requestWithdrawDelay);
    }
    if (throwOnRequestWithdraw) {
      throw StateError('request withdraw failed');
    }
    return requestWithdrawForCustomerResult;
  }

  @override
  Future<List<WithdrawRequest>> fetchWithdrawRequests({
    String? customerId,
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    fetchWithdrawRequestsCallCount += 1;
    if (throwOnFetchWithdrawRequests) {
      throw StateError('fetch withdraw requests failed');
    }
    final key = (status ?? 'PENDING').toUpperCase();
    final items = withdrawRequestsByStatus[key] ?? const <WithdrawRequest>[];
    return items.take(limit).toList(growable: false);
  }

  @override
  Future<void> approveWithdraw(
    String requestId, {
    String? idempotencyKey,
    int? amountCents,
    String? logicalActionId,
  }) async {
    approveWithdrawCallCount += 1;
    if (throwOnApproveWithdraw) {
      throw StateError('approve withdraw failed');
    }
  }

  @override
  Future<void> rejectWithdraw(
    String requestId, {
    String? note,
    String? idempotencyKey,
    String? logicalActionId,
  }) async {
    rejectWithdrawCallCount += 1;
    if (throwOnRejectWithdraw) {
      throw StateError('reject withdraw failed');
    }
  }
}

CustomerWallet buildCustomerWallet({
  required String id,
  required String customerId,
  required String displayName,
  required bool isPrimary,
  String type = 'PRIMARY',
  String status = 'ACTIVE',
  int balanceCents = 0,
  int dailyTargetCents = 10000,
  int creditLimitCents = 0,
}) {
  return CustomerWallet(
    id: id,
    customerId: customerId,
    type: type,
    displayName: displayName,
    code: null,
    status: status,
    balanceCents: balanceCents,
    dailyTargetCents: dailyTargetCents,
    creditLimitCents: creditLimitCents,
    lastSavingAt: null,
    lastActivityAt: null,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    isPrimary: isPrimary,
  );
}

WalletSnapshot buildWalletSnapshot({
  required String id,
  required String customerId,
  required String displayName,
  String type = 'PRIMARY',
  String status = 'ACTIVE',
  int balanceCents = 0,
  int dailyTargetCents = 10000,
  int creditLimitCents = 0,
}) {
  return WalletSnapshot(
    id: id,
    customerId: customerId,
    balanceCents: balanceCents,
    dailyTargetCents: dailyTargetCents,
    creditLimitCents: creditLimitCents,
    status: status,
    type: type,
    displayName: displayName,
    code: null,
    lastSavingAt: null,
    lastActivityAt: null,
    updatedAt: DateTime(2025, 1, 1),
  );
}

LedgerTx buildLedgerTx({
  required String id,
  String type = 'DAILY_PAYMENT',
  String direction = 'IN',
  int amountCents = 10000,
  int? balanceAfterCents = 10000,
}) {
  return LedgerTx(
    id: id,
    type: type,
    direction: direction,
    amountCents: amountCents,
    balanceAfterCents: balanceAfterCents,
    txDate: DateTime.utc(2025, 1, 10),
    createdAt: DateTime.utc(2025, 1, 10),
    createdByUid: 'admin-1',
    meta: const <String, dynamic>{},
  );
}

WithdrawRequest buildWithdrawRequest({
  required String id,
  required String customerId,
  String? walletId,
  int amountCents = 3000,
  int feeCents = 100,
  int netPayoutCents = 2900,
  String reason = 'Need cash',
  String status = 'PENDING',
}) {
  return WithdrawRequest(
    id: id,
    customerId: customerId,
    walletId: walletId,
    amountCents: amountCents,
    feeCents: feeCents,
    netPayoutCents: netPayoutCents,
    approvalFeeCents: feeCents,
    approvedNetPayoutCents: netPayoutCents,
    reason: reason,
    status: status,
    requestedByUid: 'u-1',
    reviewedByUid: null,
    createdAt: DateTime.utc(2025, 1, 10),
    updatedAt: DateTime.utc(2025, 1, 10),
  );
}

RecordedDailyDaysMonth buildRecordedDailyDaysMonth({
  required String customerId,
  required String walletId,
  required String month,
  required Set<String> recordedTxDays,
}) {
  return RecordedDailyDaysMonth(
    customerId: customerId,
    walletId: walletId,
    month: month,
    recordedTxDays: recordedTxDays,
  );
}

String monthKeyFor(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

String _monthKey(String customerId, String walletId, String month) =>
    '$customerId|$walletId|$month';

String ledgerPageKeyFor({
  required String customerId,
  String? walletId,
  String? startAfter,
  int limit = 20,
  DateTime? startDate,
  DateTime? endDate,
  List<String>? types,
}) => _ledgerPageKey(
  customerId: customerId,
  walletId: walletId,
  startAfter: startAfter,
  limit: limit,
  startDate: startDate,
  endDate: endDate,
  types: types,
);

String _ledgerPageKey({
  required String customerId,
  String? walletId,
  String? startAfter,
  int limit = 20,
  DateTime? startDate,
  DateTime? endDate,
  List<String>? types,
}) {
  final typeToken = (types ?? const <String>[]).join(',');
  return [
    customerId,
    walletId ?? '',
    startAfter ?? '',
    '$limit',
    startDate?.toIso8601String() ?? '',
    endDate?.toIso8601String() ?? '',
    typeToken,
  ].join('|');
}
