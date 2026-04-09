import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api/media_api.dart';
import 'customer_media.dart';

class CloudinaryCustomerMediaService {
  CloudinaryCustomerMediaService({
    MediaApi? mediaApi,
    http.Client? httpClient,
  }) : _mediaApi = mediaApi ?? MediaApi(),
       _httpClient = httpClient ?? http.Client();

  final MediaApi _mediaApi;
  final http.Client _httpClient;

  Future<SignedCustomerMediaUpload> createSignedUpload({
    required String customerId,
    required CustomerMediaSlot slot,
  }) async {
    return _mediaApi.signUpload(customerId: customerId, slot: slot);
  }

  Future<CustomerMediaAsset> uploadImage({
    required String customerId,
    required SelectedCustomerImage image,
  }) async {
    final signedUpload = await createSignedUpload(
      customerId: customerId,
      slot: image.slot,
    );

    final request = http.MultipartRequest('POST', signedUpload.uploadUri)
      ..fields['api_key'] = signedUpload.apiKey
      ..fields['timestamp'] = '${signedUpload.timestamp}'
      ..fields['signature'] = signedUpload.signature
      ..fields['folder'] = signedUpload.folder
      ..fields['public_id'] = signedUpload.publicId
      ..fields['overwrite'] = signedUpload.overwrite ? 'true' : 'false'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          image.bytes,
          filename: image.fileName,
        ),
      );

    final streamedResponse = await _httpClient.send(request);
    final responseBody = await streamedResponse.stream.bytesToString();
    final jsonBody = responseBody.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(responseBody) as Map<String, dynamic>;

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      final error = jsonBody['error'];
      final message = error is Map<String, dynamic>
          ? (error['message'] as String?) ?? 'Upload failed.'
          : 'Upload failed.';
      throw Exception(message);
    }

    return CustomerMediaAsset(
      secureUrl: (jsonBody['secure_url'] as String?) ?? '',
      publicId: (jsonBody['public_id'] as String?) ?? '',
      assetType: (jsonBody['asset_type'] as String?) ?? 'image',
      resourceType: (jsonBody['resource_type'] as String?) ?? 'image',
      uploadedAt: DateTime.tryParse((jsonBody['created_at'] as String?) ?? ''),
    );
  }
}
