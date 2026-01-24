import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/users/user_model.dart';
import '../../data/users/user_repo.dart';
import '../app_lock/app_lock_gate.dart';
import '../admin/admin_shell.dart';
import '../superadmin/superadmin_shell.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }

        final user = authSnap.data;
        if (user == null) return const LoginScreen();

        // Logged in -> get role profile, then route.
        return FutureBuilder<AppUser>(
          future: UserRepo().getOrCreateUserProfile(user.uid),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const _Loading();
            }
            if (userSnap.hasError) {
              return _ErrorView(message: userSnap.error.toString());
            }

            final appUser = userSnap.data!;
            if (appUser.status != 'active') {
              return const _ErrorView(message: 'Account is disabled.');
            }

            switch (appUser.role) {
              case UserRole.customer:
                return AppLockGate(uid: appUser.uid);
              case UserRole.admin:
                return const AdminShell();
              case UserRole.superadmin:
                return const SuperAdminShell();
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
