import 'package:flutter/material.dart';

import '../withdraw_approvals_screen.dart';

class AdminApprovalsTab extends StatelessWidget {
  const AdminApprovalsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Reuse the existing approvals screen for now; we’ll restyle it later.
    return const WithdrawApprovalsScreen();
  }
}

