import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_model.dart';

class UserRepo {
  final FirebaseFirestore _db;

  UserRepo({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Future<AppUser> getOrCreateUserProfile(String uid) async {
    final ref = _db.doc('users/$uid');
    final snap = await ref.get();

    if (!snap.exists) {
      // default new users -> customer
      await ref.set({
        'role': 'customer',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const AppUser(
        uid: '',
        role: UserRole.customer,
        status: 'active',
      ).copyWithUid(uid);
    }

    final data = snap.data()!;
    final role = AppUser.roleFromString(data['role'] as String?);
    final status = (data['status'] as String?) ?? 'active';
    return AppUser(uid: uid, role: role, status: status);
  }
}

extension _CopyUid on AppUser {
  AppUser copyWithUid(String uid) =>
      AppUser(uid: uid, role: role, status: status);
}
