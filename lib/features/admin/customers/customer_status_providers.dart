import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/wallet/models.dart';
import '../../data/repository_providers.dart';
import 'customer_status_list_notifier.dart';
import 'customer_status_list_state.dart';

final customerStatusListNotifierProvider = NotifierProvider.autoDispose<
    CustomerStatusListNotifier,
    CustomerStatusListState>(CustomerStatusListNotifier.new);

final customerStatusWalletsProvider =
    FutureProvider.autoDispose<Map<String, List<CustomerWallet>>>((ref) async {
  final customers = ref.watch(customerStatusListNotifierProvider).items;
  final repo = ref.read(customerRepoProvider);
  final entries = await Future.wait(
    customers.map((c) async {
      final wallets = await repo.fetchCustomerWallets(c.customerId);
      return MapEntry(c.customerId, wallets);
    }),
  );
  return Map.fromEntries(entries);
});
