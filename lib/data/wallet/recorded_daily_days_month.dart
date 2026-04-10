class RecordedDailyDaysMonth {
  final String customerId;
  final String walletId;
  final String month;
  final Set<String> recordedTxDays;

  const RecordedDailyDaysMonth({
    required this.customerId,
    required this.walletId,
    required this.month,
    required this.recordedTxDays,
  });

  static RecordedDailyDaysMonth fromBackendMap(Map<String, dynamic> json) {
    final raw = json['recordedTxDays'];
    final days = raw is List ? raw.map((e) => '$e').toSet() : <String>{};
    return RecordedDailyDaysMonth(
      customerId: (json['customerId'] as String?) ?? '',
      walletId: (json['walletId'] as String?) ?? '',
      month: (json['month'] as String?) ?? '',
      recordedTxDays: days,
    );
  }
}
