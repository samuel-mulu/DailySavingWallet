import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/cache_ttl.dart';
import '../../core/data/stale_fetch_state.dart';
import '../../data/wallet/models.dart';
import '../data/repository_providers.dart';

final pendingWithdrawalsStaleProvider = NotifierProvider.autoDispose<
    PendingWithdrawalsNotifier,
    StaleFetchState<List<WithdrawRequest>>
>(PendingWithdrawalsNotifier.new);

class PendingWithdrawalsNotifier
    extends AutoDisposeNotifier<StaleFetchState<List<WithdrawRequest>>> {
  bool _inFlight = false;

  @override
  StaleFetchState<List<WithdrawRequest>> build() {
    Future.microtask(() => ensureFresh(force: false));
    return StaleFetchState.initial();
  }

  Future<void> ensureFresh({bool force = false}) async {
    final s = state;
    if (!force &&
        s.data != null &&
        s.lastSuccessAt != null &&
        DateTime.now().difference(s.lastSuccessAt!) <
            CacheTtl.pendingWithdrawals) {
      return;
    }
    await refresh(force: force);
  }

  Future<void> refresh({bool force = true, int limit = 99}) async {
    if (_inFlight) return;
    _inFlight = true;
    final prev = state;
    state = prev.copyWith(isRefreshing: true, clearError: true);
    try {
      final items =
          await ref.read(walletRepoProvider).fetchPendingWithdrawRequests(
                limit: limit,
              );
      state = StaleFetchState(
        data: items,
        isRefreshing: false,
        error: null,
        lastSuccessAt: DateTime.now(),
      );
    } catch (e) {
      state = StaleFetchState(
        data: prev.data ?? const <WithdrawRequest>[],
        isRefreshing: false,
        error: e,
        lastSuccessAt: prev.lastSuccessAt,
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Optimistic remove after approve/reject; server refresh on failure.
  void removeById(String id) {
    final list = state.data ?? const <WithdrawRequest>[];
    state = StaleFetchState(
      data: list.where((r) => r.id != id).toList(growable: false),
      isRefreshing: state.isRefreshing,
      error: state.error,
      lastSuccessAt: state.lastSuccessAt,
    );
  }
}
