enum UserRole { customer, admin, superadmin }

class AppUser {
  final String uid;
  final UserRole role;
  final String status;

  const AppUser({required this.uid, required this.role, required this.status});

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
