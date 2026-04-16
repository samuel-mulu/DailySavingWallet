import 'package:uuid/uuid.dart';

import '../../core/idempotency/idempotency_key_manager.dart';
import '../../core/logging/app_logger.dart';
import '../api/customer_api.dart';
import '../api/media_api.dart';
import '../wallet/models.dart';
import 'customer_group_model.dart';
import 'customer_media.dart';
import 'customer_model.dart';

class CustomerRepo {
  CustomerRepo({
    CustomerApi? customerApi,
    MediaApi? mediaApi,
    Uuid? uuid,
    IdempotencyKeyManager? idempotencyKeyManager,
  }) : _customerApi = customerApi ?? CustomerApi(),
       _mediaApi = mediaApi ?? MediaApi(),
       _uuid = uuid ?? const Uuid(),
       _idempotencyKeyManager =
           idempotencyKeyManager ?? IdempotencyKeyManager();

  final CustomerApi _customerApi;
  final MediaApi _mediaApi;
  final Uuid _uuid;
  final IdempotencyKeyManager _idempotencyKeyManager;

  Future<CustomerPage> fetchCustomersPage({
    String? search,
    String? status = 'active',
    String? walletStatus,
    int limit = 50,
    String? cursor,
  }) {
    return _customerApi.fetchCustomersPage(
      search: search,
      status: status,
      walletStatus: walletStatus,
      limit: limit,
      cursor: cursor,
    );
  }

  /// All active customer ids (cursor walk; call sparingly e.g. admin badges).
  Future<List<String>> fetchAllActiveCustomerIds() async {
    final ids = <String>[];
    String? cursor;
    do {
      final page = await fetchCustomersPage(
        status: 'active',
        limit: 100,
        cursor: cursor,
      );
      ids.addAll(page.items.map((c) => c.customerId));
      cursor = page.nextCursor;
    } while (cursor != null && cursor.isNotEmpty);
    return ids;
  }

  /// Full active customer list (cursor walk; use for admin summaries/modals).
  Future<List<Customer>> fetchAllActiveCustomers() async {
    final customers = <Customer>[];
    String? cursor;
    do {
      final page = await fetchCustomersPage(
        status: 'active',
        limit: 100,
        cursor: cursor,
      );
      customers.addAll(page.items);
      cursor = page.nextCursor;
    } while (cursor != null && cursor.isNotEmpty);
    return customers;
  }

  Future<List<Customer>> fetchCustomers({
    String? search,
    String? status = 'active',
    String? walletStatus,
    int limit = 200,
  }) {
    return _customerApi.fetchCustomers(
      search: search,
      status: status,
      walletStatus: walletStatus,
      limit: limit,
    );
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
  }) async {
    return _customerApi.createCustomer(
      fullName: fullName,
      phone: phone,
      companyName: companyName,
      address: address,
      email: email,
      password: password,
      dailyTargetCents: dailyTargetCents,
      creditLimitCents: creditLimitCents,
      idempotencyKey: _uuid.v4(),
    );
  }

  Future<Customer?> getCustomer(String customerId) async {
    try {
      return await _customerApi.fetchCustomer(customerId);
    } catch (error, stackTrace) {
      AppLogger.error('[CustomerRepo] getCustomer failed', error, stackTrace);
      return null;
    }
  }

  Future<List<Customer>> searchCustomers(String query) async {
    try {
      return await _customerApi.fetchCustomers(search: query, status: 'active');
    } catch (error, stackTrace) {
      AppLogger.error(
        '[CustomerRepo] searchCustomers failed',
        error,
        stackTrace,
      );
      return [];
    }
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
  }) {
    return _customerApi.updateCustomer(
      customerId: customerId,
      fullName: fullName,
      phone: phone,
      companyName: companyName,
      address: address,
      email: email,
      dailyTargetCents: dailyTargetCents,
      creditLimitCents: creditLimitCents,
    );
  }

  Future<CustomerStatusCounts> fetchCustomerStatusCounts() {
    return _customerApi.fetchCustomerStatusCounts();
  }

  Future<CustomerGroupListResult> fetchCustomerGroups() {
    return _customerApi.fetchCustomerGroups();
  }

  Future<void> patchCustomerStatus({
    required String customerId,
    required String canonicalStatus,
    String? statusReason,
  }) {
    return _customerApi.patchCustomerStatus(
      customerId: customerId,
      canonicalStatus: canonicalStatus,
      statusReason: statusReason,
    );
  }

  Future<CustomerGroupSummary> createCustomerGroup({
    required String name,
    String? colorHex,
  }) {
    return _customerApi.createCustomerGroup(
      name: name,
      colorHex: colorHex,
      idempotencyKey: _uuid.v4(),
    );
  }

  Future<CustomerGroupSummary> updateCustomerGroup({
    required String groupId,
    required String name,
    String? colorHex,
  }) {
    return _customerApi.updateCustomerGroup(
      groupId: groupId,
      name: name,
      colorHex: colorHex,
    );
  }

  Future<void> assignCustomerGroup({
    required String customerId,
    required String? groupId,
  }) {
    return _customerApi.assignCustomerGroup(
      customerId: customerId,
      groupId: groupId,
    );
  }

  Future<void> saveCustomerMediaAssets({
    required String customerId,
    required Map<CustomerMediaSlot, CustomerMediaAsset> assets,
    String? idempotencyKey,
    String? logicalActionId,
  }) async {
    if (assets.isEmpty) return;
    final mediaFingerprint =
        assets.entries
            .map((e) => '${e.key.firestoreField}:${e.value.publicId}')
            .toList()
          ..sort();
    final actionId =
        logicalActionId ??
        'mediaSave|$customerId|${mediaFingerprint.join(',')}';
    final key = idempotencyKey ?? _idempotencyKeyManager.keyFor(actionId);
    await _mediaApi.saveMedia(
      customerId: customerId,
      assets: assets,
      idempotencyKey: key,
    );
    if (idempotencyKey == null) {
      _idempotencyKeyManager.clear(actionId);
    }
  }

  Future<List<CustomerWallet>> fetchCustomerWallets(String customerId) {
    return _customerApi.fetchCustomerWallets(customerId);
  }

  Future<CustomerWallet> createSecondaryWallet({
    required String customerId,
    required String displayName,
    String? code,
    required int dailyTargetCents,
    int creditLimitCents = 0,
  }) {
    return _customerApi.createSecondaryWallet(
      customerId: customerId,
      displayName: displayName,
      code: code,
      dailyTargetCents: dailyTargetCents,
      creditLimitCents: creditLimitCents,
      idempotencyKey: _uuid.v4(),
    );
  }

  Future<void> resetCustomerPassword({
    required String customerId,
    required String newPassword,
  }) {
    return _customerApi.resetCustomerPassword(
      customerId: customerId,
      newPassword: newPassword,
    );
  }
}
