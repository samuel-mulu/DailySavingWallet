/// Client-side TTLs for in-memory cache (no polling; only gates background refresh).
abstract final class CacheTtl {
  static const Duration wallet = Duration(seconds: 45);
  static const Duration recentLedger = Duration(seconds: 45);
  static const Duration customerList = Duration(seconds: 60);
  static const Duration pendingWithdrawals = Duration(seconds: 45);
  static const Duration recordedDailyPaymentIds = Duration(seconds: 60);
  static const Duration adminCustomerIds = Duration(minutes: 2);
}
