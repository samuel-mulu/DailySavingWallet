import '../api/auth_api.dart';

enum UserRole { customer, admin, superadmin }

class AppUser {
  final String uid;
  final UserRole role;
  final String status;
  final String? customerId;

  const AppUser({
    required this.uid,
    required this.role,
    required this.status,
    required this.customerId,
  });

  factory AppUser.fromBackendMe(BackendMe me) {
    return AppUser(
      uid: me.userId,
      role: AppUser.roleFromString(me.role),
      status: me.status,
      customerId: me.customerId,
    );
  }

  static UserRole roleFromString(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'superadmin':
        return UserRole.superadmin;
      default:
        return UserRole.customer;
    }
  }

  static String roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.superadmin:
        return 'superadmin';
      case UserRole.customer:
        return 'customer';
    }
  }
}
