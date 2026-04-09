import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/routes.dart';
import '../admin/record_daily_saving_screen.dart';
import '../admin/withdraw_approvals_screen.dart';
import '../auth/providers/auth_providers.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(authClientProvider).signOut();
              if (context.mounted) {
                AppRoutes.goToAuthGate(context);
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RecordDailySavingScreen(),
                  ),
                ),
                child: const Text('Record Daily Saving'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WithdrawApprovalsScreen(),
                  ),
                ),
                child: const Text('Withdraw Approvals'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
