import 'package:flutter/material.dart';

import '../../features/admin/admin_shell.dart';
import '../../features/admin/admin_tab.dart';
import '../../features/admin/customers/create_customer_screen.dart';
import '../../features/admin/customers/customer_status_screen.dart';
import '../../features/auth/auth_gate.dart';
import '../../features/auth/splash_screen.dart';

final class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String authGate = '/auth';
  static const String adminShell = '/admin';
  static const String adminCreateCustomer = '/admin/customers/create';
  static const String adminCustomerStatus = '/admin/customers/status';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case authGate:
        return MaterialPageRoute(
          builder: (_) => const AuthGate(),
          settings: settings,
        );
      case adminShell:
        final args = settings.arguments as AdminShellRouteArgs?;
        return MaterialPageRoute(
          builder: (_) =>
              AdminShell(initialTab: args?.initialTab ?? AdminTab.daily),
          settings: settings,
        );
      case adminCreateCustomer:
        return MaterialPageRoute(
          builder: (_) => const CreateCustomerScreen(),
          settings: settings,
        );
      case adminCustomerStatus:
        return MaterialPageRoute(
          builder: (_) => const CustomerStatusScreen(),
          settings: settings,
        );
      default:
        return _unknownRoute(settings);
    }
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return _unknownRoute(settings);
  }

  static Future<T?> goToAdminCreateCustomer<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(adminCreateCustomer);
  }

  static Future<T?> goToAdminCustomerStatus<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(adminCustomerStatus);
  }

  static void goToAuthGate(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(authGate, (route) => false);
  }

  static MaterialPageRoute<void> _unknownRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => UnknownRouteScreen(routeName: settings.name),
    );
  }
}

class AdminShellRouteArgs {
  final AdminTab initialTab;

  const AdminShellRouteArgs({required this.initialTab});
}

class UnknownRouteScreen extends StatelessWidget {
  final String? routeName;

  const UnknownRouteScreen({super.key, this.routeName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.route_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'This screen is not available yet.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                routeName == null ? 'Unknown route.' : 'Route: $routeName',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(
                      context,
                    ).pushReplacementNamed(AppRoutes.authGate);
                  }
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
