import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahtot/data/customers/customer_media.dart';
import 'package:mahtot/data/customers/customer_model.dart';
import 'package:mahtot/data/wallet/models.dart';
import 'package:mahtot/features/admin/customers/customer_detail_screen.dart';
import 'package:mahtot/features/data/repository_providers.dart';
import 'package:mahtot/features/wallet/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../test_helpers/fake_repos.dart';

void main() {
  testWidgets(
    'CustomerDetailScreen uses providers for reads and local wallet selection',
    (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final customer = Customer(
        customerId: 'customer-1',
        fullName: 'Demo Customer',
        phone: '0911223344',
        companyName: 'Demo Co',
        address: 'Addis',
        email: 'demo@co.test',
        dailyTargetCents: 10000,
        creditLimitCents: 0,
        status: CustomerLifecycleStatus.active,
        createdAt: DateTime(2025, 1, 1),
        createdByUid: 'admin-1',
        media: const CustomerMedia(),
        group: null,
      );
      final wallet1 = buildCustomerWallet(
        id: 'wallet-1',
        customerId: 'customer-1',
        displayName: 'Primary',
        isPrimary: true,
      );
      final wallet2 = buildCustomerWallet(
        id: 'wallet-2',
        customerId: 'customer-1',
        displayName: 'Holiday',
        isPrimary: false,
        type: 'SECONDARY',
      );
      final fakeCustomerRepo = FakeCustomerRepo(
        walletsByCustomerId: {
          'customer-1': [wallet1, wallet2],
        },
      );
      final fakeWalletRepo = FakeWalletRepo(
        walletSnapshotsByWalletId: {
          'wallet-1': buildWalletSnapshot(
            id: 'wallet-1',
            customerId: 'customer-1',
            displayName: 'Primary',
            balanceCents: 12000,
          ),
          'wallet-2': buildWalletSnapshot(
            id: 'wallet-2',
            customerId: 'customer-1',
            displayName: 'Holiday',
            balanceCents: 8000,
          ),
        },
        recentLedgerByWalletId: {
          'wallet-1': [buildLedgerTx(id: 'tx-1', type: 'DAILY_PAYMENT')],
          'wallet-2': [buildLedgerTx(id: 'tx-2', type: 'DEPOSIT')],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepoProvider.overrideWithValue(fakeCustomerRepo),
            walletRepoProvider.overrideWithValue(fakeWalletRepo),
            customerByIdProvider(
              'customer-1',
            ).overrideWith((ref) async => customer),
            walletStatusHistoryProvider((
              customerId: 'customer-1',
              walletId: 'wallet-1',
            )).overrideWith(
              (ref) async => (
                health: const WalletStatusHealth(
                  freezeCount: 0,
                  closeCount: 0,
                  reactivateCount: 0,
                  latestReason: null,
                  latestChangedAt: null,
                ),
                events: const <WalletStatusEvent>[],
              ),
            ),
            walletStatusHistoryProvider((
              customerId: 'customer-1',
              walletId: 'wallet-2',
            )).overrideWith(
              (ref) async => (
                health: const WalletStatusHealth(
                  freezeCount: 0,
                  closeCount: 0,
                  reactivateCount: 0,
                  latestReason: null,
                  latestChangedAt: null,
                ),
                events: const <WalletStatusEvent>[],
              ),
            ),
          ],
          child: const MaterialApp(
            home: CustomerDetailScreen(customerId: 'customer-1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Demo Customer'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
    },
  );
}
