import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahtot/data/users/user_model.dart';
import 'package:mahtot/data/wallet/models.dart';
import 'package:mahtot/features/auth/providers/auth_providers.dart';
import 'package:mahtot/features/customer/tabs/customer_history_tab.dart';
import 'package:mahtot/features/data/repository_providers.dart';
import 'package:mahtot/features/wallet/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/fake_repos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CustomerHistoryTab renders provider data and local selections', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    const uid = 'uid-1';
    const customerId = 'customer-1';
    final user = AppUser(
      uid: uid,
      role: UserRole.customer,
      status: 'active',
      customerId: customerId,
    );
    final month = DateTime.now();
    final monthStart = DateTime(month.year, month.month, 1);

    final wallet1 = buildCustomerWallet(
      id: 'wallet-1',
      customerId: customerId,
      displayName: 'Primary Wallet',
      isPrimary: true,
    );
    final wallet2 = buildCustomerWallet(
      id: 'wallet-2',
      customerId: customerId,
      displayName: 'Holiday Wallet',
      isPrimary: false,
      type: 'SECONDARY',
    );

    final allQueryWallet1 = CustomerLedgerPageQuery.fromDate(
      customerId: customerId,
      walletId: 'wallet-1',
      month: monthStart,
      filter: CustomerHistoryFilterValues.all,
    );
    final allQueryWallet2 = CustomerLedgerPageQuery.fromDate(
      customerId: customerId,
      walletId: 'wallet-2',
      month: monthStart,
      filter: CustomerHistoryFilterValues.all,
    );
    final withdrawQueryWallet2 = CustomerLedgerPageQuery.fromDate(
      customerId: customerId,
      walletId: 'wallet-2',
      month: monthStart,
      filter: CustomerHistoryFilterValues.withdrawals,
    );

    final fakeCustomerRepo = FakeCustomerRepo(
      walletsByCustomerId: {
        customerId: [wallet1, wallet2],
      },
    );
    final fakeWalletRepo = FakeWalletRepo(
      ledgerPagesByKey: {
        ledgerPageKeyFor(
          customerId: allQueryWallet1.customerId,
          walletId: allQueryWallet1.walletId,
          startDate: allQueryWallet1.startDate,
          endDate: allQueryWallet1.endDate,
          types: allQueryWallet1.types,
        ): LedgerPage(
          items: [buildLedgerTx(id: 'tx-wallet-1', type: 'DAILY_PAYMENT')],
          lastDoc: null,
          hasMore: false,
        ),
        ledgerPageKeyFor(
          customerId: allQueryWallet2.customerId,
          walletId: allQueryWallet2.walletId,
          startDate: allQueryWallet2.startDate,
          endDate: allQueryWallet2.endDate,
          types: allQueryWallet2.types,
        ): LedgerPage(
          items: [buildLedgerTx(id: 'tx-wallet-2', type: 'WITHDRAW_REQUEST')],
          lastDoc: null,
          hasMore: false,
        ),
        ledgerPageKeyFor(
          customerId: withdrawQueryWallet2.customerId,
          walletId: withdrawQueryWallet2.walletId,
          startDate: withdrawQueryWallet2.startDate,
          endDate: withdrawQueryWallet2.endDate,
          types: withdrawQueryWallet2.types,
        ): const LedgerPage(
          items: <LedgerTx>[],
          lastDoc: null,
          hasMore: false,
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerRepoProvider.overrideWithValue(fakeCustomerRepo),
          walletRepoProvider.overrideWithValue(fakeWalletRepo),
          authUidProvider.overrideWith((ref) => Stream<String?>.value(uid)),
          appUserProfileProvider(uid).overrideWith((ref) async => user),
        ],
        child: const MaterialApp(home: CustomerHistoryTab()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Daily Payment'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Holiday Wallet').last);
    await tester.pumpAndSettle();
    expect(find.text('Withdraw Requested'), findsOneWidget);

    await tester.tap(find.text('Withdrawals'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No matches for "Withdrawals"'), findsOneWidget);
  });
}
