import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/idempotency/idempotency_key_manager.dart';
import 'package:flutter_application_1/data/api/wallet_api.dart';
import 'package:flutter_application_1/data/api/withdrawal_api.dart';
import 'package:flutter_application_1/data/wallet/models.dart';
import 'package:flutter_application_1/data/wallet/wallet_repo.dart';

class _FakeWalletApi extends WalletApi {
  bool failDailySaving = false;
  bool failDeposit = false;
  final List<String> dailySavingKeys = <String>[];
  final List<String> depositKeys = <String>[];

  @override
  Future<WalletSnapshot?> recordDailySaving({
    required String customerId,
    String? walletId,
    required int amountCents,
    required DateTime txDate,
    String? note,
    required String idempotencyKey,
  }) async {
    dailySavingKeys.add(idempotencyKey);
    if (failDailySaving) {
      throw Exception('network error');
    }
    return null;
  }

  @override
  Future<WalletSnapshot?> recordDeposit({
    required String customerId,
    String? walletId,
    required int amountCents,
    DateTime? txDate,
    String? note,
    required String idempotencyKey,
  }) async {
    depositKeys.add(idempotencyKey);
    if (failDeposit) {
      throw Exception('network error');
    }
    return null;
  }
}

class _FakeWithdrawalApi extends WithdrawalApi {
  bool failApprove = false;
  final List<String> approveKeys = <String>[];
  final List<String> rejectKeys = <String>[];
  final List<String> requestKeys = <String>[];

  @override
  Future<String> requestWithdraw({
    required int amountCents,
    required String reason,
    String? customerId,
    String? walletId,
    required String idempotencyKey,
  }) async {
    requestKeys.add(idempotencyKey);
    return 'req-1';
  }

  @override
  Future<void> approveWithdraw({
    required String requestId,
    required String idempotencyKey,
    int? amountCents,
  }) async {
    approveKeys.add(idempotencyKey);
    if (failApprove) {
      throw Exception('temporary failure');
    }
  }

  @override
  Future<void> rejectWithdraw({
    required String requestId,
    String? note,
    required String idempotencyKey,
  }) async {
    rejectKeys.add(idempotencyKey);
  }
}

void main() {
  group('WalletRepo idempotency lifecycle', () {
    test('failed retry keeps same key, success clears key', () async {
      final keyManager = IdempotencyKeyManager();
      final walletApi = _FakeWalletApi()..failDailySaving = true;
      final repo = WalletRepo(
        walletApi: walletApi,
        withdrawalApi: _FakeWithdrawalApi(),
        idempotencyKeyManager: keyManager,
      );

      await expectLater(
        () => repo.recordDailySaving(
          customerId: 'c1',
          walletId: 'w1',
          amountCents: 1000,
          txDateMillis: 1710000000000,
          logicalActionId: 'daily-action-1',
        ),
        throwsException,
      );

      final firstKey = walletApi.dailySavingKeys.single;
      expect(keyManager.peek('daily-action-1'), firstKey);

      walletApi.failDailySaving = false;
      await repo.recordDailySaving(
        customerId: 'c1',
        walletId: 'w1',
        amountCents: 1000,
        txDateMillis: 1710000000000,
        logicalActionId: 'daily-action-1',
      );

      expect(walletApi.dailySavingKeys.length, 2);
      expect(walletApi.dailySavingKeys[1], firstKey);
      expect(keyManager.peek('daily-action-1'), isNull);
    });

    test('new logical action gets a different key', () async {
      final keyManager = IdempotencyKeyManager();
      final walletApi = _FakeWalletApi();
      final repo = WalletRepo(
        walletApi: walletApi,
        withdrawalApi: _FakeWithdrawalApi(),
        idempotencyKeyManager: keyManager,
      );

      await repo.recordDeposit(
        customerId: 'c1',
        walletId: 'w1',
        amountCents: 1000,
        txDateMillis: 1710000000000,
        logicalActionId: 'deposit-action-1',
      );
      await repo.recordDeposit(
        customerId: 'c1',
        walletId: 'w1',
        amountCents: 1000,
        txDateMillis: 1710000000000,
        logicalActionId: 'deposit-action-2',
      );

      expect(walletApi.depositKeys.length, 2);
      expect(walletApi.depositKeys[0], isNot(walletApi.depositKeys[1]));
    });

    test('approve retry reuses key until success', () async {
      final keyManager = IdempotencyKeyManager();
      final withdrawalApi = _FakeWithdrawalApi()..failApprove = true;
      final repo = WalletRepo(
        walletApi: _FakeWalletApi(),
        withdrawalApi: withdrawalApi,
        idempotencyKeyManager: keyManager,
      );

      await expectLater(
        () => repo.approveWithdraw(
          'req-123',
          amountCents: 2000,
          logicalActionId: 'approve-req-123',
        ),
        throwsException,
      );
      final firstKey = withdrawalApi.approveKeys.single;
      expect(keyManager.peek('approve-req-123'), firstKey);

      withdrawalApi.failApprove = false;
      await repo.approveWithdraw(
        'req-123',
        amountCents: 2000,
        logicalActionId: 'approve-req-123',
      );

      expect(withdrawalApi.approveKeys[1], firstKey);
      expect(keyManager.peek('approve-req-123'), isNull);
    });
  });
}
