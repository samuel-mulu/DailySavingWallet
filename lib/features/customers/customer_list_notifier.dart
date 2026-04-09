import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/cache_ttl.dart';
import '../../data/customers/customer_model.dart';
import '../data/repository_providers.dart';
import 'customer_list_state.dart';

final customerListNotifierProvider = NotifierProvider.autoDispose<
    CustomerListNotifier,
    CustomerListState
>(CustomerListNotifier.new);

class CustomerListNotifier extends AutoDisposeNotifier<CustomerListState> {
  bool _initialScheduled = false;

  @override
  CustomerListState build() {
    if (!_initialScheduled) {
      _initialScheduled = true;
      Future.microtask(() => loadInitial(forceNetwork: false));
    }
    return CustomerListState.initial();
  }

  Future<void> loadInitial({
    String search = '',
    bool forceNetwork = false,
  }) async {
    final now = DateTime.now();
    final prev = state;
    final sameSearch = prev.searchApplied == search;
    if (!forceNetwork &&
        sameSearch &&
        prev.items.isNotEmpty &&
        prev.lastFetchedAt != null &&
        now.difference(prev.lastFetchedAt!) < CacheTtl.customerList &&
        prev.error == null) {
      return;
    }

    final searchChanged = !sameSearch;
    state = CustomerListState(
      items: searchChanged ? [] : prev.items,
      nextCursor: null,
      isRefreshing: true,
      loadingMore: false,
      error: null,
      lastFetchedAt: prev.lastFetchedAt,
      searchApplied: search,
    );
    final withRefreshing = state;
    try {
      final page = await ref.read(customerRepoProvider).fetchCustomersPage(
            search: search.isEmpty ? null : search,
            status: CustomerLifecycleStatus.active,
            limit: 50,
          );
      state = CustomerListState(
        items: page.items,
        nextCursor: page.nextCursor,
        isRefreshing: false,
        loadingMore: false,
        error: null,
        lastFetchedAt: DateTime.now(),
        searchApplied: search,
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
            status: CustomerLifecycleStatus.active,
            limit: 50,
            cursor: cursor,
          );
      state = CustomerListState(
        items: [...cur.items, ...page.items],
        nextCursor: page.nextCursor,
        isRefreshing: false,
        loadingMore: false,
        error: null,
        lastFetchedAt: DateTime.now(),
        searchApplied: cur.searchApplied,
      );
    } catch (e) {
      state = cur.copyWith(loadingMore: false, error: e);
    }
  }

  Future<void> refresh({bool force = true}) =>
      loadInitial(search: state.searchApplied, forceNetwork: force);
}
