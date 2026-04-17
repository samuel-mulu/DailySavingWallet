import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahtot/data/customers/customer_media.dart';
import 'package:mahtot/data/customers/customer_model.dart';
import 'package:mahtot/features/admin/withdraw_approvals_screen.dart';
import 'package:mahtot/features/data/repository_providers.dart';
import 'package:mahtot/features/wallet/wallet_providers.dart';

import '../../test_helpers/fake_repos.dart';

void main() {
  testWidgets(
    'WithdrawApprovalsScreen keeps tab selection local and uses provider-driven list/mutation',
    (tester) async {
      final fakeWalletRepo = FakeWalletRepo(
        withdrawRequestsByStatus: {
          'PENDING': [
            buildWithdrawRequest(
              id: 'wr-1',
              customerId: 'customer-1',
              reason: 'Need business cash',
              status: 'PENDING',
            ),
          ],
          'APPROVED': [
            buildWithdrawRequest(
              id: 'wr-2',
              customerId: 'customer-1',
              reason: 'Approved sample',
              status: 'APPROVED',
            ),
          ],
          'REJECTED': [
            buildWithdrawRequest(
              id: 'wr-3',
              customerId: 'customer-1',
              reason: 'Rejected sample',
              status: 'REJECTED',
            ),
          ],
        },
      );
      final customer = Customer(
        customerId: 'customer-1',
        fullName: 'Demo Customer',
        phone: '0911000000',
        companyName: 'Demo Co',
        address: 'Addis',
        email: 'demo@co.test',
        dailyTargetCents: 10000,
        creditLimitCents: 50000,
        status: CustomerLifecycleStatus.active,
        createdAt: DateTime(2025, 1, 1),
        createdByUid: 'admin-1',
        media: const CustomerMedia(),
        group: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletRepoProvider.overrideWithValue(fakeWalletRepo),
            customerByIdProvider(
              'customer-1',
            ).overrideWith((ref) async => customer),
          ],
          child: const MaterialApp(home: WithdrawApprovalsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Need business cash'), findsOneWidget);

      await tester.tap(find.text('Approved'));
      await tester.pumpAndSettle();
      expect(find.text('Approved sample'), findsOneWidget);

      await tester.tap(find.text('Pending'));
      await tester.pumpAndSettle();
      expect(find.text('Need business cash'), findsOneWidget);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(find.text('Approve Withdraw'), findsOneWidget);

      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();
      expect(fakeWalletRepo.approveWithdrawCallCount, 1);
    },
  );
}
