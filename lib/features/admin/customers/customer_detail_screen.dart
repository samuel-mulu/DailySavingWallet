import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/settings/calendar_mode.dart';
import '../../../core/ui/date_selector.dart';
import '../../../data/customers/cloudinary_customer_media_service.dart';
import '../../../data/customers/customer_image_picker_service.dart';
import '../../../data/customers/customer_media.dart';
import '../../../data/customers/customer_model.dart';
import '../../../data/wallet/models.dart';
import '../../data/repository_providers.dart';
import '../../wallet/wallet_providers.dart';
import '../../wallet/wallet_status_utils.dart';
import '../../wallet/widgets/wallet_status_widgets.dart';
import '../../wallet/widgets/transaction_tile.dart';
import '../daily_saving/admin_bulk_daily_saving_sheet.dart';
import 'widgets/customer_profile_avatar.dart';
import 'widgets/customer_media_form_section.dart';
import 'widgets/customer_media_gallery_card.dart';

void _showMoneyActionBlockedSnack(BuildContext context, CustomerWallet wallet) {
  final msg = walletActionBlockedMessage(wallet.status);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  final _imagePickerService = CustomerImagePickerService();
  final _cloudinaryMediaService = CloudinaryCustomerMediaService();
  CalendarModeService? _calendarService;
  String? _selectedWalletId;
  int _recentTxLimit = 5;

  @override
  void initState() {
    super.initState();
    _initCalendarService();
  }

  Future<void> _initCalendarService() async {
    final service = await CalendarModeService.getInstance();
    if (!mounted) return;
    setState(() => _calendarService = service);
  }

  Future<void> _onPullToRefresh() async {
    await _refreshDetailScope();
  }

  Future<void> _refreshDetailScope() async {
    ref.invalidate(customerByIdProvider(widget.customerId));
    await Future.wait([
      ref
          .read(customerWalletsStaleProvider(widget.customerId).notifier)
          .refresh(force: true),
      ref
          .read(
            walletStaleProvider((
              customerId: widget.customerId,
              walletId: _selectedWalletId,
            )).notifier,
          )
          .refresh(force: true),
      ref
          .read(
            recentLedgerStaleProvider((
              customerId: widget.customerId,
              walletId: _selectedWalletId,
            )).notifier,
          )
          .refresh(force: true, limit: _recentTxLimit),
    ]);
    final walletId = _selectedWalletId;
    if (walletId != null && walletId.isNotEmpty) {
      ref.invalidate(
        walletStatusHistoryProvider((
          customerId: widget.customerId,
          walletId: walletId,
        )),
      );
    }
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
        .firstWhere((wallet) => wallet.isPrimary, orElse: () => wallets.first)
        .id;
  }

  CustomerWallet? _findSelectedWallet(
    List<CustomerWallet> wallets,
    String? selectedWalletId,
  ) {
    for (final wallet in wallets) {
      if (wallet.id == selectedWalletId) return wallet;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_calendarService == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final customerAsync = ref.watch(customerByIdProvider(widget.customerId));
    final walletsStale = ref.watch(
      customerWalletsStaleProvider(widget.customerId),
    );
    final wallets = walletsStale.data ?? const <CustomerWallet>[];
    final selectedWalletId = _resolveSelectedWalletId(wallets);
    final selectedWallet = _findSelectedWallet(wallets, selectedWalletId);

    return ValueListenableBuilder<CalendarMode>(
      valueListenable: _calendarService!,
      builder: (context, mode, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Customer Details'),
            actions: [
              IconButton(
                tooltip: 'Add wallet',
                icon: const Icon(Icons.add_card_outlined),
                onPressed: walletsStale.isRefreshing && wallets.isEmpty
                    ? null
                    : () => _showAddWalletModal(context),
              ),
            ],
          ),
          body: customerAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
            data: (customer) {
              if (customer == null) {
                return const Center(child: Text('Customer not found'));
              }

              return RefreshIndicator(
                onRefresh: _onPullToRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Profile Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CustomerProfileAvatar(
                                  customer: customer,
                                  radius: 32,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.fullName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        customer.companyName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.secondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _showEditCustomerModal(
                                        context,
                                        customer,
                                        wallets,
                                        selectedWalletId,
                                      ),
                                  tooltip: 'Edit customer',
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _InfoRow(
                              icon: Icons.phone,
                              label: 'Phone',
                              value: customer.phone,
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              icon: Icons.location_on,
                              label: 'Address',
                              value: customer.address,
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              icon: Icons.savings,
                              label: 'Daily Target',
                              value: MoneyEtb.formatCents(
                                customer.dailyTargetCents,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              icon: Icons.credit_card,
                              label: 'Credit Limit',
                              value: customer.creditLimitCents == 0
                                  ? 'Unlimited'
                                  : MoneyEtb.formatCents(
                                      customer.creditLimitCents,
                                    ),
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              icon: Icons.verified_user_outlined,
                              label: 'Account status',
                              valueChild: _AccountStatusPill(
                                status: customer.status,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomerMediaGalleryCard(
                      media: customer.media,
                      onManage: () => _showManageMediaSheet(context, customer),
                    ),
                    const SizedBox(height: 16),

                    // Wallet Balance Card
                    Consumer(
                      builder: (context, ref, _) {
                        final key = (
                          customerId: widget.customerId,
                          walletId: selectedWalletId,
                        );
                        final stale = ref.watch(walletStaleProvider(key));
                        final wallet = stale.data;
                        if (wallet == null) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: stale.error != null
                                  ? Text('Error: ${stale.error}')
                                  : const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                            ),
                          );
                        }

                        final isNegative = wallet.balanceCents < 0;

                        return Card(
                          color: isNegative
                              ? Theme.of(context).colorScheme.errorContainer
                              : Theme.of(context).colorScheme.primaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (wallets.length > 1) ...[
                                  DropdownButtonFormField<String>(
                                    initialValue:
                                        selectedWalletId != null &&
                                            wallets.any(
                                              (w) => w.id == selectedWalletId,
                                            )
                                        ? selectedWalletId
                                        : wallets.first.id,
                                    decoration: const InputDecoration(
                                      labelText: 'Account',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    items: wallets
                                        .map(
                                          (w) => DropdownMenuItem(
                                            value: w.id,
                                            child: Text(
                                              '${w.label} • Target ${MoneyEtb.formatCents(w.dailyTargetCents)}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() => _selectedWalletId = v);
                                    _recentTxLimit = 5;
                                      ref
                                          .read(
                                            walletStaleProvider((
                                              customerId: widget.customerId,
                                              walletId: v,
                                            )).notifier,
                                          )
                                          .refresh(force: true);
                                      ref
                                          .read(
                                            recentLedgerStaleProvider((
                                              customerId: widget.customerId,
                                              walletId: v,
                                            )).notifier,
                                          )
                                          .refresh(
                                            force: true,
                                            limit: _recentTxLimit,
                                          );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Wallet Balance',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: isNegative
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .onErrorContainer
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .onPrimaryContainer,
                                            ),
                                      ),
                                    ),
                                    WalletStatusPill(status: wallet.status),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  MoneyEtb.formatCents(wallet.balanceCents),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isNegative
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onErrorContainer
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                      ),
                                ),
                                if (isNegative) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Customer has debt',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    if (selectedWalletId != null)
                      Consumer(
                        builder: (context, ref, _) {
                          final historyAsync = ref.watch(
                            walletStatusHistoryProvider((
                              customerId: widget.customerId,
                              walletId: selectedWalletId,
                            )),
                          );
                          if (historyAsync.hasError) {
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Could not load wallet health: ${historyAsync.error}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            );
                          }
                          if (!historyAsync.hasValue) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                            );
                          }
                          final data = historyAsync.requireValue;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Wallet Health',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _HealthBadge(
                                        label: 'Freeze',
                                        count: data.health.freezeCount,
                                      ),
                                      _HealthBadge(
                                        label: 'Close',
                                        count: data.health.closeCount,
                                      ),
                                      _HealthBadge(
                                        label: 'Reactivate',
                                        count: data.health.reactivateCount,
                                      ),
                                    ],
                                  ),
                                  if (data.health.latestReason != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Latest reason: ${data.health.latestReason}',
                                    ),
                                  ],
                                  if (data.events.isNotEmpty) ...[
                                    const Divider(height: 20),
                                    ...data.events
                                        .take(5)
                                        .map(
                                          (e) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            child: Text(
                                              '${e.fromStatus} -> ${e.toStatus} • ${e.reason}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ),
                                        ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.lock_reset),
                        title: const Text('Reset Customer Password'),
                        subtitle: const Text(
                          'Set a new password and force re-login on all devices',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showResetPasswordModal(context, customer),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: selectedWallet == null
                                ? null
                                : () {
                                    final w = selectedWallet!;
                                    if (!walletAllowsMoneyMovement(w.status)) {
                                      _showMoneyActionBlockedSnack(context, w);
                                      return;
                                    }
                                    _showRecordPayment(
                                      context,
                                      customer,
                                      w,
                                      'DAILY_PAYMENT',
                                    );
                                  },
                            icon: const Icon(Icons.savings),
                            label: const Text('Daily Saving'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: selectedWallet == null
                                ? null
                                : () {
                                    final w = selectedWallet!;
                                    if (!walletAllowsMoneyMovement(w.status)) {
                                      _showMoneyActionBlockedSnack(context, w);
                                      return;
                                    }
                                    _showRecordPayment(
                                      context,
                                      customer,
                                      w,
                                      'DEPOSIT',
                                    );
                                  },
                            icon: const Icon(Icons.add_circle),
                            label: const Text('Deposit'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: selectedWallet == null
                            ? null
                            : () {
                                final w = selectedWallet!;
                                if (!walletAllowsMoneyMovement(w.status)) {
                                  _showMoneyActionBlockedSnack(context, w);
                                  return;
                                }
                                _showRequestWithdraw(context, customer, w);
                              },
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Request Withdraw'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Transaction History
                    Text(
                      'Recent Transactions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final stale = ref.watch(
                          recentLedgerStaleProvider((
                            customerId: widget.customerId,
                            walletId: selectedWalletId,
                          )),
                        );
                        if (stale.error != null &&
                            (stale.data == null || stale.data!.isEmpty)) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Error: ${stale.error}'),
                            ),
                          );
                        }
                        if (stale.data == null && stale.isRefreshing) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          );
                        }

                        final txs = stale.data ?? const <LedgerTx>[];
                        if (txs.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: Text('No transactions yet')),
                            ),
                          );
                        }

                        return Card(
                          child: Column(
                            children: txs
                                .map(
                                  (tx) => TransactionTile(
                                    tx: tx,
                                    calendarMode: mode,
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final stale = ref.watch(
                          recentLedgerStaleProvider((
                            customerId: widget.customerId,
                            walletId: selectedWalletId,
                          )),
                        );
                        final txs = stale.data ?? const <LedgerTx>[];
                        if (txs.length < _recentTxLimit || stale.isRefreshing) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () async {
                                setState(() => _recentTxLimit += 5);
                                await ref
                                    .read(
                                      recentLedgerStaleProvider((
                                        customerId: widget.customerId,
                                        walletId: selectedWalletId,
                                      )).notifier,
                                    )
                                    .refresh(force: true, limit: _recentTxLimit);
                              },
                              icon: const Icon(Icons.expand_more_rounded),
                              label: const Text('Load more transactions'),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showManageMediaSheet(
    BuildContext context,
    Customer customer,
  ) async {
    final selectedImages = <CustomerMediaSlot, SelectedCustomerImage>{};
    String? mediaError;
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> pickImage(CustomerMediaSlot slot) async {
              try {
                final selected = await _imagePickerService.pickImageFromGallery(
                  slot,
                );
                if (selected == null) return;
                setSheetState(() {
                  selectedImages[slot] = selected;
                  mediaError = null;
                });
              } on FormatException catch (e) {
                setSheetState(() => mediaError = e.message);
              } catch (e) {
                setSheetState(() => mediaError = 'Could not select image: $e');
              }
            }

            Future<void> saveMedia() async {
              if (selectedImages.isEmpty) {
                Navigator.of(sheetContext).pop();
                return;
              }

              setSheetState(() {
                isSaving = true;
                mediaError = null;
              });

              try {
                final uploadedAssets =
                    <CustomerMediaSlot, CustomerMediaAsset>{};
                for (final entry in selectedImages.entries) {
                  final asset = await _cloudinaryMediaService.uploadImage(
                    customerId: customer.customerId,
                    image: entry.value,
                  );
                  uploadedAssets[entry.key] = asset;
                }

                await ref
                    .read(customerRepoProvider)
                    .saveCustomerMediaAssets(
                      customerId: customer.customerId,
                      assets: uploadedAssets,
                    );

                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                await _refreshDetailScope();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer images updated')),
                );
              } catch (e) {
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  isSaving = false;
                  mediaError = 'Could not upload image: $e';
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Manage Customer Images',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomerMediaFormSection(
                        selectedImages: selectedImages,
                        savedMedia: customer.media,
                        onPickImage: pickImage,
                        onRemoveImage: (slot) {
                          setSheetState(() => selectedImages.remove(slot));
                        },
                        busy: isSaving,
                        errorText: mediaError,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(sheetContext).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: isSaving ? null : saveMedia,
                              child: isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Save Images'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditCustomerModal(
    BuildContext context,
    Customer customer,
    List<CustomerWallet> wallets,
    String? selectedWalletId,
  ) {
    CustomerWallet? initialWallet;
    for (final wallet in wallets) {
      if (wallet.id == selectedWalletId) {
        initialWallet = wallet;
        break;
      }
    }
    initialWallet ??=
        wallets.isNotEmpty
            ? wallets.firstWhere(
                (wallet) => wallet.isPrimary,
                orElse: () => wallets.first,
              )
            : null;
    final formKey = GlobalKey<FormState>();
    final fullNameCtrl = TextEditingController(text: customer.fullName);
    final companyNameCtrl = TextEditingController(text: customer.companyName);
    final phoneCtrl = TextEditingController(text: customer.phone);
    final addressCtrl = TextEditingController(text: customer.address);
    final editWalletId = ValueNotifier<String?>(initialWallet?.id);
    final dailyTargetCtrl = TextEditingController(
      text: MoneyEtb.formatCents(
        initialWallet?.dailyTargetCents ?? customer.dailyTargetCents,
      ).replaceFirst('ETB ', ''),
    );
    final creditLimitCtrl = TextEditingController(
      text: (initialWallet?.creditLimitCents ?? customer.creditLimitCents) == 0
          ? ''
          : MoneyEtb.formatCents(
              initialWallet?.creditLimitCents ?? customer.creditLimitCents,
            ).replaceFirst('ETB ', ''),
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var isSaving = false;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> submit() async {
              final form = formKey.currentState;
              if (form == null || !form.validate()) return;

              setSheetState(() => isSaving = true);

              try {
                final dailyTargetCents = MoneyEtb.parseEtbToCents(
                  dailyTargetCtrl.text.trim(),
                );
                final creditText = creditLimitCtrl.text.trim();
                final creditLimitCents = creditText.isEmpty
                    ? 0
                    : MoneyEtb.parseEtbToCents(creditText);

                final targetWalletId = editWalletId.value;
                await ref.read(customerRepoProvider).updateCustomer(
                  customerId: customer.customerId,
                  fullName: fullNameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  companyName: companyNameCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  email: customer.email,
                  dailyTargetCents: customer.dailyTargetCents,
                  creditLimitCents: customer.creditLimitCents,
                );
                if (targetWalletId != null && targetWalletId.isNotEmpty) {
                  await ref.read(customerRepoProvider).updateCustomerWalletLimits(
                    customerId: customer.customerId,
                    walletId: targetWalletId,
                    dailyTargetCents: dailyTargetCents,
                    creditLimitCents: creditLimitCents,
                  );
                }

                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                await _refreshDetailScope();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Customer updated successfully'),
                  ),
                );
              } catch (e) {
                if (!sheetContext.mounted) return;
                setSheetState(() => isSaving = false);
                ScaffoldMessenger.of(
                  sheetContext,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Edit Customer',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: fullNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Full name is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: companyNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Company Name',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Company name is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Phone is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        if (wallets.length > 1) ...[
                          ValueListenableBuilder<String?>(
                            valueListenable: editWalletId,
                            builder: (context, selected, _) {
                              return DropdownButtonFormField<String>(
                                initialValue: selected,
                                decoration: const InputDecoration(
                                  labelText: 'Wallet',
                                  border: OutlineInputBorder(),
                                ),
                                items: wallets
                                    .map(
                                      (wallet) => DropdownMenuItem(
                                        value: wallet.id,
                                        child: Text(
                                          wallet.label,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  editWalletId.value = value;
                                  final wallet = wallets.firstWhere(
                                    (w) => w.id == value,
                                    orElse: () => wallets.first,
                                  );
                                  dailyTargetCtrl.text = MoneyEtb.formatCents(
                                    wallet.dailyTargetCents,
                                  ).replaceFirst('ETB ', '');
                                  creditLimitCtrl.text =
                                      wallet.creditLimitCents == 0
                                      ? ''
                                      : MoneyEtb.formatCents(
                                          wallet.creditLimitCents,
                                        ).replaceFirst('ETB ', '');
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: addressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          maxLines: 2,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Address is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: dailyTargetCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Daily Target (ETB)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            try {
                              final parsed = MoneyEtb.parseEtbToCents(
                                value?.trim() ?? '',
                              );
                              if (parsed <= 0) {
                                return 'Daily target must be greater than 0';
                              }
                            } catch (_) {
                              return 'Enter a valid daily target';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: creditLimitCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Credit Limit (ETB)',
                            helperText: 'Leave empty for unlimited',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;
                            try {
                              final parsed = MoneyEtb.parseEtbToCents(text);
                              if (parsed < 0) {
                                return 'Credit limit cannot be negative';
                              }
                            } catch (_) {
                              return 'Enter a valid credit limit';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) {
                            if (!isSaving) submit();
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.of(sheetContext).pop(),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: isSaving ? null : submit,
                                child: isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Save Changes'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showResetPasswordModal(BuildContext context, Customer customer) {
    final formKey = GlobalKey<FormState>();
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var isSaving = false;
        var obscurePassword = true;
        var obscureConfirm = true;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> submit() async {
              final form = formKey.currentState;
              if (form == null || !form.validate()) return;
              setSheetState(() => isSaving = true);
              try {
                await ref
                    .read(customerRepoProvider)
                    .resetCustomerPassword(
                      customerId: customer.customerId,
                      newPassword: passwordCtrl.text,
                    );
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                passwordCtrl.clear();
                confirmCtrl.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Password reset successful. Customer was logged out from all active sessions.',
                    ),
                  ),
                );
              } catch (e) {
                if (!sheetContext.mounted) return;
                setSheetState(() => isSaving = false);
                ScaffoldMessenger.of(
                  sheetContext,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Reset Password',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Customer: ${customer.fullName}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: passwordCtrl,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setSheetState(
                                () => obscurePassword = !obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final v = value ?? "";
                            if (v.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            if (v.length > 128) {
                              return 'Password is too long';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmCtrl,
                          obscureText: obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setSheetState(
                                () => obscureConfirm = !obscureConfirm,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? "") != passwordCtrl.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) {
                            if (!isSaving) submit();
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.of(sheetContext).pop(),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: isSaving ? null : submit,
                                child: isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Reset Password'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddWalletModal(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final creditCtrl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    var busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Add wallet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Reference code (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: targetCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Daily target (ETB)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          try {
                            final c = MoneyEtb.parseEtbToCents(v?.trim() ?? '');
                            if (c <= 0) return 'Must be > 0';
                          } catch (_) {
                            return 'Invalid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: creditCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Credit limit (ETB)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (formKey.currentState?.validate() != true) {
                                  return;
                                }
                                setSheetState(() => busy = true);
                                try {
                                  final targetCents = MoneyEtb.parseEtbToCents(
                                    targetCtrl.text.trim(),
                                  );
                                  final creditText = creditCtrl.text.trim();
                                  final creditCents = creditText.isEmpty
                                      ? 0
                                      : MoneyEtb.parseEtbToCents(creditText);
                                  await ref
                                      .read(customerRepoProvider)
                                      .createSecondaryWallet(
                                        customerId: widget.customerId,
                                        displayName: nameCtrl.text.trim(),
                                        code: codeCtrl.text.trim().isEmpty
                                            ? null
                                            : codeCtrl.text.trim(),
                                        dailyTargetCents: targetCents,
                                        creditLimitCents: creditCents,
                                      );
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop();
                                  await _refreshDetailScope();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Wallet created'),
                                    ),
                                  );
                                } catch (e) {
                                  setSheetState(() => busy = false);
                                  if (!sheetContext.mounted) return;
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(SnackBar(content: Text('$e')));
                                }
                              },
                        child: busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Create'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRecordPayment(
    BuildContext context,
    Customer customer,
    CustomerWallet wallet,
    String type,
  ) {
    if (!walletAllowsMoneyMovement(wallet.status)) {
      _showMoneyActionBlockedSnack(context, wallet);
      return;
    }

    if (type == 'DAILY_PAYMENT') {
      showAdminBulkDailySavingSheet(
        context: context,
        customerId: customer.customerId,
        customerName: customer.fullName,
        wallet: wallet,
        onWalletUpdated: (updated) async {
          if (updated != null) {
            ref
                .read(
                  walletStaleProvider((
                    customerId: customer.customerId,
                    walletId: wallet.id,
                  )).notifier,
                )
                .applyWallet(updated);
          }
          await _refreshDetailScope();
        },
        onRefreshAfterBatch: _refreshDetailScope,
      );
      return;
    }

    final amountCtrl = TextEditingController(
      text: type == 'DAILY_PAYMENT'
          ? MoneyEtb.formatCents(
              wallet.dailyTargetCents,
            ).replaceFirst('ETB ', '')
          : '',
    );
    final noteCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    var paymentMethod = 'CASH';
    DateTime selectedDate = DateTime.now();
    var busy = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            type == 'DAILY_PAYMENT'
                ? 'Record Daily Saving — ${wallet.label}'
                : 'Record Deposit — ${wallet.label}',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date Selector
                DateSelector(
                  selectedDate: selectedDate,
                  onDateChanged: (date) =>
                      setDialogState(() => selectedDate = date),
                  showQuickSelect: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Amount (ETB)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(
                      value: 'MOBILE_BANKING',
                      child: Text('Mobile Banking'),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          setDialogState(() => paymentMethod = value);
                        },
                ),
                if (paymentMethod == 'MOBILE_BANKING') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: bankCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bank (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setDialogState(() => busy = true);

                      try {
                        final cents = MoneyEtb.parseEtbToCents(amountCtrl.text);
                        final note = noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim();
                        final txDateMillis = dateToTxMillis(selectedDate);

                        ref.read(dailyWalletMutationProvider.notifier).clear();
                        await ref
                            .read(dailyWalletMutationProvider.notifier)
                            .submit((
                              customerId: customer.customerId,
                              walletId: wallet.id,
                              amountCents: cents,
                              txDateMillis: txDateMillis,
                              paymentMethod: paymentMethod,
                              bankName: paymentMethod == 'MOBILE_BANKING'
                                  ? (bankCtrl.text.trim().isEmpty
                                        ? null
                                        : bankCtrl.text.trim())
                                  : null,
                              note: note,
                              isDailySaving: type == 'DAILY_PAYMENT',
                            ));
                        final mutation = ref.read(dailyWalletMutationProvider);
                        if (mutation.error != null) {
                          throw mutation.error!;
                        }
                        final updated = mutation.data;

                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        if (!context.mounted) return;
                        if (updated != null) {
                          ref
                              .read(
                                walletStaleProvider((
                                  customerId: customer.customerId,
                                  walletId: wallet.id,
                                )).notifier,
                              )
                              .applyWallet(updated);
                        }
                        await _refreshDetailScope();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment recorded successfully'),
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => busy = false);
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(
                          dialogContext,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
              child: busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestWithdraw(
    BuildContext context,
    Customer customer,
    CustomerWallet wallet,
  ) {
    if (!walletAllowsMoneyMovement(wallet.status)) {
      _showMoneyActionBlockedSnack(context, wallet);
      return;
    }

    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    var busy = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Request Withdraw — ${wallet.label}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount (ETB)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setDialogState(() => busy = true);
                      try {
                        final cents = MoneyEtb.parseEtbToCents(amountCtrl.text);
                        final reason = reasonCtrl.text.trim();

                        if (reason.isEmpty) {
                          throw const FormatException('Reason is required');
                        }

                        await ref
                            .read(walletRepoProvider)
                            .requestWithdrawForCustomer(
                              customerId: customer.customerId,
                              walletId: wallet.id,
                              amountCents: cents,
                              reason: reason,
                            );

                        await _refreshDetailScope();
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Withdraw request created'),
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => busy = false);
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(
                          dialogContext,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
              child: busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueChild;

  const _InfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueChild,
  }) : assert(
         value != null || valueChild != null,
         'Provide value or valueChild',
       );

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (valueChild != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: valueChild!,
                )
              else
                Text(
                  value!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountStatusPill extends StatelessWidget {
  const _AccountStatusPill({required this.status});

  final String status;

  Color _color(ColorScheme cs) {
    switch (status) {
      case CustomerLifecycleStatus.active:
        return Colors.green.shade700;
      case CustomerLifecycleStatus.onHold:
        return Colors.amber.shade900;
      case CustomerLifecycleStatus.frozen:
        return Colors.orange.shade900;
      case CustomerLifecycleStatus.deactive:
        return cs.error;
      default:
        return cs.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = _color(cs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
        color: fg.withValues(alpha: 0.08),
      ),
      child: Text(
        CustomerLifecycleStatus.displayLabel(status),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text('$label: $count'),
    );
  }
}
