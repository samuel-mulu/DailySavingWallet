import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../data/customers/customer_model.dart';
import '../../../data/customers/customer_repo.dart';
import '../../../data/wallet/wallet_repo.dart';
import 'create_customer_screen.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = CustomerRepo();
    final walletRepo = WalletRepo();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or company',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Customer>>(
        stream: repo.streamAllCustomers(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var customers = snap.data!;
          if (_searchQuery.trim().isNotEmpty) {
            customers = customers.where((c) => c.matchesQuery(_searchQuery)).toList();
          }

          if (customers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty ? 'No customers yet' : 'No customers found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            itemBuilder: (context, i) {
              final customer = customers[i];
              return CustomerCard(
                customer: customer,
                walletRepo: walletRepo,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerDetailScreen(customerId: customer.customerId),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateCustomerScreen()),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
    );
  }
}

class CustomerCard extends StatelessWidget {
  final Customer customer;
  final WalletRepo walletRepo;
  final VoidCallback onTap;

  const CustomerCard({
    super.key,
    required this.customer,
    required this.walletRepo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  customer.fullName.isNotEmpty ? customer.fullName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.companyName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phone,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              StreamBuilder(
                stream: walletRepo.streamWallet(customer.customerId),
                builder: (context, snap) {
                  if (!snap.hasData || snap.data == null) {
                    return const SizedBox.shrink();
                  }
                  final balance = snap.data!.balanceCents;
                  final isNegative = balance < 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        MoneyEtb.formatCents(balance),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isNegative
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      if (isNegative)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'DEBT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
