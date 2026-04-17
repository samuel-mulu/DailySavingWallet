import '../../data/customers/customer_model.dart';

class CustomerListState {
  final List<Customer> items;
  final String? nextCursor;
  final bool isRefreshing;
  final bool loadingMore;
  final Object? error;
  final DateTime? lastFetchedAt;
  final String searchApplied;
  final bool fullyLoaded;

  const CustomerListState({
    required this.items,
    required this.nextCursor,
    required this.isRefreshing,
    required this.loadingMore,
    required this.error,
    required this.lastFetchedAt,
    required this.searchApplied,
    required this.fullyLoaded,
  });

  factory CustomerListState.initial() => const CustomerListState(
        items: [],
        nextCursor: null,
        isRefreshing: false,
        loadingMore: false,
        error: null,
        lastFetchedAt: null,
        searchApplied: '',
        fullyLoaded: false,
      );

  CustomerListState copyWith({
    List<Customer>? items,
    String? nextCursor,
    bool? isRefreshing,
    bool? loadingMore,
    Object? error,
    DateTime? lastFetchedAt,
    String? searchApplied,
    bool? fullyLoaded,
    bool clearError = false,
    bool clearCursor = false,
  }) {
    return CustomerListState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isRefreshing: isRefreshing ?? this.isRefreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      searchApplied: searchApplied ?? this.searchApplied,
      fullyLoaded: fullyLoaded ?? this.fullyLoaded,
    );
  }
}
