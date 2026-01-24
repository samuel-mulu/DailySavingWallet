import 'package:flutter/material.dart';

import '../../../data/wallet/wallet_repo.dart';

class AdminHomeTab extends StatelessWidget {
  const AdminHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = WalletRepo();
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pending approvals', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          FutureBuilder<int>(
                            future: repo.fetchPendingWithdrawCount(limit: 20),
                            builder: (context, snap) {
                              final v = snap.data;
                              final text = v == null ? '—' : '$v';
                              return Text(text, style: Theme.of(context).textTheme.headlineMedium);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Tip: Open “Approvals” tab to review pending withdraw requests.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

