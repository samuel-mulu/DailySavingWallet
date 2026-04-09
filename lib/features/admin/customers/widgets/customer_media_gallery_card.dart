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
              _SavedMediaRow(
                label: slot.label,
                asset: media.assetFor(slot),
              ),
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
  const _SavedMediaRow({
    required this.label,
    required this.asset,
  });

  final String label;
  final CustomerMediaAsset? asset;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: asset?.secureUrl.isNotEmpty == true
              ? Image.network(
                  asset!.secureUrl,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(context),
                )
              : _fallback(context),
        ),
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
                asset?.secureUrl.isNotEmpty == true
                    ? asset!.secureUrl
                    : 'No image uploaded yet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
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
