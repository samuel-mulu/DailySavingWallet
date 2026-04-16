import 'package:flutter/material.dart';

class WalletStatusValues {
  static const String all = 'ALL';
  static const String active = 'ACTIVE';
  static const String frozen = 'FROZEN';
  static const String closed = 'CLOSED';
  static const String unknown = 'UNKNOWN';
  static const List<String> allFilters = [all, active, frozen, closed, unknown];
}

class WalletStatusAction {
  final String targetStatus;
  final String label;
  final String tooltip;

  const WalletStatusAction({
    required this.targetStatus,
    required this.label,
    required this.tooltip,
  });
}

String normalizeWalletStatus(String status) => status.trim().toUpperCase();

bool walletAllowsMoneyMovement(String status) {
  return normalizeWalletStatus(status) == WalletStatusValues.active;
}

String walletOperationalLabel(String status) {
  switch (normalizeWalletStatus(status)) {
    case WalletStatusValues.active:
      return 'Active';
    case WalletStatusValues.frozen:
      return 'Frozen (System)';
    case WalletStatusValues.closed:
      return 'Closed (Admin)';
    case WalletStatusValues.unknown:
      return 'Unknown';
    default:
      return status;
  }
}

String walletStatusChipLabel(String status) {
  switch (normalizeWalletStatus(status)) {
    case WalletStatusValues.all:
      return 'All';
    case WalletStatusValues.active:
      return 'Active';
    case WalletStatusValues.frozen:
      return 'Frozen (System)';
    case WalletStatusValues.closed:
      return 'Closed (Admin)';
    case WalletStatusValues.unknown:
      return 'Unknown';
    default:
      return status;
  }
}

String walletStatusTooltip(String status) {
  switch (normalizeWalletStatus(status)) {
    case WalletStatusValues.active:
      return 'Wallet can record savings, deposits, and withdrawals.';
    case WalletStatusValues.frozen:
      return 'System-frozen due to inactivity; money movement is blocked.';
    case WalletStatusValues.closed:
      return 'Admin-closed wallet; money movement is blocked.';
    case WalletStatusValues.unknown:
      return 'Wallet status is unknown.';
    case WalletStatusValues.all:
      return 'Show all wallets regardless of status.';
    default:
      return 'Wallet status: $status';
  }
}

IconData walletStatusIcon(String status) {
  switch (normalizeWalletStatus(status)) {
    case WalletStatusValues.all:
      return Icons.account_balance_wallet_outlined;
    case WalletStatusValues.active:
      return Icons.check_circle_outline;
    case WalletStatusValues.frozen:
      return Icons.ac_unit;
    case WalletStatusValues.closed:
      return Icons.lock_outline;
    case WalletStatusValues.unknown:
      return Icons.help_outline;
    default:
      return Icons.tune;
  }
}

Color walletStatusColor(String status, ColorScheme colorScheme) {
  switch (normalizeWalletStatus(status)) {
    case WalletStatusValues.active:
      return Colors.green.shade700;
    case WalletStatusValues.frozen:
      return Colors.orange.shade800;
    case WalletStatusValues.closed:
      return Colors.red.shade700;
    case WalletStatusValues.unknown:
      return Colors.blueGrey.shade700;
    default:
      return colorScheme.outline;
  }
}

String walletActionBlockedMessage(String status) {
  if (walletAllowsMoneyMovement(status)) {
    return 'This action is not available.';
  }
  return 'Wallet is ${walletOperationalLabel(status)}. Resolve wallet status before recording money.';
}

List<WalletStatusAction> walletStatusActions(String status) {
  switch (normalizeWalletStatus(status)) {
    case WalletStatusValues.active:
      return const [
        WalletStatusAction(
          targetStatus: WalletStatusValues.closed,
          label: 'Close',
          tooltip: 'Close this wallet and block money movement.',
        ),
      ];
    case WalletStatusValues.frozen:
      return const [
        WalletStatusAction(
          targetStatus: WalletStatusValues.active,
          label: 'Activate',
          tooltip: 'Reactivate this wallet.',
        ),
        WalletStatusAction(
          targetStatus: WalletStatusValues.closed,
          label: 'Close',
          tooltip: 'Close this wallet and keep money movement blocked.',
        ),
      ];
    case WalletStatusValues.closed:
      return const [
        WalletStatusAction(
          targetStatus: WalletStatusValues.active,
          label: 'Reopen',
          tooltip: 'Reopen this wallet for operations.',
        ),
      ];
    default:
      return const [];
  }
}
