import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/routing/routes.dart';
import 'package:flutter_application_1/features/admin/admin_tab.dart';
import 'package:flutter_application_1/features/admin/tabs/admin_home_tab.dart';
import 'package:flutter_application_1/features/auth/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers/fakes.dart';

void main() {
  testWidgets('add new customer quick action opens create customer screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountDisplayLabelProvider.overrideWith((ref) async => 'Tester'),
          authClientProvider.overrideWithValue(FakeAuthClient()),
        ],
        child: MaterialApp(
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: AdminHomeTab(
            loadPendingWithdrawCount: () async => 0,
            loadCustomerCount: () async => 1,
            loadTotalSaving: () async => 0,
            loadTotalCredit: () async => 0,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final addCustomer = find.text('Add New Customer');
    await tester.scrollUntilVisible(addCustomer, 300);
    await tester.tap(addCustomer);
    await tester.pumpAndSettle();

    expect(find.text('Add Customer'), findsOneWidget);
  });

  testWidgets('review withdrawals quick action switches to approvals tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    AdminTab? selectedTab;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountDisplayLabelProvider.overrideWith((ref) async => 'Tester'),
          authClientProvider.overrideWithValue(FakeAuthClient()),
        ],
        child: MaterialApp(
          home: AdminHomeTab(
            loadPendingWithdrawCount: () async => 0,
            loadCustomerCount: () async => 1,
            loadTotalSaving: () async => 0,
            loadTotalCredit: () async => 0,
            onNavigateToTab: (tab) => selectedTab = tab,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final review = find.text('Review Withdrawals');
    await tester.scrollUntilVisible(review, 300);
    await tester.tap(review);
    await tester.pump();

    expect(selectedTab, AdminTab.approvals);
  });
}
