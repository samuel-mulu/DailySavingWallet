import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahtot/data/users/user_model.dart';
import 'package:mahtot/features/auth/providers/auth_providers.dart';
import 'package:mahtot/features/customer/tabs/customer_reports_tab.dart';
import 'package:mahtot/features/data/repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/fake_repos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  testWidgets(
    'customer reports uses wallet provider data and loads month report',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final month = monthKeyFor(DateTime.now());
      final fakeCustomerRepo = FakeCustomerRepo(
        walletsByCustomerId: {
          'customer-1': [
            buildCustomerWallet(
              id: 'wallet-1',
              customerId: 'customer-1',
              displayName: 'Primary Wallet',
              isPrimary: true,
            ),
            buildCustomerWallet(
              id: 'wallet-2',
              customerId: 'customer-1',
              displayName: 'Holiday Wallet',
              isPrimary: false,
              type: 'SECONDARY',
            ),
          ],
        },
      );
      final fakeWalletRepo = FakeWalletRepo(
        primaryWalletIdsByCustomerId: const {'customer-1': 'wallet-1'},
        recordedDailyByMonthKey: {
          'customer-1|wallet-1|$month': buildRecordedDailyDaysMonth(
            customerId: 'customer-1',
            walletId: 'wallet-1',
            month: month,
            recordedTxDays: const {'2026-04-01', '2026-04-02', '2026-04-05'},
          ),
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
            customerRepoProvider.overrideWithValue(fakeCustomerRepo),
            walletRepoProvider.overrideWithValue(fakeWalletRepo),
          ],
          child: const MaterialApp(home: CustomerReportsTab()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Monthly report'), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Saved days'), findsOneWidget);
      expect(find.text('Green days are saved dates.'), findsOneWidget);
      expect(find.text('Primary Wallet'), findsOneWidget);
      expect(
        fakeCustomerRepo.fetchCustomerWalletsCallCount,
        greaterThanOrEqualTo(1),
      );
      expect(
        fakeWalletRepo.fetchRecordedDailyDaysByMonthCallCount,
        greaterThanOrEqualTo(1),
      );

      await tester.tap(find.text('Primary Wallet').last);
      await tester.pumpAndSettle();
      expect(find.text('Holiday Wallet'), findsWidgets);
    },
  );
}
