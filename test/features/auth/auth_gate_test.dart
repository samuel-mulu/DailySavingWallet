import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/users/user_model.dart';
import 'package:flutter_application_1/features/auth/auth_gate.dart';
import 'package:flutter_application_1/features/auth/providers/auth_providers.dart';

void main() {
  Widget buildTestApp({
    required Stream<String?> authStream,
    AppUser? appUser,
  }) {
    return ProviderScope(
      overrides: [
        authUidProvider.overrideWith((ref) => authStream),
        if (appUser != null)
          appUserProfileProvider.overrideWith((ref, uid) async {
            final profile = appUser;
            if (uid != profile.uid) {
              throw StateError('unexpected uid');
            }
            return profile;
          }),
      ],
      child: MaterialApp(
        home: AuthGate(
          loginBuilder: (_) => const Scaffold(body: Text('login-screen')),
          customerBuilder: (_, uid) =>
              Scaffold(body: Text('customer-shell:$uid')),
          adminBuilder: (_) => const Scaffold(body: Text('admin-shell')),
          superadminBuilder: (_) =>
              const Scaffold(body: Text('superadmin-shell')),
        ),
      ),
    );
  }

  testWidgets('shows login when signed out', (tester) async {
    await tester.pumpWidget(buildTestApp(authStream: Stream.value(null)));
    await tester.pumpAndSettle();

    expect(find.text('login-screen'), findsOneWidget);
  });

  testWidgets('routes customer users to customer flow', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authStream: Stream.value('customer-uid'),
        appUser: const AppUser(
          uid: 'customer-uid',
          role: UserRole.customer,
          status: 'active',
          customerId: null,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('customer-shell:customer-uid'), findsOneWidget);
  });

  testWidgets('routes admin users to admin shell', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authStream: Stream.value('admin-uid'),
        appUser: const AppUser(
          uid: 'admin-uid',
          role: UserRole.admin,
          status: 'active',
          customerId: null,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('admin-shell'), findsOneWidget);
  });
}
