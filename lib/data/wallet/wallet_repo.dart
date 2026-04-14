import '../../core/idempotency/idempotency_key_manager.dart';
import '../../core/logging/app_logger.dart';
import '../api/wallet_api.dart';
import '../api/withdrawal_api.dart';
import 'models.dart';
import 'recorded_daily_days_month.dart';

class WalletRepo {
  WalletRepo({
    WalletApi? walletApi,
    WithdrawalApi? withdrawalApi,
    IdempotencyKeyManager? idempotencyKeyManager,
  })
    : _walletApi = walletApi ?? WalletApi(),
      _withdrawalApi = withdrawalApi ?? WithdrawalApi(),
      _idempotencyKeyManager =
          idempotencyKeyManager ?? IdempotencyKeyManager();

  final WalletApi _walletApi;
  final WithdrawalApi _withdrawalApi;
  final IdempotencyKeyManager _idempotencyKeyManager;

  Future<WalletSnapshot?> fetchWallet(String customerId, {String? walletId}) {
    return _walletApi.fetchWallet(customerId, walletId: walletId);
  }

  Future<LedgerPage> fetchLedgerPage(
    String customerId, {
    Object? startAfter,
    int limit = 20,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? types,
    String? walletId,
  }) {
    final cursor = startAfter is String ? startAfter : null;
    return _walletApi.fetchLedgerPage(
      customerId,
      cursor: cursor,
      limit: limit,
      startDate: startDate,
      endDate: endDate,
      types: types,
      walletId: walletId,
    );
  }

  Future<List<LedgerTx>> fetchRecentLedger(
    String customerId, {
    int limit = 5,
    String? walletId,
  }) async {
    final page = await fetchLedgerPage(
      customerId,
      limit: limit,
      walletId: walletId,
    );
    return page.items;
  }

  Future<List<WithdrawRequest>> fetchPendingWithdrawRequests({int limit = 20}) {
    return _withdrawalApi.fetchPendingWithdrawals(limit: limit);
  }

  Future<List<WithdrawRequest>> fetchWithdrawRequests({
    String? customerId,
    String? status,
    int limit = 20,
    String? cursor,
  }) {
    return _withdrawalApi.listWithdrawals(
      customerId: customerId,
      status: status,
      limit: limit,
      cursor: cursor,
    );
  }

  Future<List<WithdrawRequest>> fetchCustomerWithdrawRequests(
    String customerId, {
    int limit = 3,
  }) {
    return _withdrawalApi.listWithdrawals(customerId: customerId, limit: limit);
  }

  Future<int> fetchPendingWithdrawCount({int limit = 20}) async {
    final items = await _withdrawalApi.fetchPendingWithdrawals(limit: limit);
    return items.length;
  }

  Future<WithdrawPreview> previewWithdraw({required int amountCents}) {
    return _withdrawalApi.previewWithdraw(amountCents: amountCents);
  }

  Future<Set<String>> fetchRecordedDailyPaymentCustomerIds(String txDay) {
    AppLogger.debug(
      '[WalletRepo] fetchRecordedDailyPaymentCustomerIds: txDay="$txDay"',
    );
    return _walletApi.fetchRecordedDailyPaymentCustomerIds(txDay);
  }

  Future<Set<String>> fetchRecordedDailyPaymentWalletIds(String txDay) {
    AppLogger.debug(
      '[WalletRepo] fetchRecordedDailyPaymentWalletIds: txDay="$txDay"',
    );
    return _walletApi.fetchRecordedDailyPaymentWalletIds(txDay);
  }

  Future<RecordedDailyDaysMonth> fetchRecordedDailyPaymentDaysByMonth({
    required String customerId,
    required String walletId,
    required String month,
  }) {
    return _walletApi.fetchRecordedDailyPaymentDaysByMonth(
      customerId: customerId,
      walletId: walletId,
      month: month,
    );
  }

  Future<DailyPendingSummary> fetchDailyPendingSummary(String txDay) {
    return _walletApi.fetchDailyPendingSummary(txDay);
  }

  Future<DailyWalletCounts> fetchDailyWalletCounts(String txDay) {
    return _walletApi.fetchDailyWalletCounts(txDay);
  }

  Future<void> requestWithdraw({
    required int amountCents,
    required String reason,
    String? idempotencyKey,
    String? logicalActionId,
  }) async {
    final actionId =
        logicalActionId ?? 'withdraw:self|$amountCents|${reason.trim()}';
    final key = idempotencyKey ?? _idempotencyKeyManager.keyFor(actionId);
    await _withdrawalApi.requestWithdraw(
      amountCents: amountCents,
      reason: reason,
      idempotencyKey: key,
    );
    if (idempotencyKey == null) {
      _idempotencyKeyManager.clear(actionId);
    }
  }

  Future<WalletSnapshot?> recordDailySaving({
    required String customerId,
    String? walletId,
    required int amountCents,
    required int txDateMillis,
    String? note,
    String? idempotencyKey,
    String? logicalActionId,
  }) async {
    final actionId = logicalActionId ??
        'dailySaving|$customerId|${walletId ?? 'PRIMARY'}|$amountCents|$txDateMillis|${note?.trim() ?? ''}';
    final key = idempotencyKey ?? _idempotencyKeyManager.keyFor(actionId);
    final txDate = DateTime.fromMillisecondsSinceEpoch(txDateMillis);
    final result = await _walletApi.recordDailySaving(
      customerId: customerId,
      walletId: walletId,
      amountCents: amountCents,
      txDate: txDate,
      note: note,
      idempotencyKey: key,
    );
    if (idempotencyKey == null) {
      _idempotencyKeyManager.clear(actionId);
    }
    return result;
  }

  Future<WalletSnapshot?> recordDeposit({
    required String customerId,
    String? walletId,
    required int amountCents,
    int? txDateMillis,
    String? note,
    String? idempotencyKey,
    String? logicalActionId,
  }) async {
    final actionId = logicalActionId ??
        'deposit|$customerId|${walletId ?? 'PRIMARY'}|$amountCents|${txDateMillis ?? ''}|${note?.trim() ?? ''}';
    final key = idempotencyKey ?? _idempotencyKeyManager.keyFor(actionId);
    final result = await _walletApi.recordDeposit(
      customerId: customerId,
      walletId: walletId,
      amountCents: amountCents,
      txDate: txDateMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(txDateMillis)
          : null,
      note: note,
      idempotencyKey: key,
    );
    if (idempotencyKey == null) {
      _idempotencyKeyManager.clear(actionId);
    }
    return result;
  }

  Future<WalletSnapshot?> updateWalletStatus({
    required String customerId,
    required String walletId,
    required String targetStatus,
    required String reason,
  }) {
    return _walletApi.updateWalletStatus(
      customerId: customerId,
      walletId: walletId,
      targetStatus: targetStatus,
      reason: reason,
    );
  }

  Future<({WalletStatusHealth health, List<WalletStatusEvent> events})>
  fetchWalletStatusHistory({
    required String customerId,
    required String walletId,
  }) {
    return _walletApi.fetchWalletStatusHistory(
      customerId: customerId,
      walletId: walletId,
    );
  }

  Future<String> requestWithdrawForCustomer({
    required String customerId,
    String? walletId,
    required int amountCents,
    required String reason,
    String? idempotencyKey,
    String? logicalActionId,
  }) async {
    final actionId = logicalActionId ??
        'withdraw:customer|$customerId|${walletId ?? 'PRIMARY'}|$amountCents|${reason.trim()}';
    final key = idempotencyKey ?? _idempotencyKeyManager.keyFor(actionId);
    final result = await _withdrawalApi.requestWithdraw(
      customerId: customerId,
      walletId: walletId,
      amountCents: amountCents,
      reason: reason,
      idempotencyKey: key,
    );
    if (idempotencyKey == null) {
      _idempotencyKeyManager.clear(actionId);
    }
    return result;
  }

  Future<void> approveWithdraw(
    String requestId, {
    String? idempotencyKey,
    int? amountCents,
    String? logicalActionId,
  }) async {
    final actionId =
        logicalActionId ?? 'withdraw:approve|$requestId|${amountCents ?? ''}';
    final key = idempotencyKey ?? _idempotencyKeyManager.keyFor(actionId);
    await _withdrawalApi.approveWithdraw(
      requestId: requestId,
      idempotencyKey: key,
      amountCents: amountCents,
    );
    if (idempotencyKey == null) {
      _idempotencyKeyManager.clear(actionId);
    }
  }

  Future<void> rejectWithdraw(
    String requestId, {
    String? note,
    String? idempotencyKey,
    String? logicalActionId,
  }) async {
    final actionId =
        logicalActionId ?? 'withdraw:reject|$requestId|${note?.trim() ?? ''}';
    final key = idempotencyKey ?? _idempotencyKeyManager.keyFor(actionId);
    await _withdrawalApi.rejectWithdraw(
      requestId: requestId,
      note: note,
      idempotencyKey: key,
    );
    if (idempotencyKey == null) {
      _idempotencyKeyManager.clear(actionId);
    }
  }

  Future<int> fetchTotalSaving() async {
    try {
      final totals = await _walletApi.fetchWalletTotals();
      return totals.totalSavingCents;
    } catch (e) {
      AppLogger.error('[WalletRepo] fetchTotalSaving failed', e);
      return 0;
    }
  }

  Future<int> fetchTotalCredit() async {
    try {
      final totals = await _walletApi.fetchWalletTotals();
      return totals.totalCreditCents;
    } catch (e) {
      AppLogger.error('[WalletRepo] fetchTotalCredit failed', e);
      return 0;
    }
  }

  Future<WalletTotals> fetchWalletTotals() {
    return _walletApi.fetchWalletTotals();
  }

  Future<Map<String, dynamic>> fetchDailySavingsReport(String txDay) {
    return _walletApi.fetchDailySavingsReport(txDay);
  }

  Future<Map<String, dynamic>> fetchMonthlySavingsReport(String month) {
    return _walletApi.fetchMonthlySavingsReport(month);
  }

  Future<Map<String, dynamic>> fetchCompanyWalletReport({int limit = 30}) {
    return _walletApi.fetchCompanyWalletReport(limit: limit);
  }

  Future<WalletStatusCounts> fetchWalletStatusCounts({String? search}) {
    return _walletApi.fetchWalletStatusCounts(search: search);
  }
}
