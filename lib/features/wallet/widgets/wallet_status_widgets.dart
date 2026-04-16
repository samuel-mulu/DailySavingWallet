import 'package:flutter/material.dart';

import '../wallet_status_utils.dart';

class WalletStatusPill extends StatelessWidget {
  const WalletStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = walletStatusColor(status, cs);
    return Tooltip(
      message: walletStatusTooltip(status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withValues(alpha: 0.35)),
          color: fg.withValues(alpha: 0.1),
        ),
        child: Text(
          walletOperationalLabel(status),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class WalletStatusActionsMenu extends StatelessWidget {
  const WalletStatusActionsMenu({
    super.key,
    required this.status,
    required this.onSelected,
    this.icon = const Icon(Icons.more_horiz),
  });

  final String status;
  final ValueChanged<String> onSelected;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final actions = walletStatusActions(status);
    if (actions.isEmpty) {
      return Tooltip(
        message: 'No status actions for ${walletOperationalLabel(status)} wallet',
        child: Icon(
          Icons.info_outline,
          size: 20,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }

    return PopupMenuButton<String>(
      icon: icon,
      tooltip: walletStatusTooltip(status),
      onSelected: onSelected,
      itemBuilder: (_) => actions
          .map(
            (action) => PopupMenuItem<String>(
              value: action.targetStatus,
              child: Tooltip(
                message: action.tooltip,
                child: Text(action.label),
              ),
            ),
          )
          .toList(),
    );
  }
}
