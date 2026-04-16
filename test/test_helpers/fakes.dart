import 'dart:async';

import 'package:flutter_application_1/data/customers/customer_media.dart';
import 'package:flutter_application_1/data/customers/customer_model.dart';
import 'package:flutter_application_1/features/auth/services/auth_client.dart';

class FakeAuthClient implements AuthClient {
  FakeAuthClient({this.authUidStream});

  final Stream<String?>? authUidStream;
  String? lastResetEmail;
  String? lastLoginEmail;
  String? lastLoginPassword;

  @override
  Stream<String?> authUidChanges() {
    return authUidStream ?? const Stream<String?>.empty();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    lastResetEmail = email;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> signInWithPhoneAndPassword({
    required String phone,
    required String password,
  }) async {
    lastLoginEmail = phone;
    lastLoginPassword = password;
  }

  @override
  Future<void> signOut() async {}
}

Customer buildCustomer({
  String customerId = 'customer-1',
  String fullName = 'Jane Doe',
  String phone = '+251900000000',
  String email = 'jane@example.com',
  String companyName = 'Sample Co',
  String address = 'Addis Ababa',
  int dailyTargetCents = 10000,
  int creditLimitCents = 0,
}) {
  return Customer(
    customerId: customerId,
    fullName: fullName,
    phone: phone,
    email: email,
    companyName: companyName,
    address: address,
    dailyTargetCents: dailyTargetCents,
    creditLimitCents: creditLimitCents,
    status: 'active',
    createdAt: DateTime(2025, 1, 1),
    createdByUid: 'admin-1',
    media: const CustomerMedia(),
    group: null,
    balanceCents: 0,
  );
}
