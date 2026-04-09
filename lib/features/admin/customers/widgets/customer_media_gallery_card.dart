import 'package:flutter/material.dart';

import '../../../../data/customers/customer_media.dart';

class CustomerMediaGalleryCard extends StatelessWidget {
  const CustomerMediaGalleryCard({
    super.key,
    required this.media,
    this.onManage,
  });

  final CustomerMedia media;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Customer Images',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onManage,
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final slot in CustomerMediaSlot.values) ...[
              _SavedMediaRow(label: slot.label, asset: media.assetFor(slot)),
              if (slot != CustomerMediaSlot.values.last)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _SavedMediaRow extends StatelessWidget {
  const _SavedMediaRow({required this.label, required this.asset});

  final String label;
  final CustomerMediaAsset? asset;

  @override
  Widget build(BuildContext context) {
    final hasImage = asset?.secureUrl.isNotEmpty == true;
    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: hasImage
          ? Image.network(
              asset!.secureUrl,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(context),
            )
          : _fallback(context),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasImage
            ? () => showCustomerMediaImageModal(
                context,
                title: label,
                asset: asset!,
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              preview,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasImage
                          ? 'Tap to expand and inspect the image.'
                          : 'No image uploaded yet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (hasImage) ...[
                      const SizedBox(height: 6),
                      Text(
                        asset!.secureUrl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasImage)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Icon(
                    Icons.open_in_full_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

Future<void> showCustomerMediaImageModal(
  BuildContext context, {
  required String title,
  required CustomerMediaAsset asset,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final uploadedAt = asset.uploadedAt;
      final uploadedLabel = uploadedAt == null
          ? 'Unknown upload date'
          : MaterialLocalizations.of(
              dialogContext,
            ).formatMediumDate(uploadedAt);

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(dialogContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                uploadedLabel,
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  child: Image.network(
                    asset.secureUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      height: 280,
                      color: Theme.of(
                        dialogContext,
                      ).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Text('Could not load image'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
