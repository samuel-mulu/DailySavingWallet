import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/routing/routes.dart';

void main() {
  testWidgets('unknown routes fall back to safe screen', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
        onGenerateRoute: AppRoutes.onGenerateRoute,
        onUnknownRoute: AppRoutes.onUnknownRoute,
      ),
    );

    navigatorKey.currentState!.pushNamed('/missing-route');
    await tester.pumpAndSettle();

    expect(find.text('Page Not Found'), findsOneWidget);
    expect(find.text('Route: /missing-route'), findsOneWidget);
  });
}
