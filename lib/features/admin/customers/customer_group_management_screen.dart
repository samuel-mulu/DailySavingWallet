import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/group_colors.dart';
import '../../../data/api/api_client.dart';
import '../../../data/customers/customer_group_model.dart';
import '../../../data/customers/customer_model.dart';
import 'customer_detail_screen.dart';
import 'customer_group_management_providers.dart';
import 'widgets/customer_profile_avatar.dart';

class CustomerGroupManagementScreen extends ConsumerStatefulWidget {
  const CustomerGroupManagementScreen({super.key});

  @override
  ConsumerState<CustomerGroupManagementScreen> createState() =>
      _CustomerGroupManagementScreenState();
}

class _CustomerGroupManagementScreenState
    extends ConsumerState<CustomerGroupManagementScreen> {
  static const String _unassignedGroupKey = '__unassigned__';
  Set<String> _expandedSectionKeys = <String>{};

  List<Customer> _customersForGroup(List<Customer> customers, String groupId) {
    return customers
        .where((customer) => customer.group?.id == groupId)
        .toList(growable: false);
  }

  List<Customer> _unassignedCustomers(List<Customer> customers) {
    return customers
        .where((customer) => customer.group == null)
        .toList(growable: false);
  }

  bool _isSectionExpanded(String sectionKey) {
    return _expandedSectionKeys.contains(sectionKey);
  }

  void _toggleSectionExpanded(String sectionKey) {
    setState(() {
      if (!_expandedSectionKeys.remove(sectionKey)) {
        _expandedSectionKeys.add(sectionKey);
      }
    });
  }

  Set<String> _blockedGroupColorHexes(
    List<CustomerGroupSummary> groups, {
    String? allowedColorHex,
  }) {
    return unavailablePaletteGroupColorHexes(
      usedColorHexes: groups.map((group) => group.colorHex),
      allowedColorHexes: allowedColorHex == null
          ? const <String>[]
          : <String>[allowedColorHex],
    );
  }

  String _suggestedGroupColorHex(
    List<CustomerGroupSummary> groups, {
    String? preferredColorHex,
  }) {
    return preferredGroupColorHex(
      usedColorHexes: groups.map((group) => group.colorHex),
      preferredColorHex: preferredColorHex,
      allowedColorHexes: preferredColorHex == null
          ? const <String>[]
          : <String>[preferredColorHex],
    );
  }

  Future<void> _createGroup(List<CustomerGroupSummary> groups) async {
    final input = await _showGroupNameDialog(
      title: 'Create group',
      actionLabel: 'Create',
      initialColorHex: _suggestedGroupColorHex(groups),
      unavailableColorHexes: _blockedGroupColorHexes(groups),
    );
    if (input == null) return;

    await _runAction((
      type: 'create',
      groupId: null,
      customerId: null,
      name: input.name,
      colorHex: input.colorHex,
    ));
  }

  Future<void> _renameGroup(
    CustomerGroupSummary group,
    List<CustomerGroupSummary> groups,
  ) async {
    final input = await _showGroupNameDialog(
      title: 'Rename group',
      actionLabel: 'Save',
      initialValue: group.name,
      initialColorHex: _suggestedGroupColorHex(
        groups,
        preferredColorHex: group.colorHex,
      ),
      unavailableColorHexes: _blockedGroupColorHexes(
        groups,
        allowedColorHex: group.colorHex,
      ),
    );
    if (input == null) return;

    await _runAction((
      type: 'rename',
      groupId: group.id,
      customerId: null,
      name: input.name,
      colorHex: input.colorHex,
    ));
  }

  Future<void> _assignCustomerToGroup(
    Customer customer,
    CustomerGroupSummary? targetGroup,
  ) async {
    final destination = targetGroup?.name ?? 'Not assigned';

    await _runAction((
      type: 'assign',
      groupId: targetGroup?.id,
      customerId: customer.customerId,
      name: null,
      colorHex: null,
    ), successMessage: '${customer.fullName} moved to $destination.');
  }

  Future<void> _runAction(
    CustomerGroupMutationCommand command, {
    String? successMessage,
  }) async {
    ref.read(customerGroupMutationProvider.notifier).clear();
    try {
      await ref.read(customerGroupMutationProvider.notifier).submit(command);
      final mutation = ref.read(customerGroupMutationProvider);
      if (mutation.error != null) {
        throw mutation.error!;
      }
      await ref.read(customerGroupManagementProvider.notifier).refresh();
      if (!mounted) return;
      _showSnack(successMessage ?? (mutation.data ?? 'Done.'));
    } on BackendApiException catch (error) {
      if (!mounted) return;
      _showSnack(error.message, isError: true);
    } catch (error) {
      if (!mounted) return;
      _showSnack('$error', isError: true);
    } finally {
      ref.read(customerGroupMutationProvider.notifier).clear();
    }
  }

  Future<_GroupDialogResult?> _showGroupNameDialog({
    required String title,
    required String actionLabel,
    String initialValue = '',
    required String initialColorHex,
    Iterable<String> unavailableColorHexes = const <String>[],
  }) async {
    return showDialog<_GroupDialogResult>(
      context: context,
      builder: (dialogContext) => _GroupNameDialog(
        title: title,
        actionLabel: actionLabel,
        initialValue: initialValue,
        initialColorHex: initialColorHex,
        colorPalette: groupColorPalette,
        unavailableColorHexes: unavailableColorHexes,
      ),
    );
  }

  Future<void> _showAssignCustomerSheet(
    CustomerGroupSummary targetGroup,
    List<Customer> customers,
  ) async {
    final eligibleCustomers = customers
        .where((customer) => customer.group?.id != targetGroup.id)
        .toList(growable: false);

    if (eligibleCustomers.isEmpty) {
      _showSnack('Every active customer is already in ${targetGroup.name}.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var search = '';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = eligibleCustomers
                .where((customer) {
                  final query = search.trim().toLowerCase();
                  if (query.isEmpty) return true;
                  return customer.fullName.toLowerCase().contains(query) ||
                      customer.companyName.toLowerCase().contains(query) ||
                      customer.phone.toLowerCase().contains(query) ||
                      customer.groupName.toLowerCase().contains(query);
                })
                .toList(growable: false);

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.82,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign to ${targetGroup.name}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap a customer to assign or transfer them into this group.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Search customers',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setSheetState(() => search = value);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('No matching customers available.'),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final customer = filtered[index];
                                final currentGroup =
                                    customer.group?.name ?? 'Not assigned';
                                return ListTile(
                                  leading: CustomerProfileAvatar(
                                    customer: customer,
                                    radius: 20,
                                    enablePreview: true,
                                  ),
                                  title: Text(customer.fullName),
                                  subtitle: Text(
                                    '${customer.companyName} - $currentGroup',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: () async {
                                    Navigator.of(sheetContext).pop();
                                    await _assignCustomerToGroup(
                                      customer,
                                      targetGroup,
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showTransferCustomerSheet(Customer customer) async {
    final groups =
        ref.read(customerGroupManagementProvider).data?.groups ??
        const <CustomerGroupSummary>[];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.fullName,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Current group: ${customer.groupName}',
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              for (final group in groups)
                ListTile(
                  leading: Icon(
                    customer.group?.id == group.id
                        ? Icons.check_circle
                        : Icons.group_work_outlined,
                  ),
                  title: Text(group.name),
                  subtitle: Text('${group.customerCount} customers'),
                  enabled: customer.group?.id != group.id,
                  onTap: customer.group?.id == group.id
                      ? null
                      : () async {
                          Navigator.of(sheetContext).pop();
                          await _assignCustomerToGroup(customer, group);
                        },
                ),
              ListTile(
                leading: Icon(
                  customer.group == null
                      ? Icons.check_circle
                      : Icons.person_off_outlined,
                ),
                title: const Text('Not assigned'),
                subtitle: const Text('Remove this customer from any group'),
                enabled: customer.group != null,
                onTap: customer.group == null
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        await _assignCustomerToGroup(customer, null);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError
                ? Colors.red.shade700
                : Colors.green.shade700,
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final listState = ref.watch(customerGroupManagementProvider);
    final mutationState = ref.watch(customerGroupMutationProvider);
    final data = listState.data;
    final customers = data?.customers ?? const <Customer>[];
    final groups = data?.groups ?? const <CustomerGroupSummary>[];
    final unassignedCustomerCount = data?.unassignedCustomerCount ?? 0;
    final assignedCustomerCount = data?.assignedCustomerCount ?? 0;
    final working = mutationState.isLoading;
    final loading = listState.isRefreshing && data == null;
    final error = listState.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Groups'),
        actions: [
          IconButton(
            tooltip: 'Create group',
            onPressed: working ? null : () => _createGroup(groups),
            icon: const Icon(Icons.group_add_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (working) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null && customers.isEmpty && groups.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 44),
                          const SizedBox(height: 12),
                          Text('$error', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: working
                                ? null
                                : () => ref
                                      .read(
                                        customerGroupManagementProvider
                                            .notifier,
                                      )
                                      .refresh(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref
                        .read(customerGroupManagementProvider.notifier)
                        .refresh(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.group_work_outlined,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Use groups to organize the Daily page by route, team, or area.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _SummaryChip(
                                    label: 'Groups',
                                    value: groups.length.toString(),
                                    color: const Color(0xFF8B5CF6),
                                  ),
                                  _SummaryChip(
                                    label: 'Assigned',
                                    value: assignedCustomerCount.toString(),
                                    color: const Color(0xFF10B981),
                                  ),
                                  _SummaryChip(
                                    label: 'Not assigned',
                                    value: unassignedCustomerCount.toString(),
                                    color: unassignedGroupColor,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: working
                                    ? null
                                    : () => _createGroup(groups),
                                icon: const Icon(Icons.add),
                                label: const Text('Create group'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (groups.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: const Text(
                              'No groups yet. Create your first group to start organizing customers.',
                            ),
                          ),
                        for (final group in groups) ...[
                          _GroupCard(
                            group: group,
                            customers: _customersForGroup(customers, group.id),
                            busy: working,
                            isExpanded: _isSectionExpanded(group.id),
                            onToggleExpanded: () =>
                                _toggleSectionExpanded(group.id),
                            onAssign: () =>
                                _showAssignCustomerSheet(group, customers),
                            onRename: () => _renameGroup(group, groups),
                            onTransferCustomer: (customer) =>
                                _showTransferCustomerSheet(customer),
                            onUnassignCustomer: (customer) =>
                                _assignCustomerToGroup(customer, null),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _GroupCard(
                          titleOverride: 'Not assigned',
                          descriptionOverride:
                              'Customers without any group. Move them into a group from here.',
                          countOverride: unassignedCustomerCount,
                          iconOverride: Icons.person_off_outlined,
                          customers: _unassignedCustomers(customers),
                          busy: working,
                          isExpanded: _isSectionExpanded(_unassignedGroupKey),
                          onToggleExpanded: () =>
                              _toggleSectionExpanded(_unassignedGroupKey),
                          onTransferCustomer: (customer) =>
                              _showTransferCustomerSheet(customer),
                          showAssignButton: false,
                          emptyMessage:
                              'Every active customer already belongs to a group.',
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    this.group,
    this.titleOverride,
    this.descriptionOverride,
    this.countOverride,
    this.iconOverride,
    required this.customers,
    required this.busy,
    required this.isExpanded,
    required this.onToggleExpanded,
    this.onAssign,
    this.onRename,
    required this.onTransferCustomer,
    this.onUnassignCustomer,
    this.showAssignButton = true,
    this.emptyMessage = 'No customers assigned yet.',
  });

  final CustomerGroupSummary? group;
  final String? titleOverride;
  final String? descriptionOverride;
  final int? countOverride;
  final IconData? iconOverride;
  final List<Customer> customers;
  final bool busy;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onAssign;
  final VoidCallback? onRename;
  final ValueChanged<Customer> onTransferCustomer;
  final ValueChanged<Customer>? onUnassignCustomer;
  final bool showAssignButton;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = titleOverride ?? group?.name ?? '';
    final description =
        descriptionOverride ?? 'Assign or transfer customers into this group.';
    final count = countOverride ?? customers.length;
    final icon = iconOverride ?? Icons.group_work_outlined;
    final accentColor = group == null
        ? unassignedGroupColor
        : groupColorFromHex(group!.colorHex);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  if (onRename != null)
                    PopupMenuButton<_GroupMenuAction>(
                      enabled: !busy,
                      onSelected: (value) {
                        if (value == _GroupMenuAction.rename) {
                          onRename?.call();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _GroupMenuAction.rename,
                          child: Text('Rename group'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (showAssignButton && onAssign != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: busy ? null : onAssign,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Assign customer'),
            ),
          ],
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 14),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: customers.isEmpty
                  ? Text(
                      emptyMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Column(
                      children: [
                        for (
                          var index = 0;
                          index < customers.length;
                          index++
                        ) ...[
                          if (index > 0) const Divider(height: 1),
                          _GroupedCustomerRow(
                            customer: customers[index],
                            onTransfer: busy
                                ? null
                                : () => onTransferCustomer(customers[index]),
                            onUnassign: onUnassignCustomer == null || busy
                                ? null
                                : () => onUnassignCustomer!(customers[index]),
                          ),
                        ],
                      ],
                    ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _GroupedCustomerRow extends StatelessWidget {
  const _GroupedCustomerRow({
    required this.customer,
    required this.onTransfer,
    this.onUnassign,
  });

  final Customer customer;
  final VoidCallback? onTransfer;
  final VoidCallback? onUnassign;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CustomerProfileAvatar(
        customer: customer,
        radius: 20,
        enablePreview: true,
      ),
      title: Text(customer.fullName),
      subtitle: Text('${customer.companyName} - ${customer.phone}'),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                CustomerDetailScreen(customerId: customer.customerId),
          ),
        );
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Transfer',
            onPressed: onTransfer,
            icon: Icon(Icons.swap_horiz_rounded, color: colorScheme.primary),
          ),
          if (onUnassign != null)
            IconButton(
              tooltip: 'Unassign',
              onPressed: onUnassign,
              icon: const Icon(Icons.person_remove_alt_1_outlined),
            ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

enum _GroupMenuAction { rename }

class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({
    required this.title,
    required this.actionLabel,
    required this.initialValue,
    required this.initialColorHex,
    required this.colorPalette,
    required this.unavailableColorHexes,
  });

  final String title;
  final String actionLabel;
  final String initialValue;
  final String initialColorHex;
  final List<String> colorPalette;
  final Iterable<String> unavailableColorHexes;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  late String _selectedColorHex;
  late final Set<String> _unavailableColorHexes;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _unavailableColorHexes = widget.unavailableColorHexes
        .map(tryNormalizeGroupColorHex)
        .whereType<String>()
        .toSet();
    _selectedColorHex = normalizeGroupColorHex(widget.initialColorHex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      _GroupDialogResult(
        name: _controller.text.trim(),
        colorHex: _selectedColorHex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasBlockedColors = _unavailableColorHexes.isNotEmpty;
    final previewLabel = _controller.text.trim().isEmpty
        ? 'Group preview'
        : _controller.text.trim();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  hintText: 'Example: Route A',
                ),
                autofocus: true,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Group name is required.';
                  }
                  if (trimmed.length > 120) {
                    return 'Use 120 characters or fewer.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 14),
            Text('Group color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              hasBlockedColors
                  ? 'Choose a color that is not already used by another group.'
                  : 'Choose a color for this group.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final colorHex in widget.colorPalette)
                  Builder(
                    builder: (context) {
                      final isSelected = _selectedColorHex == colorHex;
                      final isUnavailable =
                          _unavailableColorHexes.contains(colorHex) &&
                          !isSelected;
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: isUnavailable
                            ? null
                            : () =>
                                  setState(() => _selectedColorHex = colorHex),
                        child: Opacity(
                          opacity: isUnavailable ? 0.35 : 1,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: groupColorFromHex(colorHex),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black87
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : isUnavailable
                                ? const Icon(
                                    Icons.block_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: groupColorFromHex(
                  _selectedColorHex,
                ).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: groupColorFromHex(
                    _selectedColorHex,
                  ).withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: groupColorFromHex(_selectedColorHex),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      previewLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}

class _GroupDialogResult {
  const _GroupDialogResult({required this.name, required this.colorHex});

  final String name;
  final String colorHex;
}
