class MutationState<T> {
  final bool isLoading;
  final T? data;
  final Object? error;

  const MutationState({
    required this.isLoading,
    required this.data,
    required this.error,
  });

  factory MutationState.idle() =>
      MutationState<T>(isLoading: false, data: null, error: null);

  MutationState<T> loading() =>
      MutationState(isLoading: true, data: data, error: null);

  MutationState<T> success(T? value) =>
      MutationState(isLoading: false, data: value, error: null);

  MutationState<T> failure(Object err) =>
      MutationState(isLoading: false, data: data, error: err);

  MutationState<T> reset() => MutationState<T>.idle();
}
