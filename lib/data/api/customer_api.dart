import '../customers/customer_model.dart';
import '../customers/customer_group_model.dart';
import '../wallet/models.dart';
import 'api_client.dart';

class CustomerStatusCounts {
  final int active;
  final int onHold;
  final int frozen;
  final int deactive;

  const CustomerStatusCounts({
    required this.active,
    required this.onHold,
    required this.frozen,
    required this.deactive,
  });

  int countForCanonical(String canonical) {
    switch (canonical) {
      case CustomerLifecycleStatus.active:
        return active;
      case CustomerLifecycleStatus.onHold:
        return onHold;
      case CustomerLifecycleStatus.frozen:
        return frozen;
      case CustomerLifecycleStatus.deactive:
        return deactive;
      default:
        return 0;
    }
  }
}

class CustomerPage {
  final List<Customer> items;
  final String? nextCursor;

  const CustomerPage({required this.items, required this.nextCursor});
}

class CustomerApi {
  final ApiClient _client;

  CustomerApi({ApiClient? client}) : _client = client ?? ApiClient();

  Future<CustomerPage> fetchCustomersPage({
    String? search,
    String? status = 'active',
    String? walletStatus,
    int limit = 50,
    String? cursor,
  }) async {
    final data = await _client.getJson(
      '/customers',
      queryParameters: {
        'limit': '$limit',
        if (status != null && status.trim().isNotEmpty)
          'status': CustomerLifecycleStatus.toApiValue(status),
        if (walletStatus != null && walletStatus.trim().isNotEmpty)
          'walletStatus': walletStatus.trim().toUpperCase(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );

    final items = asJsonList(data['items'], fieldName: 'items')
        .map((item) => Customer.fromBackendMap(asJsonMap(item)))
        .toList(growable: false);
    final next = data['nextCursor'];
    final nextCursor = next is String && next.isNotEmpty ? next : null;
    return CustomerPage(items: items, nextCursor: nextCursor);
  }

  Future<List<Customer>> fetchCustomers({
    String? search,
    String? status = 'active',
    String? walletStatus,
    int limit = 200,
  }) async {
    final page = await fetchCustomersPage(
      search: search,
      status: status,
      walletStatus: walletStatus,
      limit: limit,
    );
    return page.items;
  }

  Future<CustomerStatusCounts> fetchCustomerStatusCounts() async {
    final data = await _client.getJson('/customers/status-counts');
    final counts = asJsonMap(data['counts'], fieldName: 'counts');
    int n(Object? key) {
      final v = counts[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return CustomerStatusCounts(
      active: n('ACTIVE'),
      onHold: n('ON_HOLD'),
      frozen: n('FROZEN'),
      deactive: n('DEACTIVE'),
    );
  }

  Future<CustomerGroupListResult> fetchCustomerGroups() async {
    final data = await _client.getJson('/customers/groups');
    final groups = asJsonList(data['groups'], fieldName: 'groups')
        .map((item) => CustomerGroupSummary.fromBackendMap(asJsonMap(item)))
        .toList(growable: false);
    final unassigned = data['unassignedCustomerCount'];
    final unassignedCustomerCount = unassigned is int
        ? unassigned
        : unassigned is num
        ? unassigned.toInt()
        : unassigned is String
        ? int.tryParse(unassigned) ?? 0
        : 0;

    return CustomerGroupListResult(
      groups: groups,
      unassignedCustomerCount: unassignedCustomerCount,
    );
  }

  Future<Customer?> fetchCustomer(String customerId) async {
    try {
      final data = await _client.getJson('/customers/$customerId');
      return Customer.fromBackendMap(
        asJsonMap(data['customer'], fieldName: 'customer'),
      );
    } on BackendApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCustomer({
    required String fullName,
    required String phone,
    required String companyName,
    required String address,
    required String email,
    required String password,
    required int dailyTargetCents,
    int creditLimitCents = 0,
    required String idempotencyKey,
  }) async {
    final data = await _client.postJson(
      '/customers',
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      body: {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'companyName': companyName.trim(),
        'address': address.trim(),
        'email': email.trim(),
        'password': password,
        'dailyTargetCents': dailyTargetCents,
        'creditLimitCents': creditLimitCents,
      },
    );
    final customer = asJsonMap(data['customer'], fieldName: 'customer');
    final user = asJsonMap(data['user'], fieldName: 'user');
    return {
      'customerId': customer['id'] as String? ?? '',
      'uid': user['id'] as String? ?? '',
      'email': user['email'] as String? ?? email,
    };
  }

  Future<CustomerGroupSummary> createCustomerGroup({
    required String name,
    required String idempotencyKey,
  }) async {
    final data = await _client.postJson(
      '/customers/groups',
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      body: {'name': name.trim()},
    );
    return CustomerGroupSummary.fromBackendMap(
      asJsonMap(data['group'], fieldName: 'group'),
    );
  }

  Future<CustomerGroupSummary> updateCustomerGroup({
    required String groupId,
    required String name,
  }) async {
    final data = await _client.patchJson(
      '/customers/groups/$groupId',
      body: {'name': name.trim()},
    );
    return CustomerGroupSummary.fromBackendMap(
      asJsonMap(data['group'], fieldName: 'group'),
    );
  }

  Future<void> updateCustomer({
    required String customerId,
    required String fullName,
    required String phone,
    required String companyName,
    required String address,
    required String email,
    required int dailyTargetCents,
    required int creditLimitCents,
  }) async {
    await _client.patchJson(
      '/customers/$customerId',
      body: {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'companyName': companyName.trim(),
        'address': address.trim(),
        'email': email.trim(),
        'dailyTargetCents': dailyTargetCents,
        'creditLimitCents': creditLimitCents,
      },
    );
  }

  Future<void> patchCustomerStatus({
    required String customerId,
    required String canonicalStatus,
    String? statusReason,
  }) async {
    await _client.patchJson(
      '/customers/$customerId',
      body: {
        'status': CustomerLifecycleStatus.toApiValue(canonicalStatus),
        if (statusReason != null && statusReason.trim().isNotEmpty)
          'statusReason': statusReason.trim(),
      },
    );
  }

  Future<void> assignCustomerGroup({
    required String customerId,
    required String? groupId,
  }) async {
    await _client.patchJson(
      '/customers/$customerId/group',
      body: {'groupId': groupId},
    );
  }

  Future<List<CustomerWallet>> fetchCustomerWallets(String customerId) async {
    final data = await _client.getJson('/customers/$customerId/wallets');
    final raw = asJsonList(data['wallets'], fieldName: 'wallets');
    return raw
        .map((e) => CustomerWallet.fromBackendMap(asJsonMap(e)))
        .toList(growable: false);
  }

  Future<CustomerWallet> createSecondaryWallet({
    required String customerId,
    required String displayName,
    String? code,
    required int dailyTargetCents,
    int creditLimitCents = 0,
    required String idempotencyKey,
  }) async {
    final data = await _client.postJson(
      '/customers/$customerId/wallets',
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      body: {
        'displayName': displayName.trim(),
        if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
        'dailyTargetCents': dailyTargetCents,
        'creditLimitCents': creditLimitCents,
      },
    );
    final w = asJsonMap(data['wallet'], fieldName: 'wallet');
    return CustomerWallet.fromBackendMap(w);
  }
}
