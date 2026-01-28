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

    final isNegative = balanceCents < 0;
    final gradientColors = isNegative
        ? [const Color(0xFFD32F2F), const Color(0xFFF57C00)] // Red to amber for debt
        : [const Color(0xFF1565C0), const Color(0xFF00897B)]; // Blue to teal for positive

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isNegative ? 'Balance (DEBT)' : 'Balance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  if (isFromCache)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Cached',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (loading)
                Container(
                  height: 48,
                  width: 220,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                )
              else
                Text(
                  MoneyEtb.formatCents(balanceCents),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isNegative ? Icons.warning_rounded : Icons.account_balance_wallet,
                    color: Colors.white.withOpacity(0.8),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isFromCache ? 'Waiting to sync… (cached)' : 'Updated: $updated',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

