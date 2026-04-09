import 'package:flutter/material.dart';

import '../../../../data/customers/customer_media.dart';

class CustomerMediaFormSection extends StatelessWidget {
  const CustomerMediaFormSection({
    super.key,
    required this.selectedImages,
    this.savedMedia,
    this.onPickImage,
    this.onRemoveImage,
    this.busy = false,
    this.errorText,
  });

  final Map<CustomerMediaSlot, SelectedCustomerImage> selectedImages;
  final CustomerMedia? savedMedia;
  final ValueChanged<CustomerMediaSlot>? onPickImage;
  final ValueChanged<CustomerMediaSlot>? onRemoveImage;
  final bool busy;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Images',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload JPG, PNG, or WEBP images up to 5 MB. The back image is optional.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            for (final slot in CustomerMediaSlot.values) ...[
              _CustomerMediaInputTile(
                slot: slot,
                selectedImage: selectedImages[slot],
                savedAsset: savedMedia?.assetFor(slot),
                busy: busy,
                onPickImage: onPickImage,
                onRemoveImage: onRemoveImage,
              ),
              if (slot != CustomerMediaSlot.values.last)
                const SizedBox(height: 12),
            ],
            if (errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomerMediaInputTile extends StatelessWidget {
  const _CustomerMediaInputTile({
    required this.slot,
    required this.selectedImage,
    required this.savedAsset,
    required this.busy,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  final CustomerMediaSlot slot;
  final SelectedCustomerImage? selectedImage;
  final CustomerMediaAsset? savedAsset;
  final bool busy;
  final ValueChanged<CustomerMediaSlot>? onPickImage;
  final ValueChanged<CustomerMediaSlot>? onRemoveImage;

  @override
  Widget build(BuildContext context) {
    final preview =
        selectedImage != null
            ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                selectedImage!.bytes,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 160,
              ),
            )
            : savedAsset?.secureUrl.isNotEmpty == true
            ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                savedAsset!.secureUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 160,
                errorBuilder: (_, _, _) => const _MediaPlaceholder(),
              ),
            )
            : const _MediaPlaceholder();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slot.label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          preview,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => onPickImage?.call(slot),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(selectedImage == null ? 'Choose Image' : 'Replace'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton.icon(
                  onPressed:
                      busy || selectedImage == null
                          ? null
                          : () => onRemoveImage?.call(slot),
                  icon: const Icon(Icons.close),
                  label: const Text('Clear'),
                ),
              ),
            ],
          ),
          if (selectedImage != null) ...[
            const SizedBox(height: 4),
            Text(
              '${selectedImage!.fileName} - ${(selectedImage!.sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (savedAsset != null) ...[
            const SizedBox(height: 4),
            Text(
              'Current image saved in Cloudinary.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
