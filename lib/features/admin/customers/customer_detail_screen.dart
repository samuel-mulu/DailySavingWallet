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
import '../../wallet/widgets/transaction_tile.dart';
import '../daily_saving/admin_bulk_daily_saving_sheet.dart';
import 'widgets/customer_profile_avatar.dart';
import 'widgets/customer_media_form_section.dart';
import 'widgets/customer_media_gallery_card.dart';

String _walletOperationalLabel(String status) {
  switch (status.toUpperCase()) {
    case 'ACTIVE':
      return 'Active';
    case 'FROZEN':
      return 'Frozen (System)';
    case 'CLOSED':
      return 'Closed (Admin)';
    case 'UNKNOWN':
      return 'Unknown';
    default:
      return status;
  }
}

bool _walletAllowsMoneyMovement(String walletStatus) {
  return walletStatus.toUpperCase() == 'ACTIVE';
}

void _showMoneyActionBlockedSnack(BuildContext context, CustomerWallet wallet) {
  final msg = _walletAllowsMoneyMovement(wallet.status)
      ? 'This action is not available.'
      : 'Wallet is ${_walletOperationalLabel(wallet.status)}. Resolve wallet status before recording money.';
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
  Future<Customer?>? _customerFuture;
  Future<List<LedgerTx>>? _ledgerFuture;
  List<CustomerWallet> _wallets = const [];
  String? _selectedWalletId;
  bool _walletsLoading = true;

  @override
  void initState() {
    super.initState();
    _initCalendarService();
  }

  Future<void> _initCalendarService() async {
    final service = await CalendarModeService.getInstance();
    if (!mounted) return;
    setState(() {
      _calendarService = service;
      _customerFuture = ref
          .read(customerRepoProvider)
          .getCustomer(widget.customerId);
      _ledgerFuture = ref
          .read(walletRepoProvider)
          .fetchRecentLedger(widget.customerId, limit: 10);
    });
    await _loadWallets();
  }

  Future<void> _loadWallets() async {
    if (mounted) {
      setState(() => _walletsLoading = true);
    }
    try {
      final list = await ref
          .read(customerRepoProvider)
          .fetchCustomerWallets(widget.customerId);
      if (!mounted) return;
      setState(() {
        _wallets = list;
        _walletsLoading = false;
        if (list.isNotEmpty) {
          _selectedWalletId = list
              .firstWhere((w) => w.isPrimary, orElse: () => list.first)
              .id;
        }
      });
      _reloadLedger();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _walletsLoading = false;
        _wallets = const [];
      });
    }
  }

  void _reloadCustomer() {
    setState(() {
      _customerFuture = ref
          .read(customerRepoProvider)
          .getCustomer(widget.customerId);
    });
  }

  void _reloadLedger() {
    setState(() {
      _ledgerFuture = ref
          .read(walletRepoProvider)
          .fetchRecentLedger(
            widget.customerId,
            limit: 10,
            walletId: _selectedWalletId,
          );
    });
  }

  Future<void> _onPullToRefresh() async {
    setState(() {
      _customerFuture = ref
          .read(customerRepoProvider)
          .getCustomer(widget.customerId);
      _ledgerFuture = ref
          .read(walletRepoProvider)
          .fetchRecentLedger(
            widget.customerId,
            limit: 10,
            walletId: _selectedWalletId,
          );
    });
    await ref
        .read(
          walletStaleProvider((
            customerId: widget.customerId,
            walletId: _selectedWalletId,
          )).notifier,
        )
        .refresh(force: true);
    await _loadWallets();
  }

  @override
  Widget build(BuildContext context) {
    if (_calendarService == null ||
        _customerFuture == null ||
        _ledgerFuture == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                onPressed: _walletsLoading
                    ? null
                    : () => _showAddWalletModal(context),
              ),
            ],
          ),
          body: FutureBuilder<Customer?>(
            future: _customerFuture,
            builder: (context, custSnap) {
              if (custSnap.hasError) {
                return Center(child: Text('Error: ${custSnap.error}'));
              }

              if (custSnap.connectionState != ConnectionState.done &&
                  !custSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final customer = custSnap.data;
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
                                      _showEditCustomerModal(context, customer),
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
                          walletId: _selectedWalletId,
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
                                if (_wallets.length > 1) ...[
                                  DropdownButtonFormField<String>(
                                    initialValue:
                                        _selectedWalletId != null &&
                                            _wallets.any(
                                              (w) => w.id == _selectedWalletId,
                                            )
                                        ? _selectedWalletId
                                        : _wallets.first.id,
                                    decoration: const InputDecoration(
                                      labelText: 'Account',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    items: _wallets
                                        .map(
                                          (w) => DropdownMenuItem(
                                            value: w.id,
                                            child: Text(
                                              w.label,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() => _selectedWalletId = v);
                                      ref
                                          .read(
                                            walletStaleProvider((
                                              customerId: widget.customerId,
                                              walletId: v,
                                            )).notifier,
                                          )
                                          .refresh(force: true);
                                      _reloadLedger();
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
                                    _WalletStatusPill(status: wallet.status),
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
                    if (_selectedWalletId != null)
                      FutureBuilder<
                        ({
                          WalletStatusHealth health,
                          List<WalletStatusEvent> events,
                        })
                      >(
                        future: ref
                            .read(walletRepoProvider)
                            .fetchWalletStatusHistory(
                              customerId: widget.customerId,
                              walletId: _selectedWalletId!,
                            ),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Could not load wallet health: ${snap.error}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            );
                          }
                          if (!snap.hasData) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                            );
                          }
                          final data = snap.data!;
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
                            onPressed:
                                _selectedWalletId == null || _wallets.isEmpty
                                ? null
                                : () {
                                    final w = _wallets.firstWhere(
                                      (x) => x.id == _selectedWalletId,
                                    );
                                    if (!_walletAllowsMoneyMovement(w.status)) {
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
                            onPressed:
                                _selectedWalletId == null || _wallets.isEmpty
                                ? null
                                : () {
                                    final w = _wallets.firstWhere(
                                      (x) => x.id == _selectedWalletId,
                                    );
                                    if (!_walletAllowsMoneyMovement(w.status)) {
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
                        onPressed: _selectedWalletId == null || _wallets.isEmpty
                            ? null
                            : () {
                                final w = _wallets.firstWhere(
                                  (x) => x.id == _selectedWalletId,
                                );
                                if (!_walletAllowsMoneyMovement(w.status)) {
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
                    FutureBuilder<List<LedgerTx>>(
                      future: _ledgerFuture,
                      builder: (context, txSnap) {
                        if (txSnap.hasError) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Error: ${txSnap.error}'),
                            ),
                          );
                        }

                        if (!txSnap.hasData) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          );
                        }

                        final txs = txSnap.data!;
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
                final selected = await _imagePickerService.pickImage(slot);
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
                _reloadCustomer();
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

  void _showEditCustomerModal(BuildContext context, Customer customer) {
    final formKey = GlobalKey<FormState>();
    final fullNameCtrl = TextEditingController(text: customer.fullName);
    final companyNameCtrl = TextEditingController(text: customer.companyName);
    final phoneCtrl = TextEditingController(text: customer.phone);
    final addressCtrl = TextEditingController(text: customer.address);
    final dailyTargetCtrl = TextEditingController(
      text: MoneyEtb.formatCents(
        customer.dailyTargetCents,
      ).replaceFirst('ETB ', ''),
    );
    final creditLimitCtrl = TextEditingController(
      text: customer.creditLimitCents == 0
          ? ''
          : MoneyEtb.formatCents(
              customer.creditLimitCents,
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

                await ref
                    .read(customerRepoProvider)
                    .updateCustomer(
                      customerId: customer.customerId,
                      fullName: fullNameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      companyName: companyNameCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      email: customer.email,
                      dailyTargetCents: dailyTargetCents,
                      creditLimitCents: creditLimitCents,
                    );

                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                _reloadCustomer();
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
                                  await _loadWallets();
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
    if (!_walletAllowsMoneyMovement(wallet.status)) {
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
          _reloadLedger();
        },
        onRefreshAfterBatch: _reloadLedger,
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

                        WalletSnapshot? updated;
                        if (type == 'DAILY_PAYMENT') {
                          updated = await ref
                              .read(walletRepoProvider)
                              .recordDailySaving(
                                customerId: customer.customerId,
                                walletId: wallet.id,
                                amountCents: cents,
                                txDateMillis: txDateMillis,
                                note: note,
                              );
                        } else {
                          updated = await ref
                              .read(walletRepoProvider)
                              .recordDeposit(
                                customerId: customer.customerId,
                                walletId: wallet.id,
                                amountCents: cents,
                                txDateMillis: txDateMillis,
                                note: note,
                              );
                        }

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
                        _reloadLedger();
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
    if (!_walletAllowsMoneyMovement(wallet.status)) {
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

                        _reloadLedger();
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

class _WalletStatusPill extends StatelessWidget {
  const _WalletStatusPill({required this.status});

  final String status;

  Color _color() {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green.shade700;
      case 'FROZEN':
        return Colors.orange.shade900;
      case 'CLOSED':
        return Colors.red.shade800;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
        color: fg.withValues(alpha: 0.1),
      ),
      child: Text(
        _walletOperationalLabel(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
