import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/login_screen.dart';
import 'package:flutter_application_1/features/auth/providers/auth_providers.dart';

import '../../test_helpers/fakes.dart';

void main() {
  test('forgot password validation rejects empty or malformed email', () {
    expect(
      LoginScreen.validateForgotPasswordEmail(''),
      'Enter your email first.',
    );
    expect(
      LoginScreen.validateForgotPasswordEmail('not-an-email'),
      'Enter a valid email address.',
    );
    expect(
      LoginScreen.validateForgotPasswordEmail('user@example.com'),
      isNull,
    );
  });

  testWidgets('forgot password does not call auth client for invalid email', (
    tester,
  ) async {
    final fakeAuthClient = FakeAuthClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authClientProvider.overrideWithValue(fakeAuthClient),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.text('Forgot Password? Click here'));
    await tester.pump();

    expect(find.text('Enter your email first.'), findsOneWidget);
    expect(fakeAuthClient.lastResetEmail, isNull);
  });
}
