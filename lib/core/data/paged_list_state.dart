class PagedListState<T> {
  final List<T> items;
  final String? nextCursor;
  final bool isRefreshing;
  final bool loadingMore;
  final Object? error;
  final DateTime? lastSuccessAt;

  const PagedListState({
    required this.items,
    required this.nextCursor,
    required this.isRefreshing,
    required this.loadingMore,
    required this.error,
    required this.lastSuccessAt,
  });

  factory PagedListState.initial() => const PagedListState(
    items: <Never>[],
    nextCursor: null,
    isRefreshing: false,
    loadingMore: false,
    error: null,
    lastSuccessAt: null,
  );

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  PagedListState<T> copyWith({
    List<T>? items,
    String? nextCursor,
    bool? isRefreshing,
    bool? loadingMore,
    Object? error,
    DateTime? lastSuccessAt,
    bool clearError = false,
    bool clearCursor = false,
  }) {
    return PagedListState<T>(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isRefreshing: isRefreshing ?? this.isRefreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
    );
  }
}
