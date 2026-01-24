import 'package:flutter/material.dart';

import '../../../core/money/money.dart';

class BalanceCard extends StatelessWidget {
  final int balanceCents;
  final DateTime? updatedAt;
  final bool loading;
  final bool isFromCache;

  const BalanceCard({
    super.key,
    required this.balanceCents,
    required this.updatedAt,
    this.loading = false,
    this.isFromCache = false,
  });

  @override
  Widget build(BuildContext context) {
    final updated = updatedAt == null
        ? '—'
        : '${updatedAt!.year.toString().padLeft(4, '0')}-${updatedAt!.month.toString().padLeft(2, '0')}-${updatedAt!.day.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Balance', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (isFromCache)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Cached', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (loading)
              Container(
                height: 40,
                width: 220,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
              )
            else
              Text(
                MoneyEtb.formatCents(balanceCents),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            const SizedBox(height: 8),
            Text(
              isFromCache ? 'Waiting to sync… (cached)' : 'Updated: $updated',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

