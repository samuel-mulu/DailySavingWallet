import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String customerId;
  final String fullName;
  final String phone;
  final String companyName;
  final String address;
  final int dailyTargetCents;
  final int creditLimitCents;
  final String status; // 'active' | 'inactive'
  final DateTime? createdAt;
  final String createdByUid;

  const Customer({
    required this.customerId,
    required this.fullName,
    required this.phone,
    required this.companyName,
    required this.address,
    required this.dailyTargetCents,
    required this.creditLimitCents,
    required this.status,
    required this.createdAt,
    required this.createdByUid,
  });

  static Customer fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Customer(
      customerId: doc.id,
      fullName: (d['fullName'] as String?) ?? '',
      phone: (d['phone'] as String?) ?? '',
      companyName: (d['companyName'] as String?) ?? '',
      address: (d['address'] as String?) ?? '',
      dailyTargetCents: (d['dailyTargetCents'] as num?)?.toInt() ?? 0,
      creditLimitCents: (d['creditLimitCents'] as num?)?.toInt() ?? 0,
      status: (d['status'] as String?) ?? 'active',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      createdByUid: (d['createdByUid'] as String?) ?? '',
    );
  }

  static Customer fromDocSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Customer(
      customerId: doc.id,
      fullName: (d['fullName'] as String?) ?? '',
      phone: (d['phone'] as String?) ?? '',
      companyName: (d['companyName'] as String?) ?? '',
      address: (d['address'] as String?) ?? '',
      dailyTargetCents: (d['dailyTargetCents'] as num?)?.toInt() ?? 0,
      creditLimitCents: (d['creditLimitCents'] as num?)?.toInt() ?? 0,
      status: (d['status'] as String?) ?? 'active',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      createdByUid: (d['createdByUid'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phone': phone,
      'companyName': companyName,
      'address': address,
      'dailyTargetCents': dailyTargetCents,
      'creditLimitCents': creditLimitCents,
      'status': status,
      'createdByUid': createdByUid,
    };
  }

  bool matchesQuery(String query) {
    final q = query.toLowerCase();
    return fullName.toLowerCase().contains(q) ||
        phone.toLowerCase().contains(q) ||
        companyName.toLowerCase().contains(q);
  }
}
