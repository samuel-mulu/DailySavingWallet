import 'package:flutter/material.dart';

import '../../../../data/customers/customer_model.dart';

class CustomerProfileAvatar extends StatelessWidget {
  const CustomerProfileAvatar({
    super.key,
    required this.customer,
    this.radius = 24,
    this.enablePreview = true,
  });

  final Customer customer;
  final double radius;
  final bool enablePreview;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage:
          customer.media.profilePicture?.secureUrl.isNotEmpty == true
          ? NetworkImage(customer.media.profilePicture!.secureUrl)
          : null,
      child: customer.media.profilePicture?.secureUrl.isNotEmpty == true
          ? null
          : Text(
              customer.fullName.isNotEmpty
                  ? customer.fullName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: radius * 0.9,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
    );

    if (!enablePreview) return avatar;

    return Tooltip(
      message: 'View profile image',
      child: InkResponse(
        onTap: () => showCustomerProfileImageModal(context, customer),
        customBorder: const CircleBorder(),
        radius: radius + 10,
        child: avatar,
      ),
    );
  }
}

Future<void> showCustomerProfileImageModal(
  BuildContext context,
  Customer customer,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final imageUrl = customer.media.profilePicture?.secureUrl;

      return Dialog(
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
                      customer.fullName,
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
                customer.companyName,
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? InteractiveViewer(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              _ProfileImageFallback(customer: customer),
                        ),
                      )
                    : _ProfileImageFallback(customer: customer),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ProfileImageFallback extends StatelessWidget {
  const _ProfileImageFallback({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              customer.fullName.isNotEmpty
                  ? customer.fullName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('No profile image uploaded'),
        ],
      ),
    );
  }
}
