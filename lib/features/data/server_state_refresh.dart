import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../wallet/wallet_providers.dart';

Future<void> refreshCustomerWalletReadScope(
  WidgetRef ref, {
  required String customerId,
  required String? walletId,
}) async {
  await Future.wait([
    ref
        .read(customerWalletsStaleProvider(customerId).notifier)
        .refresh(force: true),
    ref
        .read(
          walletStaleProvider((
            customerId: customerId,
            walletId: walletId,
          )).notifier,
        )
        .refresh(force: true),
    ref
        .read(
          recentLedgerStaleProvider((
            customerId: customerId,
            walletId: walletId,
          )).notifier,
        )
        .refresh(force: true),
  ]);
}

Future<void> refreshCustomerReportScope(
  WidgetRef ref, {
  required String customerId,
  required String? walletId,
  required String month,
}) async {
  await ref
      .read(customerWalletsStaleProvider(customerId).notifier)
      .refresh(force: true);

  if (walletId == null || walletId.isEmpty) {
    return;
  }

  final _ = await ref.refresh(
    recordedDailyDaysByMonthProvider((
      customerId: customerId,
      walletId: walletId,
      month: month,
    )).future,
  );
}

Future<void> refreshCustomerHistoryScope(
  WidgetRef ref, {
  required String customerId,
  required CustomerLedgerPageQuery query,
}) async {
  await Future.wait([
    ref
        .read(customerWalletsStaleProvider(customerId).notifier)
        .refresh(force: true),
    ref.read(ledgerPageNotifierProvider(query).notifier).refresh(force: true),
  ]);
}
