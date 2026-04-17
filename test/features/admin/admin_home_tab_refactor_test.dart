import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahtot/data/api/wallet_api.dart';
import 'package:mahtot/features/admin/admin_tab.dart';
import 'package:mahtot/features/admin/tabs/admin_home_tab.dart';
import 'package:mahtot/features/auth/providers/auth_providers.dart';

void main() {
  testWidgets('AdminHomeTab renders dashboard metrics with callbacks', (
    tester,
  ) async {
    AdminTab? selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountDisplayLabelProvider.overrideWith((ref) async => 'Admin'),
        ],
        child: MaterialApp(
          home: AdminHomeTab(
            onNavigateToTab: (tab) => selected = tab,
            loadPendingWithdrawCount: () async => 3,
            loadCustomerCount: () async => 12,
            loadWalletTotals: () async => const WalletTotals(
              totalSavingCents: 250000,
              totalCreditCents: -100000,
              companyWalletBalanceCents: 0,
              companyFeeRevenueCents: 0,
              totalCustomerWalletCount: 18,
              walletsWithPositiveBalanceCount: 10,
              walletsWithNegativeBalanceCount: 5,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.text('Pending\nApprovals'), findsOneWidget);
    expect(find.text('3'), findsWidgets);

    await tester.tap(find.text('Tap to review').first);
    await tester.pump();
    expect(selected, AdminTab.approvals);
  });
}
