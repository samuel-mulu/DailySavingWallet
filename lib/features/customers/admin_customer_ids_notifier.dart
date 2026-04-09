import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/cache_ttl.dart';
import '../../core/data/stale_fetch_state.dart';
import '../data/repository_providers.dart';

/// Full active customer id list for admin badges (cursor walk; TTL).
final adminCustomerIdsStaleProvider = NotifierProvider.autoDispose<
    AdminCustomerIdsNotifier,
    StaleFetchState<List<String>>
>(AdminCustomerIdsNotifier.new);

class AdminCustomerIdsNotifier
    extends AutoDisposeNotifier<StaleFetchState<List<String>>> {
  bool _inFlight = false;

  @override
  StaleFetchState<List<String>> build() {
    Future.microtask(() => ensureFresh(force: false));
    return StaleFetchState.initial();
  }

  Future<void> ensureFresh({bool force = false}) async {
    final s = state;
    if (!force &&
        s.data != null &&
        s.data!.isNotEmpty &&
        s.lastSuccessAt != null &&
        DateTime.now().difference(s.lastSuccessAt!) < CacheTtl.adminCustomerIds) {
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
      final ids =
          await ref.read(customerRepoProvider).fetchAllActiveCustomerIds();
      state = StaleFetchState(
        data: ids,
        isRefreshing: false,
        error: null,
        lastSuccessAt: DateTime.now(),
      );
    } catch (e) {
      state = StaleFetchState(
        data: prev.data ?? const <String>[],
        isRefreshing: false,
        error: e,
        lastSuccessAt: prev.lastSuccessAt,
      );
    } finally {
      _inFlight = false;
    }
  }
}
