import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/cache_ttl.dart';
import '../../core/data/mutation_state.dart';
import '../../core/data/paged_list_state.dart';
import '../../core/data/stale_fetch_state.dart';
import '../../data/customers/customer_model.dart';
import '../../data/api/wallet_api.dart';
import '../../data/wallet/models.dart';
import '../../data/wallet/recorded_daily_days_month.dart';
import '../customers/customer_list_notifier.dart';
import '../data/repository_providers.dart';

typedef WithdrawSubmitCommand = ({
  String? customerId,
  String? walletId,
  int amountCents,
  String reason,
});

class WithdrawRequestListQuery {
  final String status;
  final int limit;

  const WithdrawRequestListQuery({required this.status, this.limit = 60});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WithdrawRequestListQuery &&
          other.status == status &&
          other.limit == limit;

  @override
  int get hashCode => Object.hash(status, limit);
}

const pendingWithdrawListQuery = WithdrawRequestListQuery(status: 'PENDING');
const approvedWithdrawListQuery = WithdrawRequestListQuery(status: 'APPROVED');
const rejectedWithdrawListQuery = WithdrawRequestListQuery(status: 'REJECTED');

typedef WithdrawRequestWalletLookupKey = ({String customerId, String walletId});
typedef WithdrawReviewCommand = ({
  String requestId,
  bool approve,
  int? amountCents,
  String? note,
});
typedef DailyWalletMutationCommand = ({
  String customerId,
  String walletId,
  int amountCents,
  int txDateMillis,
  String? note,
  bool isDailySaving,
});
typedef RecordDailySavingCommand = ({
  String customerId,
  String? walletId,
  int amountCents,
  int txDateMillis,
  String? note,
});

class AdminHomeCustomerBuckets {
  final List<Customer> withSaving;
  final List<Customer> withCredit;
  final List<Customer> withFlat;
  final Map<String, int> savingByCustomerId;
  final Map<String, int> creditByCustomerId;

  const AdminHomeCustomerBuckets({
    required this.withSaving,
    required this.withCredit,
    required this.withFlat,
    required this.savingByCustomerId,
    required this.creditByCustomerId,
  });
}

final adminHomePendingWithdrawCountProvider = FutureProvider.autoDispose<int>((
  ref,
) {
  return ref.read(walletRepoProvider).fetchPendingWithdrawCount(limit: 99);
});

final adminHomeWalletTotalsProvider = FutureProvider.autoDispose<WalletTotals>((
  ref,
) {
  return ref.read(walletRepoProvider).fetchWalletTotals();
});

final adminHomeCustomerBucketsProvider =
    FutureProvider.autoDispose<AdminHomeCustomerBuckets>((ref) async {
      final customerRepo = ref.read(customerRepoProvider);
      final walletRepo = ref.read(walletRepoProvider);
      final customers = await customerRepo.fetchAllActiveCustomers();
      if (customers.isEmpty) {
        return const AdminHomeCustomerBuckets(
          withSaving: <Customer>[],
          withCredit: <Customer>[],
          withFlat: <Customer>[],
          savingByCustomerId: <String, int>{},
          creditByCustomerId: <String, int>{},
        );
      }
      final ids = customers.map((e) => e.customerId).toList(growable: false);
      final walletsByCustomer = await walletRepo.fetchWalletsForCustomers(ids);
      final savingBy = <String, int>{};
      final creditBy = <String, int>{};
      final withSaving = <Customer>[];
      final withCredit = <Customer>[];
      final withFlat = <Customer>[];

      for (final customer in customers) {
        final wallets =
            walletsByCustomer[customer.customerId] ?? const <CustomerWallet>[];
        if (wallets.isEmpty) {
          final bal = customer.balanceCents;
          final saving = bal > 0 ? bal : 0;
          final credit = bal < 0 ? bal.abs() : 0;
          savingBy[customer.customerId] = saving;
          creditBy[customer.customerId] = credit;
          if (bal > 0) withSaving.add(customer);
          if (bal < 0) withCredit.add(customer);
          if (bal == 0) withFlat.add(customer);
          continue;
        }
        final saving = wallets
            .where((w) => w.balanceCents > 0)
            .fold<int>(0, (sum, w) => sum + w.balanceCents);
        final credit = wallets
            .where((w) => w.balanceCents < 0)
            .fold<int>(0, (sum, w) => sum + w.balanceCents.abs());
        final hasFlat = wallets.any((w) => w.balanceCents == 0);
        savingBy[customer.customerId] = saving;
        creditBy[customer.customerId] = credit;
        if (saving > 0) withSaving.add(customer);
        if (credit > 0) withCredit.add(customer);
        if (hasFlat) withFlat.add(customer);
      }

      int byName(Customer a, Customer b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      withSaving.sort(byName);
      withCredit.sort(byName);
      withFlat.sort(byName);

      return AdminHomeCustomerBuckets(
        withSaving: withSaving,
        withCredit: withCredit,
        withFlat: withFlat,
        savingByCustomerId: savingBy,
        creditByCustomerId: creditBy,
      );
    });

final dailySavingsActivityReportProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, txDay) {
      return ref
          .read(walletRepoProvider)
          .fetchDailySavingsActivityReport(txDay);
    });

final monthlySavingsReportProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, month) {
      return ref.read(walletRepoProvider).fetchMonthlySavingsReport(month);
    });

final companyWalletReportProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, limit) {
      return ref
          .read(walletRepoProvider)
          .fetchCompanyWalletReport(limit: limit);
    });

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
      final customerIds = items
          .map((c) => c.customerId)
          .toList(growable: false);
      return ref.read(walletRepoProvider).fetchWalletsForCustomers(customerIds);
    });

/// Wallet list for a single customer detail/report scope.
final customerWalletsStaleProvider = NotifierProvider.autoDispose
    .family<
      CustomerWalletsStaleNotifier,
      StaleFetchState<List<CustomerWallet>>,
      String
    >(CustomerWalletsStaleNotifier.new);

class CustomerWalletsStaleNotifier
    extends
        AutoDisposeFamilyNotifier<
          StaleFetchState<List<CustomerWallet>>,
          String
        > {
  bool _inFlight = false;

  @override
  StaleFetchState<List<CustomerWallet>> build(String customerId) {
    Future.microtask(() => ensureFresh(force: false));
    return StaleFetchState.initial();
  }

  Future<void> ensureFresh({bool force = false}) async {
    final s = state;
    if (!force &&
        s.data != null &&
        s.lastSuccessAt != null &&
        DateTime.now().difference(s.lastSuccessAt!) <
            CacheTtl.customerWallets) {
      return;
    }
    await refresh(force: force);
  }

  Future<void> refresh({bool force = true}) async {
    if (_inFlight) return;
    _inFlight = true;
    final customerId = arg;
    final prev = state;
    state = prev.copyWith(isRefreshing: true, clearError: true);
    try {
      final wallets = await ref
          .read(customerRepoProvider)
          .fetchCustomerWallets(customerId);
      state = StaleFetchState(
        data: wallets,
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
}

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

final withdrawPreviewProvider = NotifierProvider.autoDispose
    .family<WithdrawPreviewNotifier, StaleFetchState<WithdrawPreview>, int>(
      WithdrawPreviewNotifier.new,
    );

class WithdrawPreviewNotifier
    extends AutoDisposeFamilyNotifier<StaleFetchState<WithdrawPreview>, int> {
  bool _inFlight = false;

  @override
  StaleFetchState<WithdrawPreview> build(int amountCents) {
    Future.microtask(() => ensureFresh(force: false));
    return StaleFetchState(
      data: WithdrawPreview.calculate(amountCents),
      isRefreshing: true,
      error: null,
      lastSuccessAt: null,
    );
  }

  Future<void> ensureFresh({bool force = false}) async {
    final s = state;
    if (!force &&
        s.lastSuccessAt != null &&
        DateTime.now().difference(s.lastSuccessAt!) < CacheTtl.wallet) {
      return;
    }
    await refresh(force: force);
  }

  Future<void> refresh({bool force = true}) async {
    if (_inFlight) return;
    _inFlight = true;
    final prev = state;
    state = prev.copyWith(isRefreshing: true, clearError: true);
    try {
      final preview = await ref
          .read(walletRepoProvider)
          .previewWithdraw(amountCents: arg);
      state = StaleFetchState(
        data: preview,
        isRefreshing: false,
        error: null,
        lastSuccessAt: DateTime.now(),
      );
    } catch (e) {
      state = StaleFetchState(
        data: prev.data ?? WithdrawPreview.calculate(arg),
        isRefreshing: false,
        error: e,
        lastSuccessAt: prev.lastSuccessAt,
      );
    } finally {
      _inFlight = false;
    }
  }
}

final withdrawSubmitMutationProvider =
    NotifierProvider.autoDispose<
      WithdrawSubmitNotifier,
      MutationState<String?>
    >(WithdrawSubmitNotifier.new);

class WithdrawSubmitNotifier
    extends AutoDisposeNotifier<MutationState<String?>> {
  @override
  MutationState<String?> build() => MutationState<String?>.idle();

  Future<void> submit(WithdrawSubmitCommand command) async {
    state = state.loading();
    try {
      final customerId = command.customerId;
      String? requestId;
      if (customerId != null && customerId.isNotEmpty) {
        requestId = await ref
            .read(walletRepoProvider)
            .requestWithdrawForCustomer(
              customerId: customerId,
              walletId: command.walletId,
              amountCents: command.amountCents,
              reason: command.reason,
            );
      } else {
        await ref
            .read(walletRepoProvider)
            .requestWithdraw(
              amountCents: command.amountCents,
              reason: command.reason,
            );
      }
      state = state.success(requestId);
    } catch (e) {
      state = state.failure(e);
    }
  }

  void clear() {
    state = state.reset();
  }
}

final withdrawRequestListProvider = NotifierProvider.autoDispose
    .family<
      WithdrawRequestListNotifier,
      PagedListState<WithdrawRequest>,
      WithdrawRequestListQuery
    >(WithdrawRequestListNotifier.new);

class WithdrawRequestListNotifier
    extends
        AutoDisposeFamilyNotifier<
          PagedListState<WithdrawRequest>,
          WithdrawRequestListQuery
        > {
  bool _initialScheduled = false;

  @override
  PagedListState<WithdrawRequest> build(WithdrawRequestListQuery arg) {
    if (!_initialScheduled) {
      _initialScheduled = true;
      Future.microtask(() => loadInitial(forceNetwork: false));
    }
    return PagedListState<WithdrawRequest>.initial();
  }

  Future<void> loadInitial({bool forceNetwork = true}) async {
    final now = DateTime.now();
    final prev = state;
    if (!forceNetwork &&
        prev.items.isNotEmpty &&
        prev.lastSuccessAt != null &&
        prev.error == null &&
        now.difference(prev.lastSuccessAt!) < CacheTtl.pendingWithdrawals) {
      return;
    }
    state = prev.copyWith(
      isRefreshing: true,
      loadingMore: false,
      clearError: true,
      clearCursor: true,
    );
    try {
      final items = await ref
          .read(walletRepoProvider)
          .fetchWithdrawRequests(status: arg.status, limit: arg.limit);
      final sorted = [...items]
        ..sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      state = PagedListState(
        items: sorted,
        nextCursor: null,
        isRefreshing: false,
        loadingMore: false,
        error: null,
        lastSuccessAt: DateTime.now(),
      );
    } catch (error) {
      state = prev.copyWith(isRefreshing: false, error: error);
    }
  }

  Future<void> refresh({bool force = true}) => loadInitial(forceNetwork: force);
}

final withdrawReviewMutationProvider =
    NotifierProvider.autoDispose<
      WithdrawReviewMutationNotifier,
      MutationState<String>
    >(WithdrawReviewMutationNotifier.new);

class WithdrawReviewMutationNotifier
    extends AutoDisposeNotifier<MutationState<String>> {
  @override
  MutationState<String> build() => MutationState<String>.idle();

  Future<void> submit(WithdrawReviewCommand command) async {
    state = MutationState<String>(
      isLoading: true,
      data: command.requestId,
      error: null,
    );
    try {
      if (command.approve) {
        await ref
            .read(walletRepoProvider)
            .approveWithdraw(
              command.requestId,
              amountCents: command.amountCents,
            );
      } else {
        await ref
            .read(walletRepoProvider)
            .rejectWithdraw(command.requestId, note: command.note);
      }
      state = MutationState<String>(
        isLoading: false,
        data: command.requestId,
        error: null,
      );
      await Future.wait([
        ref
            .read(
              withdrawRequestListProvider(pendingWithdrawListQuery).notifier,
            )
            .refresh(force: true),
        ref
            .read(
              withdrawRequestListProvider(approvedWithdrawListQuery).notifier,
            )
            .refresh(force: true),
        ref
            .read(
              withdrawRequestListProvider(rejectedWithdrawListQuery).notifier,
            )
            .refresh(force: true),
      ]);
    } catch (e) {
      state = MutationState<String>(
        isLoading: false,
        data: command.requestId,
        error: e,
      );
      await ref
          .read(withdrawRequestListProvider(pendingWithdrawListQuery).notifier)
          .refresh(force: true);
    }
  }

  void clear() {
    state = MutationState<String>.idle();
  }
}

final customerByIdProvider = FutureProvider.autoDispose
    .family<Customer?, String>(
      (ref, customerId) =>
          ref.read(customerRepoProvider).getCustomer(customerId),
    );

final requestWalletLookupProvider = FutureProvider.autoDispose
    .family<WalletSnapshot?, WithdrawRequestWalletLookupKey>((ref, key) {
      return ref
          .read(walletRepoProvider)
          .fetchWallet(key.customerId, walletId: key.walletId);
    });

typedef WalletStatusHistoryKey = ({String customerId, String walletId});

final walletStatusHistoryProvider = FutureProvider.autoDispose
    .family<
      ({WalletStatusHealth health, List<WalletStatusEvent> events}),
      WalletStatusHistoryKey
    >((ref, key) {
      return ref
          .read(walletRepoProvider)
          .fetchWalletStatusHistory(
            customerId: key.customerId,
            walletId: key.walletId,
          );
    });

final dailyWalletMutationProvider =
    NotifierProvider.autoDispose<
      DailyWalletMutationNotifier,
      MutationState<WalletSnapshot?>
    >(DailyWalletMutationNotifier.new);

class DailyWalletMutationNotifier
    extends AutoDisposeNotifier<MutationState<WalletSnapshot?>> {
  @override
  MutationState<WalletSnapshot?> build() =>
      MutationState<WalletSnapshot?>.idle();

  Future<void> submit(DailyWalletMutationCommand command) async {
    state = state.loading();
    try {
      final repo = ref.read(walletRepoProvider);
      final result = command.isDailySaving
          ? await repo.recordDailySaving(
              customerId: command.customerId,
              walletId: command.walletId,
              amountCents: command.amountCents,
              txDateMillis: command.txDateMillis,
              note: command.note,
            )
          : await repo.recordDeposit(
              customerId: command.customerId,
              walletId: command.walletId,
              amountCents: command.amountCents,
              txDateMillis: command.txDateMillis,
              note: command.note,
            );
      state = state.success(result);
    } catch (e) {
      state = state.failure(e);
    }
  }

  void clear() {
    state = state.reset();
  }
}

final recordDailySavingMutationProvider =
    NotifierProvider.autoDispose<
      RecordDailySavingMutationNotifier,
      MutationState<WalletSnapshot?>
    >(RecordDailySavingMutationNotifier.new);

class RecordDailySavingMutationNotifier
    extends AutoDisposeNotifier<MutationState<WalletSnapshot?>> {
  @override
  MutationState<WalletSnapshot?> build() =>
      MutationState<WalletSnapshot?>.idle();

  Future<void> submit(RecordDailySavingCommand command) async {
    state = state.loading();
    try {
      final result = await ref
          .read(walletRepoProvider)
          .recordDailySaving(
            customerId: command.customerId,
            walletId: command.walletId,
            amountCents: command.amountCents,
            txDateMillis: command.txDateMillis,
            note: command.note,
          );
      state = state.success(result);
    } catch (e) {
      state = state.failure(e);
    }
  }

  void clear() {
    state = state.reset();
  }
}

abstract final class CustomerHistoryFilterValues {
  static const String all = 'All';
  static const String withdrawals = 'Withdrawals';
  static const String deposits = 'Deposits';
  static const String saving = 'Saving';

  static const List<String> allValues = <String>[
    all,
    withdrawals,
    deposits,
    saving,
  ];
}

const Map<String, List<String>> _customerHistoryTypesByFilter =
    <String, List<String>>{
      CustomerHistoryFilterValues.all: <String>[],
      CustomerHistoryFilterValues.withdrawals: <String>[
        'WITHDRAW_REQUEST',
        'WITHDRAW_APPROVE',
      ],
      CustomerHistoryFilterValues.deposits: <String>['DEPOSIT', 'ADJUSTMENT'],
      CustomerHistoryFilterValues.saving: <String>['DAILY_PAYMENT'],
    };

List<String> ledgerTypesForCustomerHistoryFilter(String filter) {
  final types = _customerHistoryTypesByFilter[filter];
  if (types == null) {
    return const <String>[];
  }
  return types;
}

class CustomerLedgerPageQuery {
  final String customerId;
  final String? walletId;
  final int year;
  final int month;
  final String filter;

  const CustomerLedgerPageQuery({
    required this.customerId,
    required this.walletId,
    required this.year,
    required this.month,
    required this.filter,
  });

  factory CustomerLedgerPageQuery.fromDate({
    required String customerId,
    required String? walletId,
    required DateTime month,
    required String filter,
  }) {
    return CustomerLedgerPageQuery(
      customerId: customerId,
      walletId: walletId,
      year: month.year,
      month: month.month,
      filter: filter,
    );
  }

  DateTime get startDate => DateTime(year, month, 1);

  DateTime get endDate => DateTime(year, month + 1, 0, 23, 59, 59);

  List<String> get types => ledgerTypesForCustomerHistoryFilter(filter);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomerLedgerPageQuery &&
        other.customerId == customerId &&
        other.walletId == walletId &&
        other.year == year &&
        other.month == month &&
        other.filter == filter;
  }

  @override
  int get hashCode => Object.hash(customerId, walletId, year, month, filter);
}

final ledgerPageNotifierProvider = NotifierProvider.autoDispose
    .family<
      LedgerPageNotifier,
      PagedListState<LedgerTx>,
      CustomerLedgerPageQuery
    >(LedgerPageNotifier.new);

class LedgerPageNotifier
    extends
        AutoDisposeFamilyNotifier<
          PagedListState<LedgerTx>,
          CustomerLedgerPageQuery
        > {
  bool _initialScheduled = false;

  @override
  PagedListState<LedgerTx> build(CustomerLedgerPageQuery arg) {
    if (!_initialScheduled) {
      _initialScheduled = true;
      Future.microtask(() => loadInitial(forceNetwork: false));
    }
    return PagedListState<LedgerTx>.initial();
  }

  Future<void> loadInitial({bool forceNetwork = true}) async {
    final now = DateTime.now();
    final prev = state;
    if (!forceNetwork &&
        prev.items.isNotEmpty &&
        prev.lastSuccessAt != null &&
        prev.error == null &&
        now.difference(prev.lastSuccessAt!) < CacheTtl.ledgerPage) {
      return;
    }

    state = PagedListState(
      items: prev.items,
      nextCursor: null,
      isRefreshing: true,
      loadingMore: false,
      error: null,
      lastSuccessAt: prev.lastSuccessAt,
    );
    final refreshingState = state;
    try {
      final page = await ref
          .read(walletRepoProvider)
          .fetchLedgerPage(
            arg.customerId,
            startDate: arg.startDate,
            endDate: arg.endDate,
            types: arg.types,
            walletId: arg.walletId,
          );
      state = PagedListState(
        items: page.items,
        nextCursor: _nextLedgerCursor(page.lastDoc),
        isRefreshing: false,
        loadingMore: false,
        error: null,
        lastSuccessAt: DateTime.now(),
      );
    } catch (error) {
      state = refreshingState.copyWith(isRefreshing: false, error: error);
    }
  }

  Future<void> loadMore() async {
    final cur = state;
    final cursor = cur.nextCursor;
    if (cursor == null ||
        cursor.isEmpty ||
        cur.loadingMore ||
        cur.isRefreshing) {
      return;
    }

    state = cur.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await ref
          .read(walletRepoProvider)
          .fetchLedgerPage(
            arg.customerId,
            startAfter: cursor,
            startDate: arg.startDate,
            endDate: arg.endDate,
            types: arg.types,
            walletId: arg.walletId,
          );
      state = PagedListState(
        items: [...cur.items, ...page.items],
        nextCursor: _nextLedgerCursor(page.lastDoc),
        isRefreshing: false,
        loadingMore: false,
        error: null,
        lastSuccessAt: DateTime.now(),
      );
    } catch (error) {
      state = cur.copyWith(loadingMore: false, error: error);
    }
  }

  Future<void> refresh({bool force = true}) => loadInitial(forceNetwork: force);
}

class CustomerDashboardLedgerQuery {
  final String customerId;

  const CustomerDashboardLedgerQuery({required this.customerId});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomerDashboardLedgerQuery &&
        other.customerId == customerId;
  }

  @override
  int get hashCode => customerId.hashCode;
}

final customerDashboardLedgerProvider = NotifierProvider.autoDispose
    .family<
      CustomerDashboardLedgerNotifier,
      PagedListState<LedgerTx>,
      CustomerDashboardLedgerQuery
    >(CustomerDashboardLedgerNotifier.new);

class CustomerDashboardLedgerNotifier
    extends
        AutoDisposeFamilyNotifier<
          PagedListState<LedgerTx>,
          CustomerDashboardLedgerQuery
        > {
  bool _initialScheduled = false;

  @override
  PagedListState<LedgerTx> build(CustomerDashboardLedgerQuery arg) {
    if (!_initialScheduled) {
      _initialScheduled = true;
      Future.microtask(() => loadInitial(forceNetwork: false));
    }
    return PagedListState<LedgerTx>.initial();
  }

  Future<void> loadInitial({bool forceNetwork = true}) async {
    final now = DateTime.now();
    final prev = state;
    if (!forceNetwork &&
        prev.items.isNotEmpty &&
        prev.lastSuccessAt != null &&
        prev.error == null &&
        now.difference(prev.lastSuccessAt!) < CacheTtl.ledgerPage) {
      return;
    }

    state = PagedListState(
      items: prev.items,
      nextCursor: null,
      isRefreshing: true,
      loadingMore: false,
      error: null,
      lastSuccessAt: prev.lastSuccessAt,
    );
    final refreshingState = state;
    try {
      final page = await ref
          .read(walletRepoProvider)
          .fetchLedgerPage(arg.customerId);
      state = PagedListState(
        items: page.items,
        nextCursor: _nextLedgerCursor(page.lastDoc),
        isRefreshing: false,
        loadingMore: false,
        error: null,
        lastSuccessAt: DateTime.now(),
      );
    } catch (error) {
      state = refreshingState.copyWith(isRefreshing: false, error: error);
    }
  }

  Future<void> loadMore() async {
    final cur = state;
    final cursor = cur.nextCursor;
    if (cursor == null ||
        cursor.isEmpty ||
        cur.loadingMore ||
        cur.isRefreshing) {
      return;
    }

    state = cur.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await ref
          .read(walletRepoProvider)
          .fetchLedgerPage(arg.customerId, startAfter: cursor);
      state = PagedListState(
        items: [...cur.items, ...page.items],
        nextCursor: _nextLedgerCursor(page.lastDoc),
        isRefreshing: false,
        loadingMore: false,
        error: null,
        lastSuccessAt: DateTime.now(),
      );
    } catch (error) {
      state = cur.copyWith(loadingMore: false, error: error);
    }
  }

  Future<void> refresh({bool force = true}) => loadInitial(forceNetwork: force);
}

String? _nextLedgerCursor(Object? lastDoc) {
  if (lastDoc is String && lastDoc.isNotEmpty) {
    return lastDoc;
  }
  return null;
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

typedef RecordedDaysMonthKey = ({
  String customerId,
  String walletId,
  String month,
});

final recordedDailyDaysByMonthProvider = FutureProvider.autoDispose
    .family<RecordedDailyDaysMonth, RecordedDaysMonthKey>((ref, key) {
      return ref
          .read(walletRepoProvider)
          .fetchRecordedDailyPaymentDaysByMonth(
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

final dailyCheckPageNotifierProvider =
    NotifierProvider.autoDispose<DailyCheckPageNotifier, DailyCheckPageState>(
      DailyCheckPageNotifier.new,
    );

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
    final sameScope =
        prev.txDay == txDay &&
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
      final page = await ref
          .read(walletRepoProvider)
          .fetchDailyCheckPage(
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
      final page = await ref
          .read(walletRepoProvider)
          .fetchDailyCheckPage(
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
