import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'customer_model.dart';

class CustomerRepo {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CustomerRepo({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<Map<String, dynamic>> createCustomer({
    required String fullName,
    required String phone,
    required String companyName,
    required String address,
    required String email,
    required String password,
    required int dailyTargetCents,
    int creditLimitCents = 0,
  }) async {
    final callable = _functions.httpsCallable('createCustomer');
    final result = await callable.call(<String, dynamic>{
      'fullName': fullName,
      'phone': phone,
      'companyName': companyName,
      'address': address,
      'email': email,
      'password': password,
      'dailyTargetCents': dailyTargetCents,
      'creditLimitCents': creditLimitCents,
    });
    
    final data = result.data as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('No data returned from createCustomer function');
    }
    
    return {
      'customerId': data['customerId'] as String? ?? '',
      'uid': data['uid'] as String? ?? '',
      'email': data['email'] as String? ?? email,
    };
  }

  Stream<List<Customer>> streamAllCustomers({String status = 'active'}) {
    return _db
        .collection('customers')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Customer.fromDoc).toList(growable: false));
  }

  Stream<Customer?> streamCustomer(String customerId) {
    return _db.doc('customers/$customerId').snapshots().map((doc) {
      if (!doc.exists) return null;
      return Customer.fromDocSnapshot(doc);
    });
  }

  Future<Customer?> getCustomer(String customerId) async {
    final doc = await _db.doc('customers/$customerId').get();
    if (!doc.exists) return null;
    return Customer.fromDocSnapshot(doc);
  }

  Future<List<Customer>> searchCustomers(String query) async {
    // For MVP, fetch all and filter in-memory to avoid complex Firestore queries
    final snap = await _db
        .collection('customers')
        .where('status', isEqualTo: 'active')
        .orderBy('fullName')
        .get();

    final customers = snap.docs.map(Customer.fromDoc).toList();
    
    if (query.trim().isEmpty) {
      return customers;
    }

    return customers.where((c) => c.matchesQuery(query)).toList();
  }
}
