/// Holds last good data plus refresh metadata for stale-while-revalidate UI.
class StaleFetchState<T> {
  final T? data;
  final bool isRefreshing;
  final Object? error;
  final DateTime? lastSuccessAt;

  const StaleFetchState({
    required this.data,
    required this.isRefreshing,
    required this.error,
    required this.lastSuccessAt,
  });

  factory StaleFetchState.initial() => const StaleFetchState(
        data: null,
        isRefreshing: false,
        error: null,
        lastSuccessAt: null,
      );

  StaleFetchState<T> copyWith({
    T? data,
    bool? isRefreshing,
    Object? error,
    DateTime? lastSuccessAt,
    bool clearError = false,
    bool clearData = false,
  }) {
    return StaleFetchState<T>(
      data: clearData ? null : (data ?? this.data),
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
    );
  }
}
