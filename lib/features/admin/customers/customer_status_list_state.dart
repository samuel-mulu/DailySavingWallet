import '../../../data/customers/customer_model.dart';

abstract final class WalletStatusFilter {
  static const String all = 'ALL';
  static const String active = 'ACTIVE';
  static const String frozen = 'FROZEN';
  static const String closed = 'CLOSED';

  static const List<String> allValues = [all, active, frozen, closed];
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
