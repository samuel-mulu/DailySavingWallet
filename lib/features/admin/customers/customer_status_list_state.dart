import '../../../data/customers/customer_model.dart';
import '../../wallet/wallet_status_utils.dart';

abstract final class WalletStatusFilter {
  static const String all = WalletStatusValues.all;
  static const String active = WalletStatusValues.active;
  static const String frozen = WalletStatusValues.frozen;
  static const String closed = WalletStatusValues.closed;
  static const String unknown = WalletStatusValues.unknown;

  static const List<String> allValues = WalletStatusValues.allFilters;
}

class CustomerStatusListState {
  final String walletStatusFilter;
  final List<Customer> items;
  final String? nextCursor;
  final bool isRefreshing;
  final bool loadingMore;
  final Object? error;
  final String searchApplied;

  const CustomerStatusListState({
    required this.walletStatusFilter,
    required this.items,
    required this.nextCursor,
    required this.isRefreshing,
    required this.loadingMore,
    required this.error,
    required this.searchApplied,
  });

  factory CustomerStatusListState.initial() => const CustomerStatusListState(
        walletStatusFilter: WalletStatusFilter.all,
        items: [],
        nextCursor: null,
        isRefreshing: false,
        loadingMore: false,
        error: null,
        searchApplied: '',
      );

  CustomerStatusListState copyWith({
    String? walletStatusFilter,
    List<Customer>? items,
    String? nextCursor,
    bool? isRefreshing,
    bool? loadingMore,
    Object? error,
    String? searchApplied,
    bool clearError = false,
  }) {
    return CustomerStatusListState(
      walletStatusFilter: walletStatusFilter ?? this.walletStatusFilter,
      items: items ?? this.items,
      nextCursor: nextCursor ?? this.nextCursor,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      searchApplied: searchApplied ?? this.searchApplied,
    );
  }
}
