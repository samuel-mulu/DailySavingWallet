import '../wallet/models.dart';
import 'api_client.dart';

class WalletTotals {
  final int totalSavingCents;
  final int totalCreditCents;
  final int companyWalletBalanceCents;
  final int companyFeeRevenueCents;

  const WalletTotals({
    required this.totalSavingCents,
    required this.totalCreditCents,
    required this.companyWalletBalanceCents,
    required this.companyFeeRevenueCents,
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

class WalletApi {
  final ApiClient _client;

  WalletApi({ApiClient? client}) : _client = client ?? ApiClient();

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
    );
  }

  Future<Map<String, dynamic>> fetchDailySavingsReport(String txDay) {
    return _client.getJson(
      '/wallet/stats/reports/daily',
      queryParameters: {'txDay': txDay},
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
      body: {
        'targetStatus': targetStatus,
        'reason': reason.trim(),
      },
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
