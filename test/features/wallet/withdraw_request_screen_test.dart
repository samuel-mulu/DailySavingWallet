import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahtot/features/data/repository_providers.dart';
import 'package:mahtot/features/wallet/withdraw_request_screen.dart';

import '../../test_helpers/fake_repos.dart';

void main() {
  testWidgets(
    'WithdrawRequestScreen keeps form local and uses provider state for preview/submit',
    (tester) async {
      final fakeWalletRepo = FakeWalletRepo();
      fakeWalletRepo.previewWithdrawDelay = const Duration(milliseconds: 500);
      fakeWalletRepo.requestWithdrawDelay = const Duration(milliseconds: 500);
      fakeWalletRepo.throwOnRequestWithdraw = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [walletRepoProvider.overrideWithValue(fakeWalletRepo)],
          child: const MaterialApp(
            home: WithdrawRequestScreen(
              customerId: 'customer-1',
              walletId: 'wallet-1',
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), '30');
      await tester.enterText(find.byType(TextField).at(1), 'Urgent cash');
      await tester.pump(const Duration(milliseconds: 320));

      expect(find.text('Withdrawal summary'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Urgent cash'), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm withdraw request'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.textContaining('request withdraw failed'), findsOneWidget);
      expect(find.text('Urgent cash'), findsOneWidget);
    },
  );
}
