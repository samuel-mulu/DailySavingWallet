import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/routes.dart';
import '../../../core/money/money.dart';
import '../../../core/settings/calendar_mode.dart';
import '../../../core/ui/app_header.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/error_state.dart';
import '../../../core/ui/skeleton_box.dart';
import '../../../data/wallet/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../../data/server_state_refresh.dart';
import '../../wallet/wallet_providers.dart';
import '../../wallet/wallet_status_utils.dart';
import '../../wallet/widgets/transaction_tile.dart';
import '../../wallet/withdraw_request_screen.dart';

class CustomerHomeTab extends ConsumerStatefulWidget {
  const CustomerHomeTab({super.key});

  @override
  ConsumerState<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

class _CustomerHomeTabState extends ConsumerState<CustomerHomeTab> {
  CalendarModeService? _calendarService;
  String? _selectedWalletId;
  bool _logoutLoading = false;

  Future<void> _logout() async {
    if (_logoutLoading) return;
    setState(() => _logoutLoading = true);
    try {
      await ref.read(authClientProvider).signOut();
      if (mounted) {
        AppRoutes.goToAuthGate(context);
      }
    } finally {
      if (mounted) setState(() => _logoutLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _initCalendarService();
  }

  Future<void> _initCalendarService() async {
    final service = await CalendarModeService.getInstance();
    if (mounted) setState(() => _calendarService = service);
  }

  Future<void> _onRefresh(
    String customerId, {
    required String? walletId,
  }) async {
    await refreshCustomerWalletReadScope(
      ref,
      customerId: customerId,
      walletId: walletId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authUidProvider).valueOrNull;
    if (uid == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_calendarService == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final profileAsync = ref.watch(appUserProfileProvider(uid));

    return ValueListenableBuilder<CalendarMode>(
      valueListenable: _calendarService!,
      builder: (context, mode, _) {
        return profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load profile: $e'),
            ),
          ),
          data: (profile) {
            final accountBlocked = profile.status != 'active';
            final customerId = profile.customerId;
            if (customerId == null || customerId.isEmpty) {
              return Column(
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final name =
                          ref.watch(accountDisplayLabelProvider).valueOrNull ??
                          'User';
                      return AppHeader(
                        title: 'My Wallet',
                        subtitle: 'Welcome back',
                        userName: name,
                        onLogout: _logout,
                        logoutLoading: _logoutLoading,
                      );
                    },
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.link_off_rounded,
                                size: 40,
                                color: Color(0xFFC62828),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Profile Not Linked',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please contact your administrator to link your account.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFF6B7280),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final walletsStale = ref.watch(
              customerWalletsStaleProvider(customerId),
            );
            final wallets = walletsStale.data ?? const <CustomerWallet>[];
            final selectedWalletId = _resolveSelectedWalletId(wallets);

            return Column(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final name =
                        ref.watch(accountDisplayLabelProvider).valueOrNull ??
                        'User';
                    return AppHeader(
                      title: 'My Wallet',
                      subtitle: 'Welcome back',
                      userName: name,
                      onLogout: _logout,
                      logoutLoading: _logoutLoading,
                    );
                  },
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF8B5CF6),
                    onRefresh: () =>
                        _onRefresh(customerId, walletId: selectedWalletId),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        const SizedBox(height: 16),
                        BalanceCard(
                          customerId: customerId,
                          walletId: selectedWalletId,
                          wallets: wallets,
                          onWalletChanged: (walletId) async {
                            setState(() => _selectedWalletId = walletId);
                            await _onRefresh(customerId, walletId: walletId);
                          },
                        ),
                        if (accountBlocked ||
                            _isSelectedWalletBlocked(
                              wallets,
                              selectedWalletId,
                            )) ...[
                          const SizedBox(height: 12),
                          _StatusBlockBanner(
                            message: accountBlocked
                                ? 'Your account is deactivated. Please contact your administrator.'
                                : 'This wallet is frozen/closed. Operations are blocked. Please contact your administrator.',
                            isHardBlock: accountBlocked,
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D2D2D),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.request_page_rounded,
                                label: 'Request\nWithdraw',
                                color: const Color(0xFF8B5CF6),
                                onTap:
                                    (accountBlocked ||
                                        _isSelectedWalletBlocked(
                                          wallets,
                                          selectedWalletId,
                                        ))
                                    ? () {}
                                    : () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                WithdrawRequestScreen(
                                                  customerId: customerId,
                                                  walletId: selectedWalletId,
                                                ),
                                          ),
                                        );
                                        if (!context.mounted) return;
                                        await _onRefresh(
                                          customerId,
                                          walletId: selectedWalletId,
                                        );
                                      },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.history_rounded,
                                label: 'View\nHistory',
                                color: const Color(0xFF10B981),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Go to History tab'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Transactions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2D2D2D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _RecentLedgerSection(
                          customerId: customerId,
                          walletId: selectedWalletId,
                          calendarMode: mode,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String? _resolveSelectedWalletId(List<CustomerWallet> wallets) {
    final selectedWalletId = _selectedWalletId;
    if (selectedWalletId != null &&
        wallets.any((wallet) => wallet.id == selectedWalletId)) {
      return selectedWalletId;
    }
    if (wallets.isEmpty) {
      return null;
    }
    return wallets
        .firstWhere((w) => w.isPrimary, orElse: () => wallets.first)
        .id;
  }

  bool _isSelectedWalletBlocked(
    List<CustomerWallet> wallets,
    String? selectedWalletId,
  ) {
    for (final w in wallets) {
      if (w.id == selectedWalletId) {
        return !walletAllowsMoneyMovement(w.status);
      }
    }
    return false;
  }
}

class _RecentLedgerSection extends ConsumerWidget {
  final String customerId;
  final String? walletId;
  final CalendarMode calendarMode;

  const _RecentLedgerSection({
    required this.customerId,
    required this.walletId,
    required this.calendarMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stale = ref.watch(
      recentLedgerStaleProvider((customerId: customerId, walletId: walletId)),
    );

    if (stale.data == null && stale.isRefreshing) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            SkeletonBox(width: double.infinity, height: 56, radius: 14),
            SizedBox(height: 10),
            SkeletonBox(width: double.infinity, height: 56, radius: 14),
          ],
        ),
      );
    }

    if (stale.error != null && (stale.data == null || stale.data!.isEmpty)) {
      return ErrorState(
        title: 'Could not load transactions',
        message: stale.error.toString(),
        onRetry: () => ref
            .read(
              recentLedgerStaleProvider((
                customerId: customerId,
                walletId: walletId,
              )).notifier,
            )
            .refresh(force: true),
      );
    }

    final items = stale.data ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stale.isRefreshing && items.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (items.isEmpty && !stale.isRefreshing)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No transactions yet',
            message: 'Your wallet activity will appear here.',
          )
        else
          Card(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (final tx in items)
                  TransactionTile(tx: tx, calendarMode: calendarMode),
              ],
            ),
          ),
      ],
    );
  }
}

class BalanceCard extends ConsumerStatefulWidget {
  final String customerId;
  final String? walletId;
  final List<CustomerWallet> wallets;
  final ValueChanged<String> onWalletChanged;
  const BalanceCard({
    super.key,
    required this.customerId,
    required this.walletId,
    required this.wallets,
    required this.onWalletChanged,
  });

  @override
  ConsumerState<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends ConsumerState<BalanceCard> {
  bool _hideBalance = true;

  Future<void> _showExpandedBalance(int balanceCents) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Wallet Balance'),
        content: SelectableText(
          MoneyEtb.formatCents(balanceCents),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stale = ref.watch(
      walletStaleProvider((
        customerId: widget.customerId,
        walletId: widget.walletId,
      )),
    );
    final wallet = stale.data;
    final balance = wallet?.balanceCents ?? 0;
    final isNegative = balance < 0;

    final baseColor = isNegative
        ? const Color(0xFFEF5350)
        : const Color(0xFF0EA5E9);
    final accentColor = isNegative
        ? const Color(0xFFE57373)
        : const Color(0xFF2DD4BF);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [baseColor, accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              top: -20,
              right: -20,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white.withOpacity(0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isNegative
                              ? 'OUTSTANDING BALANCE'
                              : 'AVAILABLE BALANCE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      if (widget.wallets.length > 1) ...[
                        const SizedBox(width: 8),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: widget.walletId,
                            dropdownColor: Colors.white,
                            hint: const Text('Account'),
                            onChanged: (v) {
                              if (v == null) return;
                              widget.onWalletChanged(v);
                            },
                            items: widget.wallets
                                .map(
                                  (w) => DropdownMenuItem(
                                    value: w.id,
                                    child: Text(
                                      w.displayName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      IconButton(
                        tooltip: 'Refresh balance',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: stale.isRefreshing
                            ? null
                            : () => ref
                                  .read(
                                    walletStaleProvider((
                                      customerId: widget.customerId,
                                      walletId: widget.walletId,
                                    )).notifier,
                                  )
                                  .refresh(force: true),
                        icon: stale.isRefreshing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              )
                            : Icon(
                                Icons.sync_rounded,
                                color: Colors.white.withOpacity(0.9),
                                size: 22,
                              ),
                      ),
                    ],
                  ),
                  if (stale.isRefreshing && wallet != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (stale.data == null && stale.isRefreshing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  else if (stale.error != null && stale.data == null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        stale.error.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 24,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: _hideBalance
                                          ? null
                                          : () => _showExpandedBalance(balance),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          _hideBalance
                                              ? '••••••'
                                              : MoneyEtb.formatCents(
                                                  balance,
                                                ).replaceAll('ETB ', ''),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 40,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    tooltip: _hideBalance
                                        ? 'Show balance'
                                        : 'Hide balance',
                                    onPressed: () => setState(
                                      () => _hideBalance = !_hideBalance,
                                    ),
                                    icon: Icon(
                                      _hideBalance
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 24,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D2D2D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBlockBanner extends StatelessWidget {
  const _StatusBlockBanner({required this.message, required this.isHardBlock});
  final String message;
  final bool isHardBlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHardBlock ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHardBlock ? Colors.red.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isHardBlock ? Icons.block : Icons.warning_amber_rounded,
            color: isHardBlock ? Colors.red.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
