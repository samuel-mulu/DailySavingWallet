import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/users/user_model.dart';
import '../app_lock/app_lock_gate.dart';
import '../admin/admin_shell.dart';
import '../superadmin/superadmin_shell.dart';
import 'login_screen.dart';
import 'providers/auth_providers.dart';

class AuthGate extends ConsumerWidget {
  final WidgetBuilder? loginBuilder;
  final Widget Function(BuildContext context, String uid)? customerBuilder;
  final WidgetBuilder? adminBuilder;
  final WidgetBuilder? superadminBuilder;

  const AuthGate({
    super.key,
    this.loginBuilder,
    this.customerBuilder,
    this.adminBuilder,
    this.superadminBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUid = ref.watch(authUidProvider);

    return authUid.when(
      loading: () => const _Loading(),
      error: (error, _) => _ErrorView(message: error.toString()),
      data: (uid) {
        if (uid == null) {
          return loginBuilder?.call(context) ?? const LoginScreen();
        }

        final appUserAsync = ref.watch(appUserProfileProvider(uid));
        return appUserAsync.when(
          loading: () => const _Loading(),
          error: (error, _) => _ErrorView(message: error.toString()),
          data: (appUser) {
            if (appUser.status != 'active') {
              return const _ErrorView(message: 'Account is disabled.');
            }

            switch (appUser.role) {
              case UserRole.customer:
                return customerBuilder?.call(context, appUser.uid) ??
                    AppLockGate(uid: appUser.uid);
              case UserRole.admin:
                return adminBuilder?.call(context) ?? const AdminShell();
              case UserRole.superadmin:
                return superadminBuilder?.call(context) ??
                    const SuperAdminShell();
            }
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(message, textAlign: TextAlign.center)),
    );
  }
}
