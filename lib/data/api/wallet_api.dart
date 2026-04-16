import '../customers/customer_model.dart';
import '../wallet/models.dart';
import '../wallet/recorded_daily_days_month.dart';
import 'api_client.dart';

class WalletTotals {
  final int totalSavingCents;
  final int totalCreditCents;
  final int companyWalletBalanceCents;
  final int companyFeeRevenueCents;
  /// All non-company (customer) wallets.
  final int totalCustomerWalletCount;
  /// Wallets with balance &gt; 0 (matches [totalSavingCents] aggregate).
  final int walletsWithPositiveBalanceCount;
  /// Wallets with balance &lt; 0 (matches [totalCreditCents] aggregate).
  final int walletsWithNegativeBalanceCount;

  const WalletTotals({
    required this.totalSavingCents,
    required this.totalCreditCents,
    required this.companyWalletBalanceCents,
    required this.companyFeeRevenueCents,
    this.totalCustomerWalletCount = 0,
    this.walletsWithPositiveBalanceCount = 0,
    this.walletsWithNegativeBalanceCount = 0,
  });
}

class DailyPendingSummary {
  final int pendingCustomerCount;
  final int pendingWalletCount;

  const DailyPendingSummary({
    required this.pendingCustomerCount,
    required this.pendingWalletCount,
  });
}

class DailyWalletCounts {
  final int activeWalletCount;
  final int savedWalletCount;
  final int pendingWalletCount;

  const DailyWalletCounts({
    required this.activeWalletCount,
    required this.savedWalletCount,
    required this.pendingWalletCount,
  });
}

class DailyCheckSummary {
  final int customerCount;
  final int savedCustomerCount;
  final int notSavedCustomerCount;
  final int activeWalletCount;
  final int savedWalletCount;
  final int pendingWalletCount;

  const DailyCheckSummary({
    required this.customerCount,
    required this.savedCustomerCount,
    required this.notSavedCustomerCount,
    required this.activeWalletCount,
    required this.savedWalletCount,
    required this.pendingWalletCount,
  });

  static DailyCheckSummary fromBackendMap(Map<String, dynamic> json) {
    return DailyCheckSummary(
      customerCount: _toInt(json['customerCount']),
      savedCustomerCount: _toInt(json['savedCustomerCount']),
      notSavedCustomerCount: _toInt(json['notSavedCustomerCount']),
      activeWalletCount: _toInt(json['activeWalletCount']),
      savedWalletCount: _toInt(json['savedWalletCount']),
      pendingWalletCount: _toInt(json['pendingWalletCount']),
    );
  }
}

class DailyCheckRow {
  final Customer customer;
  final List<CustomerWallet> wallets;
  final int totalWalletCount;
  final int savedWalletCount;
  final int pendingWalletCount;
  final bool hasSaved;
  final bool hasPending;
  final Set<String> savedWalletIds;

  const DailyCheckRow({
    required this.customer,
    required this.wallets,
    required this.totalWalletCount,
    required this.savedWalletCount,
    required this.pendingWalletCount,
    required this.hasSaved,
    required this.hasPending,
    required this.savedWalletIds,
  });

  static DailyCheckRow fromBackendMap(Map<String, dynamic> json) {
    final customer = Customer.fromBackendMap(
      asJsonMap(json['customer'], fieldName: 'customer'),
    );
    final wallets = asJsonList(json['wallets'], fieldName: 'wallets')
        .map((item) => CustomerWallet.fromBackendMap(asJsonMap(item)))
        .toList(growable: false);
    final summary = asJsonMap(json['summary'], fieldName: 'summary');
    final savedWalletIds = asJsonList(json['wallets'], fieldName: 'wallets')
        .map((item) => asJsonMap(item))
        .where((wallet) => wallet['isSavedForTxDay'] == true)
        .map((wallet) => (wallet['walletId'] as String?) ?? '')
        .where((walletId) => walletId.isNotEmpty)
        .toSet();

    return DailyCheckRow(
      customer: customer,
      wallets: wallets,
      totalWalletCount: _toInt(summary['totalWalletCount']),
      savedWalletCount: _toInt(summary['savedWalletCount']),
      pendingWalletCount: _toInt(summary['pendingWalletCount']),
      hasSaved: summary['hasSaved'] == true,
      hasPending: summary['hasPending'] == true,
      savedWalletIds: savedWalletIds,
    );
  }
}

class DailyCheckPage {
  final String txDay;
  final DailyCheckSummary summary;
  final List<DailyCheckRow> rows;
  final String? nextCursor;
  final bool hasMore;

  const DailyCheckPage({
    required this.txDay,
    required this.summary,
    required this.rows,
    required this.nextCursor,
    required this.hasMore,
  });
}

class WalletStatusPolicy {
  final int autoFreezeAfterDays;
  const WalletStatusPolicy({required this.autoFreezeAfterDays});
}

class WalletApi {
  final ApiClient _client;

  WalletApi({ApiClient? client}) : _client = client ?? ApiClient();

  Future<WalletStatusPolicy> fetchWalletStatusPolicy() async {
    final data = await _client.getJson('/wallet/status-policy');
    return WalletStatusPolicy(
      autoFreezeAfterDays: _toInt(data['autoFreezeAfterDays']),
    );
  }

  Future<WalletStatusPolicy> updateWalletStatusPolicy({
    required int autoFreezeAfterDays,
  }) async {
    final data = await _client.patchJson(
      '/wallet/status-policy',
      body: {'autoFreezeAfterDays': autoFreezeAfterDays},
    );
    return WalletStatusPolicy(
      autoFreezeAfterDays: _toInt(data['autoFreezeAfterDays']),
    );
  }

  Future<WalletSnapshot?> fetchWallet(
    String customerId, {
    String? walletId,
  }) async {
    try {
      final data = await _client.getJson(
        '/wallet/$customerId',
        queryParameters: {
          if (walletId != null && walletId.isNotEmpty) 'walletId': walletId,
        },
      );
      return WalletSnapshot.fromBackendMap(data);
    } on BackendApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<LedgerPage> fetchLedgerPage(
    String customerId, {
    String? cursor,
    int limit = 20,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? types,
    String? walletId,
  }) async {
    final queryParameters = <String, String>{
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (startDate != null) 'startDate': startDate.toUtc().toIso8601String(),
      if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
      if (walletId != null && walletId.isNotEmpty) 'walletId': walletId,
    };

    final data = await _client.getJson(
      '/wallet/$customerId/ledger',
      queryParameters: queryParameters,
      queryParametersAll: {
        if (types != null && types.isNotEmpty) 'types': types,
      },
    );

    final items = asJsonList(data['items'], fieldName: 'items')
        .map((item) => LedgerTx.fromBackendMap(asJsonMap(item)))
        .toList(growable: false);

    final nextCursor = data['nextCursor'] as String?;
    return LedgerPage(
      items: items,
      lastDoc: nextCursor,
      hasMore: nextCursor != null && nextCursor.isNotEmpty,
    );
  }

  Future<WalletTotals> fetchWalletTotals() async {
    final data = await _client.getJson('/wallet/stats/totals');
    return WalletTotals(
      totalSavingCents: _toInt(data['totalSavingCents']),
      totalCreditCents: _toInt(data['totalCreditCents']),
      companyWalletBalanceCents: _toInt(data['companyWalletBalanceCents']),
      companyFeeRevenueCents: _toInt(data['companyFeeRevenueCents']),
      totalCustomerWalletCount: _toInt(data['totalCustomerWalletCount']),
      walletsWithPositiveBalanceCount: _toInt(
        data['walletsWithPositiveBalanceCount'],
      ),
      walletsWithNegativeBalanceCount: _toInt(
        data['walletsWithNegativeBalanceCount'],
      ),
    );
  }

  Future<Map<String, dynamic>> fetchDailySavingsReport(String txDay) {
    return _client.getJson(
      '/wallet/stats/reports/daily',
      queryParameters: {'txDay': txDay},
    );
  }

  Future<Map<String, dynamic>> fetchDailySavingsActivityReport(String activityDay) {
    return _client.getJson(
      '/wallet/stats/reports/daily-activity',
      queryParameters: {'activityDay': activityDay},
    );
  }

  Future<DailyWalletCounts> fetchDailyWalletCounts(String txDay) async {
    final data = await _client.getJson(
      '/wallet/stats/reports/daily',
      queryParameters: {'txDay': txDay},
    );
    return DailyWalletCounts(
      activeWalletCount: _toInt(data['activeWallets']),
      savedWalletCount: _toInt(data['savedWalletCount']),
      pendingWalletCount: _toInt(data['pendingWalletCount']),
    );
  }

  Future<Map<String, dynamic>> fetchMonthlySavingsReport(String month) {
    return _client.getJson(
      '/wallet/stats/reports/monthly',
      queryParameters: {'month': month},
    );
  }

  Future<Map<String, dynamic>> fetchCompanyWalletReport({int limit = 30}) {
    return _client.getJson(
      '/wallet/stats/reports/company-wallet',
      queryParameters: {'limit': '$limit'},
    );
  }

  Future<WalletStatusCounts> fetchWalletStatusCounts({String? search}) async {
    final data = await _client.getJson(
      '/wallet/status-counts',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return WalletStatusCounts.fromBackendMap(
      asJsonMap(data['counts'], fieldName: 'counts'),
    );
  }

  Future<Set<String>> fetchRecordedDailyPaymentCustomerIds(String txDay) async {
    final data = await _client.getJson(
      '/wallet/daily-payments/recorded-customers',
      queryParameters: {'txDay': txDay},
    );
    final raw = asJsonList(data['customerIds'], fieldName: 'customerIds');
    return raw.map((e) => '$e').toSet();
  }

  Future<Set<String>> fetchRecordedDailyPaymentWalletIds(String txDay) async {
    final data = await _client.getJson(
      '/wallet/daily-payments/recorded-wallets',
      queryParameters: {'txDay': txDay},
    );
    final raw = asJsonList(data['walletIds'], fieldName: 'walletIds');
    return raw.map((e) => '$e').toSet();
  }

  Future<Map<String, List<CustomerWallet>>> fetchWalletsForCustomers(
    List<String> customerIds,
  ) async {
    if (customerIds.isEmpty) {
      return const <String, List<CustomerWallet>>{};
    }
    final data = await _client.postJson(
      '/wallet/bulk/customer-wallets',
      body: {'customerIds': customerIds},
    );
    final items = asJsonList(data['items'], fieldName: 'items');
    final out = <String, List<CustomerWallet>>{};
    for (final item in items) {
      final row = asJsonMap(item, fieldName: 'item');
      final customerId = (row['customerId'] as String?) ?? '';
      if (customerId.isEmpty) {
        continue;
      }
      final walletsRaw = asJsonList(row['wallets'], fieldName: 'wallets');
      out[customerId] = walletsRaw
          .map((wallet) => CustomerWallet.fromBackendMap(asJsonMap(wallet)))
          .toList(growable: false);
    }
    return out;
  }

  Future<DailyCheckPage> fetchDailyCheckPage({
    required String txDay,
    String? search,
    String? groupId,
    String filter = 'all',
    int limit = 50,
    String? cursor,
  }) async {
    final data = await _client.getJson(
      '/wallet/daily-check',
      queryParameters: {
        'txDay': txDay,
        'filter': filter,
        'limit': '$limit',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (groupId != null && groupId.trim().isNotEmpty) 'groupId': groupId.trim(),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );

    final summary = DailyCheckSummary.fromBackendMap(
      asJsonMap(data['summary'], fieldName: 'summary'),
    );
    final rows = asJsonList(data['rows'], fieldName: 'rows')
        .map((item) => DailyCheckRow.fromBackendMap(asJsonMap(item)))
        .toList(growable: false);
    final pageInfo = asJsonMap(data['pageInfo'], fieldName: 'pageInfo');
    final next = pageInfo['nextCursor'];
    final nextCursor = next is String && next.isNotEmpty ? next : null;
    final hasMore = pageInfo['hasMore'] == true;

    return DailyCheckPage(
      txDay: (data['txDay'] as String?) ?? txDay,
      summary: summary,
      rows: rows,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  Future<RecordedDailyDaysMonth> fetchRecordedDailyPaymentDaysByMonth({
    required String customerId,
    required String walletId,
    required String month,
  }) async {
    final data = await _client.getJson(
      '/wallet/$customerId/daily-payments/recorded-days',
      queryParameters: {'walletId': walletId, 'month': month},
    );
    return RecordedDailyDaysMonth.fromBackendMap(data);
  }

  Future<DailyPendingSummary> fetchDailyPendingSummary(String txDay) async {
    final data = await _client.getJson(
      '/wallet/daily-payments/pending-summary',
      queryParameters: {'txDay': txDay},
    );
    return DailyPendingSummary(
      pendingCustomerCount: _toInt(data['pendingCustomerCount']),
      pendingWalletCount: _toInt(data['pendingWalletCount']),
    );
  }

  /// Parses `wallet` from mutation response when present.
  static WalletSnapshot? walletFromMutationPayload(Map<String, dynamic> data) {
    final raw = data['wallet'];
    if (raw is! Map) return null;
    return WalletSnapshot.fromBackendMap(Map<String, dynamic>.from(raw));
  }

  Future<WalletSnapshot?> recordDailySaving({
    required String customerId,
    String? walletId,
    required int amountCents,
    required DateTime txDate,
    String? note,
    required String idempotencyKey,
  }) async {
    final data = await _client.postJson(
      '/wallet/daily-saving',
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      body: {
        'customerId': customerId,
        if (walletId != null && walletId.isNotEmpty) 'walletId': walletId,
        'amountCents': amountCents,
        'txDate': txDate.toUtc().toIso8601String(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return walletFromMutationPayload(data);
  }

  Future<WalletSnapshot?> recordDeposit({
    required String customerId,
    String? walletId,
    required int amountCents,
    DateTime? txDate,
    String? note,
    required String idempotencyKey,
  }) async {
    final data = await _client.postJson(
      '/wallet/deposit',
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      body: {
        'customerId': customerId,
        if (walletId != null && walletId.isNotEmpty) 'walletId': walletId,
        'amountCents': amountCents,
        if (txDate != null) 'txDate': txDate.toUtc().toIso8601String(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return walletFromMutationPayload(data);
  }

  Future<WalletSnapshot?> updateWalletStatus({
    required String customerId,
    required String walletId,
    required String targetStatus,
    required String reason,
  }) async {
    final data = await _client.patchJson(
      '/wallet/$customerId/wallets/$walletId/status',
      body: {'targetStatus': targetStatus, 'reason': reason.trim()},
    );
    return walletFromMutationPayload(data);
  }

  Future<({WalletStatusHealth health, List<WalletStatusEvent> events})>
  fetchWalletStatusHistory({
    required String customerId,
    required String walletId,
  }) async {
    final data = await _client.getJson(
      '/wallet/$customerId/wallets/$walletId/status-history',
    );
    final health = WalletStatusHealth.fromBackendMap(
      asJsonMap(data['health'], fieldName: 'health'),
    );
    final events = asJsonList(data['events'], fieldName: 'events')
        .map((e) => WalletStatusEvent.fromBackendMap(asJsonMap(e)))
        .toList(growable: false);
    return (health: health, events: events);
  }
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
