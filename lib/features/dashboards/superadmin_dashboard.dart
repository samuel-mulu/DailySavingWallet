import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/routes.dart';
import '../auth/providers/auth_providers.dart';

class SuperAdminDashboard extends ConsumerWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SuperAdmin Dashboard'),
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
      body: const Center(child: Text('SuperAdmin')),
    );
  }
}
