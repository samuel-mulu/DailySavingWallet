import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/cache_ttl.dart';
import '../../core/data/stale_fetch_state.dart';
import '../../data/api/wallet_api.dart';
import '../../data/wallet/models.dart';
import '../customers/customer_list_notifier.dart';
import '../data/repository_providers.dart';

/// Server-computed pending daily saves for navigation badges.
final dailyPendingSummaryProvider = FutureProvider.autoDispose
    .family<DailyPendingSummary, String>((ref, txDay) {
      return ref.read(walletRepoProvider).fetchDailyPendingSummary(txDay);
    });

/// All wallets for each customer currently visible in [customerListNotifierProvider].
final walletsForCustomerListProvider =
    FutureProvider.autoDispose<Map<String, List<CustomerWallet>>>((ref) async {
      final items = ref.watch(customerListNotifierProvider).items;
      final repo = ref.read(customerRepoProvider);
      final entries = await Future.wait(
        items.map((c) async {
          final wallets = await repo.fetchCustomerWallets(c.customerId);
          return MapEntry(c.customerId, wallets);
        }),
      );
      return Map.fromEntries(entries);
    });

/// Wallet balance for a customer + optional wallet (null walletId = primary).
final walletStaleProvider = NotifierProvider.autoDispose
    .family<
      WalletStaleNotifier,
      StaleFetchState<WalletSnapshot?>,
      WalletFamilyKey
    >(WalletStaleNotifier.new);

class WalletStaleNotifier extends AutoDisposeFamilyNotifier<
    StaleFetchState<WalletSnapshot?>, WalletFamilyKey> {
  bool _inFlight = false;

  @override
  StaleFetchState<WalletSnapshot?> build(WalletFamilyKey arg) {
    Future.microtask(() => ensureFresh(force: false));
    return StaleFetchState.initial();
  }

  Future<void> ensureFresh({bool force = false}) async {
    final s = state;
    if (!force &&
        s.data != null &&
        s.lastSuccessAt != null &&
        DateTime.now().difference(s.lastSuccessAt!) < CacheTtl.wallet) {
      return;
    }
    await refresh(force: force);
  }

  Future<void> refresh({bool force = true}) async {
    if (_inFlight) return;
    _inFlight = true;
    final key = arg;
    final prev = state;
    state = prev.copyWith(isRefreshing: true, clearError: true);
    try {
      final w = await ref.read(walletRepoProvider).fetchWallet(
            key.customerId,
            walletId: key.walletId,
          );
      state = StaleFetchState(
        data: w,
        isRefreshing: false,
        error: null,
        lastSuccessAt: DateTime.now(),
      );
    } catch (e) {
      state = StaleFetchState(
        data: prev.data,
        isRefreshing: false,
        error: e,
        lastSuccessAt: prev.lastSuccessAt,
      );
    } finally {
      _inFlight = false;
    }
  }

  void applyWallet(WalletSnapshot? snapshot) {
    state = StaleFetchState(
      data: snapshot,
      isRefreshing: false,
      error: null,
      lastSuccessAt: DateTime.now(),
    );
  }
}

/// Recent ledger rows for a customer + optional wallet.
final recentLedgerStaleProvider = NotifierProvider.autoDispose
    .family<
      RecentLedgerNotifier,
      StaleFetchState<List<LedgerTx>>,
      WalletFamilyKey
    >(RecentLedgerNotifier.new);

class RecentLedgerNotifier extends AutoDisposeFamilyNotifier<
    StaleFetchState<List<LedgerTx>>, WalletFamilyKey> {
  bool _inFlight = false;

  @override
  StaleFetchState<List<LedgerTx>> build(WalletFamilyKey arg) {
    Future.microtask(() => ensureFresh(force: false));
    return StaleFetchState.initial();
  }

  Future<void> ensureFresh({bool force = false}) async {
    final s = state;
    if (!force &&
        s.data != null &&
        s.lastSuccessAt != null &&
        DateTime.now().difference(s.lastSuccessAt!) < CacheTtl.recentLedger) {
      return;
    }
    await refresh(force: force);
  }

  Future<void> refresh({bool force = true, int limit = 5}) async {
    if (_inFlight) return;
    _inFlight = true;
    final key = arg;
    final prev = state;
    state = prev.copyWith(isRefreshing: true, clearError: true);
    try {
      final items = await ref.read(walletRepoProvider).fetchRecentLedger(
            key.customerId,
            limit: limit,
            walletId: key.walletId,
          );
      state = StaleFetchState(
        data: items,
        isRefreshing: false,
        error: null,
        lastSuccessAt: DateTime.now(),
      );
    } catch (e) {
      state = StaleFetchState(
        data: prev.data ?? const <LedgerTx>[],
        isRefreshing: false,
        error: e,
        lastSuccessAt: prev.lastSuccessAt,
      );
    } finally {
      _inFlight = false;
    }
  }
}

/// Wallet ids that already have a DAILY_PAYMENT for `txDay` (yyyy-MM-dd).
final recordedDailyWalletIdsProvider = NotifierProvider.autoDispose
    .family<
      RecordedDailyWalletIdsNotifier,
      StaleFetchState<Set<String>>,
      String
    >(RecordedDailyWalletIdsNotifier.new);

class RecordedDailyWalletIdsNotifier
    extends AutoDisposeFamilyNotifier<StaleFetchState<Set<String>>, String> {
  bool _inFlight = false;

  @override
  StaleFetchState<Set<String>> build(String txDay) {
    Future.microtask(() => ensureFresh(force: false));
    return StaleFetchState.initial();
  }

  Future<void> ensureFresh({bool force = false}) async {
    final s = state;
    if (!force &&
        s.data != null &&
        s.lastSuccessAt != null &&
        DateTime.now().difference(s.lastSuccessAt!) <
            CacheTtl.recordedDailyPaymentIds) {
      return;
    }
    await refresh(force: force);
  }

  Future<void> refresh({bool force = true}) async {
    if (_inFlight) return;
    _inFlight = true;
    final txDay = arg;
    final prev = state;
    state = prev.copyWith(isRefreshing: true, clearError: true);
    try {
      final ids =
          await ref.read(walletRepoProvider).fetchRecordedDailyPaymentWalletIds(
                txDay,
              );
      state = StaleFetchState(
        data: ids,
        isRefreshing: false,
        error: null,
        lastSuccessAt: DateTime.now(),
      );
    } catch (e) {
      state = StaleFetchState(
        data: prev.data ?? const <String>{},
        isRefreshing: false,
        error: e,
        lastSuccessAt: prev.lastSuccessAt,
      );
    } finally {
      _inFlight = false;
    }
  }

  void addRecordedLocally(String walletId) {
    final cur = state.data ?? <String>{};
    state = StaleFetchState(
      data: {...cur, walletId},
      isRefreshing: state.isRefreshing,
      error: state.error,
      lastSuccessAt: state.lastSuccessAt,
    );
  }
}
