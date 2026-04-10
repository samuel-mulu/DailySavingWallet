import 'package:flutter/material.dart';

import '../../../data/api/api_client.dart';
import '../../../data/customers/customer_group_model.dart';
import '../../../data/customers/customer_model.dart';
import '../../../data/customers/customer_repo.dart';
import 'customer_detail_screen.dart';
import 'widgets/customer_profile_avatar.dart';

class CustomerGroupManagementScreen extends StatefulWidget {
  const CustomerGroupManagementScreen({super.key});

  @override
  State<CustomerGroupManagementScreen> createState() =>
      _CustomerGroupManagementScreenState();
}

class _CustomerGroupManagementScreenState
    extends State<CustomerGroupManagementScreen> {
  static const String _unassignedGroupKey = '__unassigned__';
  final CustomerRepo _repo = CustomerRepo();

  bool _loading = true;
  bool _working = false;
  String? _error;
  List<Customer> _customers = const [];
  List<CustomerGroupSummary> _groups = const [];
  int _unassignedCustomerCount = 0;
  Set<String> _expandedSectionKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }

    try {
      final results = await Future.wait<Object>([
        _repo.fetchAllActiveCustomers(),
        _repo.fetchCustomerGroups(),
      ]);
      final customers = (results[0] as List<Customer>).toList()
        ..sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );
      final groupResult = results[1] as CustomerGroupListResult;

      if (!mounted) return;
      final validSectionKeys = <String>{
        _unassignedGroupKey,
        ...groupResult.groups.map((group) => group.id),
      };
      setState(() {
        _customers = customers;
        _groups = groupResult.groups;
        _unassignedCustomerCount = customers
            .where((customer) => customer.group == null)
            .length;
        _expandedSectionKeys = _expandedSectionKeys
            .where(validSectionKeys.contains)
            .toSet();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  List<Customer> _customersForGroup(String groupId) {
    return _customers
        .where((customer) => customer.group?.id == groupId)
        .toList(growable: false);
  }

  List<Customer> get _unassignedCustomers {
    return _customers
        .where((customer) => customer.group == null)
        .toList(growable: false);
  }

  int get _assignedCustomerCount {
    return _customers.where((customer) => customer.group != null).length;
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

  Future<void> _createGroup() async {
    final name = await _showGroupNameDialog(
      title: 'Create group',
      actionLabel: 'Create',
    );
    if (name == null) return;

    await _runAction(() async {
      final group = await _repo.createCustomerGroup(name: name);
      await _loadData(showLoader: false);
      if (!mounted) return;
      _showSnack('${group.name} created.');
    });
  }

  Future<void> _renameGroup(CustomerGroupSummary group) async {
    final name = await _showGroupNameDialog(
      title: 'Rename group',
      actionLabel: 'Save',
      initialValue: group.name,
    );
    if (name == null) return;

    await _runAction(() async {
      final updated = await _repo.updateCustomerGroup(
        groupId: group.id,
        name: name,
      );
      await _loadData(showLoader: false);
      if (!mounted) return;
      _showSnack('Renamed to ${updated.name}.');
    });
  }

  Future<void> _assignCustomerToGroup(
    Customer customer,
    CustomerGroupSummary? targetGroup,
  ) async {
    final destination = targetGroup?.name ?? 'Not assigned';

    await _runAction(() async {
      await _repo.assignCustomerGroup(
        customerId: customer.customerId,
        groupId: targetGroup?.id,
      );
      await _loadData(showLoader: false);
      if (!mounted) return;
      _showSnack('${customer.fullName} moved to $destination.');
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } on BackendApiException catch (error) {
      if (!mounted) return;
      _showSnack(error.message, isError: true);
    } catch (error) {
      if (!mounted) return;
      _showSnack('$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<String?> _showGroupNameDialog({
    required String title,
    required String actionLabel,
    String initialValue = '',
  }) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => _GroupNameDialog(
        title: title,
        actionLabel: actionLabel,
        initialValue: initialValue,
      ),
    );
  }

  Future<void> _showAssignCustomerSheet(
    CustomerGroupSummary targetGroup,
  ) async {
    final eligibleCustomers = _customers
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
              for (final group in _groups)
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Groups'),
        actions: [
          IconButton(
            tooltip: 'Create group',
            onPressed: _working ? null : _createGroup,
            icon: const Icon(Icons.group_add_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_working) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _customers.isEmpty && _groups.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 44),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _working ? null : _loadData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadData(showLoader: false),
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
                                    value: _groups.length.toString(),
                                    color: const Color(0xFF8B5CF6),
                                  ),
                                  _SummaryChip(
                                    label: 'Assigned',
                                    value: _assignedCustomerCount.toString(),
                                    color: const Color(0xFF10B981),
                                  ),
                                  _SummaryChip(
                                    label: 'Not assigned',
                                    value: _unassignedCustomerCount.toString(),
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _working ? null : _createGroup,
                                icon: const Icon(Icons.add),
                                label: const Text('Create group'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_groups.isEmpty)
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
                        for (final group in _groups) ...[
                          _GroupCard(
                            group: group,
                            customers: _customersForGroup(group.id),
                            busy: _working,
                            isExpanded: _isSectionExpanded(group.id),
                            onToggleExpanded: () =>
                                _toggleSectionExpanded(group.id),
                            onAssign: () => _showAssignCustomerSheet(group),
                            onRename: () => _renameGroup(group),
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
                          countOverride: _unassignedCustomerCount,
                          iconOverride: Icons.person_off_outlined,
                          customers: _unassignedCustomers,
                          busy: _working,
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
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: colorScheme.primary),
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
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: colorScheme.primary,
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
  });

  final String title;
  final String actionLabel;
  final String initialValue;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
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
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
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
