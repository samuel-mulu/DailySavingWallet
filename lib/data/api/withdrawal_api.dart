import '../wallet/models.dart';
import 'api_client.dart';

class WithdrawalApi {
  final ApiClient _client;

  WithdrawalApi({ApiClient? client}) : _client = client ?? ApiClient();

  Future<List<WithdrawRequest>> fetchPendingWithdrawals({
    int limit = 20,
  }) async {
    final data = await _client.getJson(
      '/withdrawals/pending',
      queryParameters: {'limit': '$limit'},
    );

    return asJsonList(data['items'], fieldName: 'items')
        .map((item) => WithdrawRequest.fromBackendMap(asJsonMap(item)))
        .toList(growable: false);
  }

  Future<List<WithdrawRequest>> listWithdrawals({
    String? customerId,
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    final data = await _client.getJson(
      '/withdrawals',
      queryParameters: {
        'limit': '$limit',
        if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
        if (status != null && status.isNotEmpty) 'status': status.toUpperCase(),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );

    return asJsonList(data['items'], fieldName: 'items')
        .map((item) => WithdrawRequest.fromBackendMap(asJsonMap(item)))
        .toList(growable: false);
  }

  Future<String> requestWithdraw({
    required int amountCents,
    required String reason,
    String? customerId,
    String? walletId,
    required String idempotencyKey,
  }) async {
    final data = await _client.postJson(
      '/withdrawals/request',
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      body: {
        'amountCents': amountCents,
        'reason': reason,
        if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
        if (walletId != null && walletId.isNotEmpty) 'walletId': walletId,
      },
    );
    final req = asJsonMap(data['request'], fieldName: 'request');
    return (req['id'] as String?) ?? '';
  }

  Future<void> approveWithdraw({
    required String requestId,
    required String idempotencyKey,
    int approvalFeeCents = 0,
  }) async {
    await _client.postJson(
      '/withdrawals/$requestId/approve',
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      body: <String, dynamic>{'approvalFeeCents': approvalFeeCents},
    );
  }

  Future<void> rejectWithdraw({
    required String requestId,
    String? note,
    required String idempotencyKey,
  }) async {
    await _client.postJson(
      '/withdrawals/$requestId/reject',
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      body: {
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }
}
