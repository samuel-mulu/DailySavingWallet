import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahtot/data/users/user_model.dart';
import 'package:mahtot/features/auth/providers/auth_providers.dart';
import 'package:mahtot/features/customer/tabs/customer_home_tab.dart';
import 'package:mahtot/features/data/repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/fake_repos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  testWidgets(
    'customer home loads wallet data from Riverpod-backed providers',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeCustomerRepo = FakeCustomerRepo(
        walletsByCustomerId: {
          'customer-1': [
            buildCustomerWallet(
              id: 'wallet-1',
              customerId: 'customer-1',
              displayName: 'Primary Wallet',
              isPrimary: true,
              balanceCents: 250000,
            ),
            buildCustomerWallet(
              id: 'wallet-2',
              customerId: 'customer-1',
              displayName: 'Holiday Wallet',
              isPrimary: false,
              type: 'SECONDARY',
              balanceCents: 75000,
            ),
          ],
        },
      );
      final fakeWalletRepo = FakeWalletRepo(
        primaryWalletIdsByCustomerId: const {'customer-1': 'wallet-1'},
        walletSnapshotsByWalletId: {
          'wallet-1': buildWalletSnapshot(
            id: 'wallet-1',
            customerId: 'customer-1',
            displayName: 'Primary Wallet',
            balanceCents: 250000,
          ),
          'wallet-2': buildWalletSnapshot(
            id: 'wallet-2',
            customerId: 'customer-1',
            displayName: 'Holiday Wallet',
            type: 'SECONDARY',
            balanceCents: 75000,
          ),
        },
        recentLedgerByWalletId: {
          'wallet-1': [buildLedgerTx(id: 'ledger-1', amountCents: 10000)],
          'wallet-2': [buildLedgerTx(id: 'ledger-2', amountCents: 5000)],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authUidProvider.overrideWith((ref) => Stream.value('uid-1')),
            appUserProfileProvider.overrideWith((ref, uid) async {
              expect(uid, 'uid-1');
              return const AppUser(
                uid: 'uid-1',
                role: UserRole.customer,
                status: 'active',
                customerId: 'customer-1',
              );
            }),
            accountDisplayLabelProvider.overrideWith((ref) async => 'Jane'),
            customerRepoProvider.overrideWithValue(fakeCustomerRepo),
            walletRepoProvider.overrideWithValue(fakeWalletRepo),
          ],
          child: const MaterialApp(home: Scaffold(body: CustomerHomeTab())),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('My Wallet'), findsOneWidget);
      expect(find.text('Primary Wallet'), findsOneWidget);
      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(
        fakeCustomerRepo.fetchCustomerWalletsCallCount,
        greaterThanOrEqualTo(1),
      );
      expect(fakeWalletRepo.fetchWalletCallCount, greaterThanOrEqualTo(1));
      expect(
        fakeWalletRepo.fetchRecentLedgerCallCount,
        greaterThanOrEqualTo(1),
      );

      final walletsBeforeRefresh =
          fakeCustomerRepo.fetchCustomerWalletsCallCount;
      final walletSnapshotsBeforeRefresh = fakeWalletRepo.fetchWalletCallCount;
      final ledgerBeforeRefresh = fakeWalletRepo.fetchRecentLedgerCallCount;

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refreshIndicator.onRefresh();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        fakeCustomerRepo.fetchCustomerWalletsCallCount,
        greaterThan(walletsBeforeRefresh),
      );
      expect(
        fakeWalletRepo.fetchWalletCallCount,
        greaterThan(walletSnapshotsBeforeRefresh),
      );
      expect(
        fakeWalletRepo.fetchRecentLedgerCallCount,
        greaterThan(ledgerBeforeRefresh),
      );
    },
  );
}
