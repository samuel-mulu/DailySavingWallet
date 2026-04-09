import 'package:uuid/uuid.dart';

import '../../core/logging/app_logger.dart';
import '../api/wallet_api.dart';
import '../api/withdrawal_api.dart';
import 'models.dart';

class WalletRepo {
  WalletRepo({WalletApi? walletApi, WithdrawalApi? withdrawalApi, Uuid? uuid})
    : _walletApi = walletApi ?? WalletApi(),
      _withdrawalApi = withdrawalApi ?? WithdrawalApi(),
      _uuid = uuid ?? const Uuid();

  final WalletApi _walletApi;
  final WithdrawalApi _withdrawalApi;
  final Uuid _uuid;

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

  Future<DailyPendingSummary> fetchDailyPendingSummary(String txDay) {
    return _walletApi.fetchDailyPendingSummary(txDay);
  }

  Future<void> requestWithdraw({
    required int amountCents,
    required String reason,
  }) async {
    await _withdrawalApi.requestWithdraw(
      amountCents: amountCents,
      reason: reason,
      idempotencyKey: _uuid.v4(),
    );
  }

  Future<WalletSnapshot?> recordDailySaving({
    required String customerId,
    String? walletId,
    required int amountCents,
    required int txDateMillis,
    String? note,
    String? idempotencyKey,
  }) async {
    final txDate = DateTime.fromMillisecondsSinceEpoch(txDateMillis);
    return _walletApi.recordDailySaving(
      customerId: customerId,
      walletId: walletId,
      amountCents: amountCents,
      txDate: txDate,
      note: note,
      idempotencyKey: idempotencyKey ?? _uuid.v4(),
    );
  }

  Future<WalletSnapshot?> recordDeposit({
    required String customerId,
    String? walletId,
    required int amountCents,
    int? txDateMillis,
    String? note,
    String? idempotencyKey,
  }) async {
    return _walletApi.recordDeposit(
      customerId: customerId,
      walletId: walletId,
      amountCents: amountCents,
      txDate: txDateMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(txDateMillis)
          : null,
      note: note,
      idempotencyKey: idempotencyKey ?? _uuid.v4(),
    );
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
  }) async {
    return _withdrawalApi.requestWithdraw(
      customerId: customerId,
      walletId: walletId,
      amountCents: amountCents,
      reason: reason,
      idempotencyKey: _uuid.v4(),
    );
  }

  Future<void> approveWithdraw(
    String requestId, {
    String? idempotencyKey,
    int approvalFeeCents = 0,
  }) async {
    await _withdrawalApi.approveWithdraw(
      requestId: requestId,
      idempotencyKey: idempotencyKey ?? _uuid.v4(),
      approvalFeeCents: approvalFeeCents,
    );
  }

  Future<void> rejectWithdraw(String requestId, {String? note}) async {
    await _withdrawalApi.rejectWithdraw(
      requestId: requestId,
      note: note,
      idempotencyKey: _uuid.v4(),
    );
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
}
