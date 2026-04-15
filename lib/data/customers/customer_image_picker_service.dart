import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import 'customer_media.dart';

class CustomerImagePickerService {
  CustomerImagePickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  static const int maxImageBytes = 5 * 1024 * 1024;
  static const Set<String> allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  final ImagePicker _picker;

  Future<SelectedCustomerImage?> pickImageFromGallery(CustomerMediaSlot slot) {
    return _pickImage(slot, ImageSource.gallery);
  }

  Future<SelectedCustomerImage?> captureFromCamera(CustomerMediaSlot slot) {
    return _pickImage(slot, ImageSource.camera);
  }

  Future<SelectedCustomerImage?> _pickImage(
    CustomerMediaSlot slot,
    ImageSource source,
  ) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('Selected image is empty.');
    }
    if (bytes.lengthInBytes > maxImageBytes) {
      throw const FormatException('Image must be 5 MB or smaller.');
    }

    final mimeType =
        lookupMimeType(file.name, headerBytes: bytes) ?? file.mimeType ?? '';
    if (!allowedMimeTypes.contains(mimeType)) {
      throw const FormatException('Only JPG, PNG, and WEBP images are allowed.');
    }

    return SelectedCustomerImage(
      slot: slot,
      fileName: file.name,
      mimeType: mimeType,
      bytes: bytes,
    );
  }
}
