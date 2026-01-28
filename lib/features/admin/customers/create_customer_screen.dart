import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../data/customers/customer_repo.dart';

class CreateCustomerScreen extends StatefulWidget {
  const CreateCustomerScreen({super.key});

  @override
  State<CreateCustomerScreen> createState() => _CreateCustomerScreenState();
}

class _CreateCustomerScreenState extends State<CreateCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _dailyTargetCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController(text: '0');

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _companyNameCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _dailyTargetCtrl.dispose();
    _creditLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final dailyTargetCents = MoneyEtb.parseEtbToCents(_dailyTargetCtrl.text);
      final creditLimitCents = _creditLimitCtrl.text.trim().isEmpty
          ? 0
          : MoneyEtb.parseEtbToCents(_creditLimitCtrl.text);

      final result = await CustomerRepo().createCustomer(
        fullName: _fullNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        companyName: _companyNameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        dailyTargetCents: dailyTargetCents,
        creditLimitCents: creditLimitCents,
      );

      if (!mounted) return;
      
      // Show credentials dialog
      _showCredentialsDialog(context, result);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Customer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fullNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _companyNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Company Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      maxLines: 2,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login Credentials',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email (for login)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Password (for login)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                        helperText: 'Min 6 characters',
                      ),
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (v.length < 6) return 'Min 6 characters';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Settings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dailyTargetCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Daily Target (ETB)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.savings),
                        helperText: 'Expected daily saving amount',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        try {
                          MoneyEtb.parseEtbToCents(v);
                        } catch (e) {
                          return 'Invalid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _creditLimitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Credit Limit (ETB)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.credit_card),
                        helperText: '0 = unlimited credit allowed',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        try {
                          MoneyEtb.parseEtbToCents(v);
                        } catch (e) {
                          return 'Invalid amount';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Create Customer'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCredentialsDialog(BuildContext context, Map<String, dynamic> result) {
    final email = result['email'] as String? ?? _emailCtrl.text;
    final customerId = result['customerId'] as String? ?? '';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Customer Created Successfully'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share these credentials with the customer:'),
            const SizedBox(height: 16),
            SelectableText('Email: $email'),
            const SizedBox(height: 8),
            SelectableText('Password: ${_passwordCtrl.text}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Customer can now log in with these credentials',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Copy to clipboard
              final credentials = 'Email: $email\nPassword: ${_passwordCtrl.text}';
              // Note: Clipboard requires flutter/services import
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Credentials: $credentials'),
                  duration: const Duration(seconds: 5),
                ),
              );
            },
            child: const Text('Show in Snackbar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop(customerId);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
