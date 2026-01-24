import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'models.dart';

class WalletRepo {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  WalletRepo({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamWalletDoc(String customerId) {
    return _db.doc('wallets/$customerId').snapshots();
  }

  Stream<WalletSnapshot?> streamWallet(String customerId) {
    return _db.doc('wallets/$customerId').snapshots().map((doc) {
      if (!doc.exists) return null;
      return WalletSnapshot.fromDoc(customerId, doc);
    });
  }

  Future<LedgerPage> fetchLedgerPage(
    String customerId, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection('wallets')
        .doc(customerId)
        .collection('ledger')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.get();
    final items = snap.docs.map(LedgerTx.fromDoc).toList(growable: false);
    final last = snap.docs.isEmpty ? null : snap.docs.last;
    return LedgerPage(items: items, lastDoc: last, hasMore: snap.docs.length == limit);
  }

  Future<List<LedgerTx>> fetchRecentLedger(String customerId, {int limit = 5}) async {
    final page = await fetchLedgerPage(customerId, limit: limit);
    return page.items;
  }

  Stream<List<WithdrawRequest>> streamPendingWithdrawRequests({int limit = 20}) {
    return _db
        .collection('withdrawRequests')
        .where('status', isEqualTo: 'PENDING')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(WithdrawRequest.fromDoc).toList(growable: false));
  }

  Stream<List<WithdrawRequest>> streamCustomerWithdrawRequests(
    String customerId, {
    int limit = 3,
  }) {
    return _db
        .collection('withdrawRequests')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(WithdrawRequest.fromDoc).toList(growable: false));
  }

  Future<int> fetchPendingWithdrawCount({int limit = 20}) async {
    final snap = await _db
        .collection('withdrawRequests')
        .where('status', isEqualTo: 'PENDING')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.size;
  }

  Future<void> requestWithdraw({required int amountCents, required String reason}) async {
    final callable = _functions.httpsCallable('requestWithdraw');
    await callable.call(<String, dynamic>{'amountCents': amountCents, 'reason': reason});
  }

  Future<void> recordDailySaving({
    required String customerId,
    required int amountCents,
    String? note,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('recordDailySaving');
    await callable.call(<String, dynamic>{
      'customerId': customerId,
      'amountCents': amountCents,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
        'idempotencyKey': idempotencyKey.trim(),
    });
  }

  Future<void> approveWithdraw(String requestId, {String? idempotencyKey}) async {
    final callable = _functions.httpsCallable('approveWithdraw');
    await callable.call(<String, dynamic>{
      'requestId': requestId,
      if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
        'idempotencyKey': idempotencyKey.trim(),
    });
  }

  Future<void> rejectWithdraw(String requestId, {String? note}) async {
    final callable = _functions.httpsCallable('rejectWithdraw');
    await callable.call(<String, dynamic>{
      'requestId': requestId,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }
}

