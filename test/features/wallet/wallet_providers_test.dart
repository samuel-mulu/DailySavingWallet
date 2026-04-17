import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahtot/core/data/mutation_state.dart';
import 'package:mahtot/data/wallet/models.dart';
import 'package:mahtot/features/data/repository_providers.dart';
import 'package:mahtot/features/wallet/wallet_providers.dart';

import '../../test_helpers/fake_repos.dart';

void main() {
  test(
    'customerWalletsStaleProvider preserves stale data on refresh error',
    () async {
      final fakeCustomerRepo = FakeCustomerRepo(
        walletsByCustomerId: {
          'customer-1': [
            buildCustomerWallet(
              id: 'wallet-1',
              customerId: 'customer-1',
              displayName: 'Primary Wallet',
              isPrimary: true,
            ),
            buildCustomerWallet(
              id: 'wallet-2',
              customerId: 'customer-1',
              displayName: 'Holiday Wallet',
              isPrimary: false,
              type: 'SECONDARY',
            ),
          ],
        },
      );

      final container = ProviderContainer(
        overrides: [customerRepoProvider.overrideWithValue(fakeCustomerRepo)],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        customerWalletsStaleProvider('customer-1'),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final loaded = container.read(customerWalletsStaleProvider('customer-1'));
      expect(loaded.error, isNull);
      expect(loaded.isRefreshing, isFalse);
      expect(loaded.data?.map((wallet) => wallet.displayName).toList(), [
        'Primary Wallet',
        'Holiday Wallet',
      ]);

      fakeCustomerRepo.throwOnFetchCustomerWallets = true;
      await container
          .read(customerWalletsStaleProvider('customer-1').notifier)
          .refresh(force: true);

      final refreshed = container.read(
        customerWalletsStaleProvider('customer-1'),
      );
      expect(refreshed.error, isA<StateError>());
      expect(refreshed.isRefreshing, isFalse);
      expect(refreshed.data?.map((wallet) => wallet.id).toList(), [
        'wallet-1',
        'wallet-2',
      ]);
    },
  );

  test(
    'ledgerPageNotifierProvider handles initial load, loadMore, refresh, and error',
    () async {
      final month = DateTime(2026, 4, 1);
      final query = CustomerLedgerPageQuery.fromDate(
        customerId: 'customer-1',
        walletId: 'wallet-1',
        month: month,
        filter: CustomerHistoryFilterValues.all,
      );
      final initialKey = ledgerPageKeyFor(
        customerId: query.customerId,
        walletId: query.walletId,
        startDate: query.startDate,
        endDate: query.endDate,
        types: query.types,
      );
      final page2Key = ledgerPageKeyFor(
        customerId: query.customerId,
        walletId: query.walletId,
        startAfter: 'cursor-1',
        startDate: query.startDate,
        endDate: query.endDate,
        types: query.types,
      );

      final fakeWalletRepo = FakeWalletRepo(
        ledgerPagesByKey: {
          initialKey: LedgerPage(
            items: [
              buildLedgerTx(id: 'tx-1'),
              buildLedgerTx(id: 'tx-2'),
            ],
            lastDoc: 'cursor-1',
            hasMore: true,
          ),
          page2Key: LedgerPage(
            items: [buildLedgerTx(id: 'tx-3')],
            lastDoc: null,
            hasMore: false,
          ),
        },
      );

      final container = ProviderContainer(
        overrides: [walletRepoProvider.overrideWithValue(fakeWalletRepo)],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        ledgerPageNotifierProvider(query),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final initialState = container.read(ledgerPageNotifierProvider(query));
      expect(initialState.isRefreshing, isFalse);
      expect(initialState.error, isNull);
      expect(initialState.items.map((tx) => tx.id).toList(), ['tx-1', 'tx-2']);
      expect(initialState.nextCursor, 'cursor-1');
      expect(fakeWalletRepo.fetchLedgerPageCallCount, 1);

      await container
          .read(ledgerPageNotifierProvider(query).notifier)
          .loadMore();
      final afterLoadMore = container.read(ledgerPageNotifierProvider(query));
      expect(afterLoadMore.loadingMore, isFalse);
      expect(afterLoadMore.error, isNull);
      expect(afterLoadMore.items.map((tx) => tx.id).toList(), [
        'tx-1',
        'tx-2',
        'tx-3',
      ]);
      expect(afterLoadMore.nextCursor, isNull);
      expect(fakeWalletRepo.fetchLedgerPageCallCount, 2);

      await container
          .read(ledgerPageNotifierProvider(query).notifier)
          .refresh(force: true);
      final afterRefresh = container.read(ledgerPageNotifierProvider(query));
      expect(afterRefresh.isRefreshing, isFalse);
      expect(afterRefresh.error, isNull);
      expect(afterRefresh.items.map((tx) => tx.id).toList(), ['tx-1', 'tx-2']);
      expect(afterRefresh.nextCursor, 'cursor-1');
      expect(fakeWalletRepo.fetchLedgerPageCallCount, 3);

      fakeWalletRepo.throwOnFetchLedgerPage = true;
      await container
          .read(ledgerPageNotifierProvider(query).notifier)
          .refresh(force: true);
      final afterError = container.read(ledgerPageNotifierProvider(query));
      expect(afterError.isRefreshing, isFalse);
      expect(afterError.error, isA<StateError>());
      expect(afterError.items.map((tx) => tx.id).toList(), ['tx-1', 'tx-2']);
    },
  );

  test(
    'withdraw preview and submit providers handle success and error transitions',
    () async {
      final fakeWalletRepo = FakeWalletRepo(
        previewByAmountCents: {
          3000: const WithdrawPreview(
            requestedAmountCents: 3000,
            feeCents: 100,
            netPayoutCents: 2900,
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [walletRepoProvider.overrideWithValue(fakeWalletRepo)],
      );
      addTearDown(container.dispose);

      final previewSub = container.listen(
        withdrawPreviewProvider(3000),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(previewSub.close);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final loadedPreview = container.read(withdrawPreviewProvider(3000));
      expect(loadedPreview.isRefreshing, isFalse);
      expect(loadedPreview.error, isNull);
      expect(loadedPreview.data?.feeCents, 100);
      expect(fakeWalletRepo.previewWithdrawCallCount, greaterThanOrEqualTo(1));

      fakeWalletRepo.throwOnPreviewWithdraw = true;
      await container
          .read(withdrawPreviewProvider(3000).notifier)
          .refresh(force: true);
      final failedPreview = container.read(withdrawPreviewProvider(3000));
      expect(failedPreview.error, isA<StateError>());
      expect(failedPreview.data?.requestedAmountCents, 3000);

      final submitInitial = container.read(withdrawSubmitMutationProvider);
      expect(submitInitial, isA<MutationState<String?>>());
      expect(submitInitial.isLoading, isFalse);
      expect(submitInitial.error, isNull);

      await container.read(withdrawSubmitMutationProvider.notifier).submit((
        customerId: 'customer-1',
        walletId: 'wallet-1',
        amountCents: 3000,
        reason: 'Need cash',
      ));
      final submitSuccess = container.read(withdrawSubmitMutationProvider);
      expect(submitSuccess.isLoading, isFalse);
      expect(submitSuccess.error, isNull);
      expect(submitSuccess.data, 'request-1');

      fakeWalletRepo.throwOnRequestWithdraw = true;
      await container.read(withdrawSubmitMutationProvider.notifier).submit((
        customerId: 'customer-1',
        walletId: 'wallet-1',
        amountCents: 3000,
        reason: 'Need cash',
      ));
      final submitFailed = container.read(withdrawSubmitMutationProvider);
      expect(submitFailed.isLoading, isFalse);
      expect(submitFailed.error, isA<StateError>());
    },
  );

  test(
    'withdraw approval list and review mutation providers load/refresh and mutate',
    () async {
      final pending = buildWithdrawRequest(
        id: 'wr-1',
        customerId: 'customer-1',
        status: 'PENDING',
      );
      final approved = buildWithdrawRequest(
        id: 'wr-2',
        customerId: 'customer-1',
        status: 'APPROVED',
      );
      final rejected = buildWithdrawRequest(
        id: 'wr-3',
        customerId: 'customer-1',
        status: 'REJECTED',
      );
      final fakeWalletRepo = FakeWalletRepo(
        withdrawRequestsByStatus: {
          'PENDING': [pending],
          'APPROVED': [approved],
          'REJECTED': [rejected],
        },
      );
      final container = ProviderContainer(
        overrides: [walletRepoProvider.overrideWithValue(fakeWalletRepo)],
      );
      addTearDown(container.dispose);

      final pendingSub = container.listen(
        withdrawRequestListProvider(pendingWithdrawListQuery),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(pendingSub.close);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final pendingState = container.read(
        withdrawRequestListProvider(pendingWithdrawListQuery),
      );
      expect(pendingState.isRefreshing, isFalse);
      expect(pendingState.error, isNull);
      expect(pendingState.items.map((e) => e.id).toList(), ['wr-1']);

      await container
          .read(withdrawRequestListProvider(pendingWithdrawListQuery).notifier)
          .refresh(force: true);
      expect(
        fakeWalletRepo.fetchWithdrawRequestsCallCount,
        greaterThanOrEqualTo(2),
      );

      await container.read(withdrawReviewMutationProvider.notifier).submit((
        requestId: 'wr-1',
        approve: true,
        amountCents: 3000,
        note: null,
      ));
      final successMutation = container.read(withdrawReviewMutationProvider);
      expect(successMutation.isLoading, isFalse);
      expect(successMutation.error, isNull);
      expect(successMutation.data, 'wr-1');
      expect(fakeWalletRepo.approveWithdrawCallCount, 1);

      fakeWalletRepo.throwOnRejectWithdraw = true;
      await container.read(withdrawReviewMutationProvider.notifier).submit((
        requestId: 'wr-1',
        approve: false,
        amountCents: null,
        note: 'reject',
      ));
      final failedMutation = container.read(withdrawReviewMutationProvider);
      expect(failedMutation.isLoading, isFalse);
      expect(failedMutation.error, isA<StateError>());
      expect(fakeWalletRepo.rejectWithdrawCallCount, 1);
    },
  );
}
