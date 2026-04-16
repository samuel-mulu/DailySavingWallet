import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/cache_ttl.dart';
import '../../core/data/stale_fetch_state.dart';
import '../../data/api/wallet_api.dart';
import '../../data/wallet/models.dart';
import '../../data/wallet/recorded_daily_days_month.dart';
import '../customers/customer_list_notifier.dart';
import '../data/repository_providers.dart';

/// Server-computed pending daily saves for navigation badges.
final dailyPendingSummaryProvider = FutureProvider.autoDispose
    .family<DailyPendingSummary, String>((ref, txDay) {
      return ref.read(walletRepoProvider).fetchDailyPendingSummary(txDay);
    });

/// Server-computed wallet totals for the selected daily check date.
final dailyWalletCountsProvider = FutureProvider.autoDispose
    .family<DailyWalletCounts, String>((ref, txDay) {
      return ref.read(walletRepoProvider).fetchDailyWalletCounts(txDay);
    });

/// All wallets for each customer currently visible in [customerListNotifierProvider].
final walletsForCustomerListProvider =
    FutureProvider.autoDispose<Map<String, List<CustomerWallet>>>((ref) async {
      final items = ref.watch(customerListNotifierProvider).items;
      final customerIds = items.map((c) => c.customerId).toList(growable: false);
      return ref.read(walletRepoProvider).fetchWalletsForCustomers(customerIds);
    });

/// Wallet balance for a customer + optional wallet (null walletId = primary).
final walletStaleProvider = NotifierProvider.autoDispose
    .family<
      WalletStaleNotifier,
      StaleFetchState<WalletSnapshot?>,
      WalletFamilyKey
    >(WalletStaleNotifier.new);

class WalletStaleNotifier
    extends
        AutoDisposeFamilyNotifier<
          StaleFetchState<WalletSnapshot?>,
          WalletFamilyKey
        > {
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
      final w = await ref
          .read(walletRepoProvider)
          .fetchWallet(key.customerId, walletId: key.walletId);
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

class RecentLedgerNotifier
    extends
        AutoDisposeFamilyNotifier<
          StaleFetchState<List<LedgerTx>>,
          WalletFamilyKey
        > {
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
      final items = await ref
          .read(walletRepoProvider)
          .fetchRecentLedger(
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
      final ids = await ref
          .read(walletRepoProvider)
          .fetchRecordedDailyPaymentWalletIds(txDay);
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

typedef RecordedDaysMonthKey = ({String customerId, String walletId, String month});

final recordedDailyDaysByMonthProvider = FutureProvider.autoDispose
    .family<RecordedDailyDaysMonth, RecordedDaysMonthKey>((ref, key) {
      return ref.read(walletRepoProvider).fetchRecordedDailyPaymentDaysByMonth(
        customerId: key.customerId,
        walletId: key.walletId,
        month: key.month,
      );
    });

class DailyCheckPageState {
  final List<DailyCheckRow> rows;
  final DailyCheckSummary summary;
  final String? nextCursor;
  final bool isRefreshing;
  final bool loadingMore;
  final Object? error;
  final String txDay;
  final String search;
  final String? groupId;
  final String filter;

  const DailyCheckPageState({
    required this.rows,
    required this.summary,
    required this.nextCursor,
    required this.isRefreshing,
    required this.loadingMore,
    required this.error,
    required this.txDay,
    required this.search,
    required this.groupId,
    required this.filter,
  });

  factory DailyCheckPageState.initial() {
    return const DailyCheckPageState(
      rows: [],
      summary: DailyCheckSummary(
        customerCount: 0,
        savedCustomerCount: 0,
        notSavedCustomerCount: 0,
        activeWalletCount: 0,
        savedWalletCount: 0,
        pendingWalletCount: 0,
      ),
      nextCursor: null,
      isRefreshing: false,
      loadingMore: false,
      error: null,
      txDay: '',
      search: '',
      groupId: null,
      filter: 'all',
    );
  }
}

final dailyCheckPageNotifierProvider = NotifierProvider.autoDispose<
    DailyCheckPageNotifier,
    DailyCheckPageState
>(DailyCheckPageNotifier.new);

class DailyCheckPageNotifier extends AutoDisposeNotifier<DailyCheckPageState> {
  @override
  DailyCheckPageState build() => DailyCheckPageState.initial();

  Future<void> loadInitial({
    required String txDay,
    String search = '',
    String? groupId,
    String filter = 'all',
    bool force = false,
  }) async {
    final prev = state;
    final sameScope = prev.txDay == txDay &&
        prev.search == search &&
        prev.groupId == groupId &&
        prev.filter == filter;
    if (!force && sameScope && prev.rows.isNotEmpty && prev.error == null) {
      return;
    }

    state = DailyCheckPageState(
      rows: sameScope ? prev.rows : const [],
      summary: sameScope ? prev.summary : DailyCheckPageState.initial().summary,
      nextCursor: null,
      isRefreshing: true,
      loadingMore: false,
      error: null,
      txDay: txDay,
      search: search,
      groupId: groupId,
      filter: filter,
    );

    final loadingState = state;
    try {
      final page = await ref.read(walletRepoProvider).fetchDailyCheckPage(
            txDay: txDay,
            search: search.isEmpty ? null : search,
            groupId: groupId,
            filter: filter,
            limit: 50,
          );
      state = DailyCheckPageState(
        rows: page.rows,
        summary: page.summary,
        nextCursor: page.nextCursor,
        isRefreshing: false,
        loadingMore: false,
        error: null,
        txDay: txDay,
        search: search,
        groupId: groupId,
        filter: filter,
      );
    } catch (error) {
      state = DailyCheckPageState(
        rows: loadingState.rows,
        summary: loadingState.summary,
        nextCursor: loadingState.nextCursor,
        isRefreshing: false,
        loadingMore: false,
        error: error,
        txDay: txDay,
        search: search,
        groupId: groupId,
        filter: filter,
      );
    }
  }

  Future<void> loadMore() async {
    final cur = state;
    final cursor = cur.nextCursor;
    if (cur.loadingMore ||
        cur.isRefreshing ||
        cursor == null ||
        cursor.isEmpty ||
        cur.txDay.isEmpty) {
      return;
    }

    state = DailyCheckPageState(
      rows: cur.rows,
      summary: cur.summary,
      nextCursor: cur.nextCursor,
      isRefreshing: false,
      loadingMore: true,
      error: null,
      txDay: cur.txDay,
      search: cur.search,
      groupId: cur.groupId,
      filter: cur.filter,
    );

    try {
      final page = await ref.read(walletRepoProvider).fetchDailyCheckPage(
            txDay: cur.txDay,
            search: cur.search.isEmpty ? null : cur.search,
            groupId: cur.groupId,
            filter: cur.filter,
            limit: 50,
            cursor: cursor,
          );
      state = DailyCheckPageState(
        rows: [...cur.rows, ...page.rows],
        summary: page.summary,
        nextCursor: page.nextCursor,
        isRefreshing: false,
        loadingMore: false,
        error: null,
        txDay: cur.txDay,
        search: cur.search,
        groupId: cur.groupId,
        filter: cur.filter,
      );
    } catch (error) {
      state = DailyCheckPageState(
        rows: cur.rows,
        summary: cur.summary,
        nextCursor: cur.nextCursor,
        isRefreshing: false,
        loadingMore: false,
        error: error,
        txDay: cur.txDay,
        search: cur.search,
        groupId: cur.groupId,
        filter: cur.filter,
      );
    }
  }
}
