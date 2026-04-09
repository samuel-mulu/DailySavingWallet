import '../customers/customer_media.dart';
import 'api_client.dart';

class MediaApi {
  final ApiClient _client;

  MediaApi({ApiClient? client}) : _client = client ?? ApiClient();

  Future<SignedCustomerMediaUpload> signUpload({
    required String customerId,
    required CustomerMediaSlot slot,
  }) async {
    final data = await _client.postJson(
      '/media/sign-upload',
      body: {'customerId': customerId, 'slot': slot.firestoreField},
    );
    return SignedCustomerMediaUpload.fromMap(data);
  }

  Future<void> saveMedia({
    required String customerId,
    required Map<CustomerMediaSlot, CustomerMediaAsset> assets,
    required String idempotencyKey,
  }) async {
    await _client.postJson(
      '/media/save',
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      body: {
        'customerId': customerId,
        'media': {
          for (final entry in assets.entries)
            entry.key.firestoreField: entry.value.toMap(),
        },
      },
    );
  }
}
