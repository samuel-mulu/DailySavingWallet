import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/idempotency/idempotency_key_manager.dart';
import 'package:flutter_application_1/data/api/customer_api.dart';
import 'package:flutter_application_1/data/api/media_api.dart';
import 'package:flutter_application_1/data/customers/customer_media.dart';
import 'package:flutter_application_1/data/customers/customer_repo.dart';

class _FakeMediaApi extends MediaApi {
  bool failSave = false;
  final List<String> saveKeys = <String>[];

  @override
  Future<void> saveMedia({
    required String customerId,
    required Map<CustomerMediaSlot, CustomerMediaAsset> assets,
    required String idempotencyKey,
  }) async {
    saveKeys.add(idempotencyKey);
    if (failSave) {
      throw Exception('temporary upload failure');
    }
  }
}

void main() {
  group('CustomerRepo media save idempotency', () {
    test('failed retry keeps same key and success clears key', () async {
      final keyManager = IdempotencyKeyManager();
      final mediaApi = _FakeMediaApi()..failSave = true;
      final repo = CustomerRepo(
        customerApi: CustomerApi(),
        mediaApi: mediaApi,
        idempotencyKeyManager: keyManager,
      );

      final assets = <CustomerMediaSlot, CustomerMediaAsset>{
        CustomerMediaSlot.idFront: const CustomerMediaAsset(
          publicId: 'asset-front',
          secureUrl: 'https://cdn.example/front',
          assetType: 'image',
          resourceType: 'image',
          uploadedAt: null,
        ),
      };

      await expectLater(
        () => repo.saveCustomerMediaAssets(
          customerId: 'c1',
          assets: assets,
          logicalActionId: 'media-save-c1',
        ),
        throwsException,
      );
      final firstKey = mediaApi.saveKeys.single;
      expect(keyManager.peek('media-save-c1'), firstKey);

      mediaApi.failSave = false;
      await repo.saveCustomerMediaAssets(
        customerId: 'c1',
        assets: assets,
        logicalActionId: 'media-save-c1',
      );

      expect(mediaApi.saveKeys[1], firstKey);
      expect(keyManager.peek('media-save-c1'), isNull);
    });
  });
}
