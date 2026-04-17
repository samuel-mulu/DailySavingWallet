import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/mutation_state.dart';
import '../../../core/data/stale_fetch_state.dart';
import '../../../data/customers/customer_group_model.dart';
import '../../../data/customers/customer_model.dart';
import '../../data/repository_providers.dart';

class CustomerGroupManagementData {
  final List<Customer> customers;
  final List<CustomerGroupSummary> groups;

  const CustomerGroupManagementData({
    required this.customers,
    required this.groups,
  });

  int get unassignedCustomerCount {
    return customers.where((customer) => customer.group == null).length;
  }

  int get assignedCustomerCount {
    return customers.where((customer) => customer.group != null).length;
  }
}

final customerGroupManagementProvider =
    NotifierProvider.autoDispose<
      CustomerGroupManagementNotifier,
      StaleFetchState<CustomerGroupManagementData>
    >(CustomerGroupManagementNotifier.new);

class CustomerGroupManagementNotifier
    extends AutoDisposeNotifier<StaleFetchState<CustomerGroupManagementData>> {
  @override
  StaleFetchState<CustomerGroupManagementData> build() {
    Future.microtask(() => refresh(force: false));
    return StaleFetchState<CustomerGroupManagementData>.initial();
  }

  Future<void> refresh({bool force = true}) async {
    final prev = state;
    if (!force && prev.data != null && prev.error == null) {
      return;
    }
    state = prev.copyWith(isRefreshing: true, clearError: true);
    try {
      final repo = ref.read(customerRepoProvider);
      final results = await Future.wait<Object>([
        repo.fetchAllActiveCustomers(),
        repo.fetchCustomerGroups(),
      ]);
      final customers = (results[0] as List<Customer>).toList()
        ..sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );
      final groupResult = results[1] as CustomerGroupListResult;
      state = StaleFetchState(
        data: CustomerGroupManagementData(
          customers: customers,
          groups: groupResult.groups,
        ),
        isRefreshing: false,
        error: null,
        lastSuccessAt: DateTime.now(),
      );
    } catch (error) {
      state = prev.copyWith(isRefreshing: false, error: error);
    }
  }
}

typedef CustomerGroupMutationCommand = ({
  String type,
  String? groupId,
  String? customerId,
  String? name,
  String? colorHex,
});

final customerGroupMutationProvider =
    NotifierProvider.autoDispose<
      CustomerGroupMutationNotifier,
      MutationState<String>
    >(CustomerGroupMutationNotifier.new);

class CustomerGroupMutationNotifier
    extends AutoDisposeNotifier<MutationState<String>> {
  @override
  MutationState<String> build() => MutationState<String>.idle();

  Future<void> submit(CustomerGroupMutationCommand command) async {
    state = state.loading();
    try {
      final repo = ref.read(customerRepoProvider);
      switch (command.type) {
        case 'create':
          final created = await repo.createCustomerGroup(
            name: command.name!,
            colorHex: command.colorHex!,
          );
          state = state.success('${created.name} created.');
          break;
        case 'rename':
          final updated = await repo.updateCustomerGroup(
            groupId: command.groupId!,
            name: command.name!,
            colorHex: command.colorHex!,
          );
          state = state.success('Renamed to ${updated.name}.');
          break;
        case 'assign':
          await repo.assignCustomerGroup(
            customerId: command.customerId!,
            groupId: command.groupId,
          );
          state = state.success('Customer group updated.');
          break;
        default:
          throw ArgumentError('Unsupported mutation command: ${command.type}');
      }
    } catch (error) {
      state = state.failure(error);
    }
  }

  void clear() {
    state = state.reset();
  }
}
