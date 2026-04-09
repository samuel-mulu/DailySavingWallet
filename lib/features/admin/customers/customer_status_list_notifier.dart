import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository_providers.dart';
import 'customer_status_list_state.dart';

class CustomerStatusListNotifier
    extends AutoDisposeNotifier<CustomerStatusListState> {
  bool _initialScheduled = false;

  @override
  CustomerStatusListState build() {
    if (!_initialScheduled) {
      _initialScheduled = true;
      Future.microtask(loadInitial);
    }
    return CustomerStatusListState.initial();
  }

  Future<void> setWalletStatusFilter(String walletStatus) async {
    await loadInitial(
      walletStatusFilter: walletStatus,
      search: state.searchApplied,
    );
  }

  Future<void> loadInitial({
    String? walletStatusFilter,
    String? search,
  }) async {
    final prev = state;
    final filter = walletStatusFilter ?? prev.walletStatusFilter;
    final appliedSearch = search ?? prev.searchApplied;

    state = CustomerStatusListState(
      walletStatusFilter: filter,
      items: const [],
      nextCursor: null,
      isRefreshing: true,
      loadingMore: false,
      error: null,
      searchApplied: appliedSearch,
    );
    final withRefreshing = state;
    try {
      // Customer status is still customer-level. Wallet filtering is applied in UI.
      final page = await ref.read(customerRepoProvider).fetchCustomersPage(
            search: appliedSearch.isEmpty ? null : appliedSearch,
            limit: 50,
          );
      state = CustomerStatusListState(
        walletStatusFilter: filter,
        items: page.items,
        nextCursor: page.nextCursor,
        isRefreshing: false,
        loadingMore: false,
        error: null,
        searchApplied: appliedSearch,
      );
    } catch (e) {
      state = withRefreshing.copyWith(
        isRefreshing: false,
        error: e,
      );
    }
  }

  Future<void> loadMore() async {
    final cur = state;
    final cursor = cur.nextCursor;
    if (cursor == null || cursor.isEmpty || cur.loadingMore || cur.isRefreshing) {
      return;
    }
    state = cur.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await ref.read(customerRepoProvider).fetchCustomersPage(
            search: cur.searchApplied.isEmpty ? null : cur.searchApplied,
            limit: 50,
            cursor: cursor,
          );
      state = CustomerStatusListState(
        walletStatusFilter: cur.walletStatusFilter,
        items: [...cur.items, ...page.items],
        nextCursor: page.nextCursor,
        isRefreshing: false,
        loadingMore: false,
        error: null,
        searchApplied: cur.searchApplied,
      );
    } catch (e) {
      state = cur.copyWith(loadingMore: false, error: e);
    }
  }

  Future<void> refresh() => loadInitial(
        walletStatusFilter: state.walletStatusFilter,
        search: state.searchApplied,
      );
}
