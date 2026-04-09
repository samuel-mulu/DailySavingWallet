import 'dart:typed_data';

enum CustomerMediaSlot {
  profilePicture,
  idFront,
  idBack;

  String get firestoreField => switch (this) {
        CustomerMediaSlot.profilePicture => 'profilePicture',
        CustomerMediaSlot.idFront => 'idFront',
        CustomerMediaSlot.idBack => 'idBack',
      };

  String get label => switch (this) {
        CustomerMediaSlot.profilePicture => 'Profile Picture',
        CustomerMediaSlot.idFront => 'ID/Passport Front',
        CustomerMediaSlot.idBack => 'ID/Passport Back (Optional)',
      };
}

class CustomerMediaAsset {
  final String secureUrl;
  final String publicId;
  final String assetType;
  final String resourceType;
  final DateTime? uploadedAt;

  const CustomerMediaAsset({
    required this.secureUrl,
    required this.publicId,
    required this.assetType,
    required this.resourceType,
    required this.uploadedAt,
  });

  factory CustomerMediaAsset.fromMap(Map<String, dynamic> map) {
    return CustomerMediaAsset(
      secureUrl: (map['secureUrl'] as String?) ?? '',
      publicId: (map['publicId'] as String?) ?? '',
      assetType: (map['assetType'] as String?) ?? 'image',
      resourceType: (map['resourceType'] as String?) ?? 'image',
      uploadedAt: DateTime.tryParse((map['uploadedAt'] as String?) ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'secureUrl': secureUrl,
      'publicId': publicId,
      'assetType': assetType,
      'resourceType': resourceType,
      'uploadedAt': uploadedAt?.toUtc().toIso8601String(),
    };
  }

  bool get isReady => secureUrl.isNotEmpty && publicId.isNotEmpty;
}

class CustomerMedia {
  final CustomerMediaAsset? profilePicture;
  final CustomerMediaAsset? idFront;
  final CustomerMediaAsset? idBack;

  const CustomerMedia({
    this.profilePicture,
    this.idFront,
    this.idBack,
  });

  factory CustomerMedia.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const CustomerMedia();

    CustomerMediaAsset? parseAsset(String key) {
      final raw = map[key];
      if (raw is! Map) return null;
      final asset = CustomerMediaAsset.fromMap(
        raw.map((assetKey, value) => MapEntry('$assetKey', value)),
      );
      return asset.isReady ? asset : null;
    }

    return CustomerMedia(
      profilePicture: parseAsset('profilePicture'),
      idFront: parseAsset('idFront'),
      idBack: parseAsset('idBack'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (profilePicture != null) 'profilePicture': profilePicture!.toMap(),
      if (idFront != null) 'idFront': idFront!.toMap(),
      if (idBack != null) 'idBack': idBack!.toMap(),
    };
  }

  CustomerMediaAsset? assetFor(CustomerMediaSlot slot) {
    return switch (slot) {
      CustomerMediaSlot.profilePicture => profilePicture,
      CustomerMediaSlot.idFront => idFront,
      CustomerMediaSlot.idBack => idBack,
    };
  }
}

class SelectedCustomerImage {
  final CustomerMediaSlot slot;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  const SelectedCustomerImage({
    required this.slot,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  int get sizeBytes => bytes.lengthInBytes;
}

class SignedCustomerMediaUpload {
  final String cloudName;
  final String apiKey;
  final String signature;
  final int timestamp;
  final String folder;
  final String publicId;
  final bool overwrite;

  const SignedCustomerMediaUpload({
    required this.cloudName,
    required this.apiKey,
    required this.signature,
    required this.timestamp,
    required this.folder,
    required this.publicId,
    required this.overwrite,
  });

  factory SignedCustomerMediaUpload.fromMap(Map<String, dynamic> map) {
    return SignedCustomerMediaUpload(
      cloudName: (map['cloudName'] as String?) ?? '',
      apiKey: (map['apiKey'] as String?) ?? '',
      signature: (map['signature'] as String?) ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      folder: (map['folder'] as String?) ?? '',
      publicId: (map['publicId'] as String?) ?? '',
      overwrite: (map['overwrite'] as bool?) ?? true,
    );
  }

  Uri get uploadUri =>
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
}
