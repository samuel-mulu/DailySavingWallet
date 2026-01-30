import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'models.dart';

class WalletRepo {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  WalletRepo({FirebaseFirestore? db, FirebaseFunctions? functions})
    : _db = db ?? FirebaseFirestore.instance,
      _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamWalletDoc(
    String customerId,
  ) {
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
    DateTime? startDate,
    DateTime? endDate,
    List<String>? types,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection('wallets')
        .doc(customerId)
        .collection('ledger')
        .orderBy('txDate', descending: true);

    if (startDate != null) {
      q = q.where(
        'txDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      q = q.where('txDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }
    if (types != null && types.isNotEmpty) {
      q = q.where('type', whereIn: types);
    }

    q = q.limit(limit);

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.get();
    final items = snap.docs.map(LedgerTx.fromDoc).toList(growable: false);
    final last = snap.docs.isEmpty ? null : snap.docs.last;
    return LedgerPage(
      items: items,
      lastDoc: last,
      hasMore: snap.docs.length == limit,
    );
  }

  Future<List<LedgerTx>> fetchRecentLedger(
    String customerId, {
    int limit = 5,
  }) async {
    final page = await fetchLedgerPage(customerId, limit: limit);
    return page.items;
  }

  Stream<List<WithdrawRequest>> streamPendingWithdrawRequests({
    int limit = 20,
  }) {
    return _db
        .collection('withdrawRequests')
        .where('status', isEqualTo: 'PENDING')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(WithdrawRequest.fromDoc).toList(growable: false),
        );
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
        .map(
          (snap) =>
              snap.docs.map(WithdrawRequest.fromDoc).toList(growable: false),
        );
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

  Stream<int> streamPendingWithdrawCount({int limit = 99}) {
    return _db
        .collection('withdrawRequests')
        .where('status', isEqualTo: 'PENDING')
        .limit(limit)
        .snapshots()
        .map((snap) => snap.size);
  }

  Future<void> requestWithdraw({
    required int amountCents,
    required String reason,
  }) async {
    final callable = _functions.httpsCallable('requestWithdraw');
    await callable.call(<String, dynamic>{
      'amountCents': amountCents,
      'reason': reason,
    });
  }

  Stream<Set<String>> streamRecordedCustomerIdsForDay(String txDay) {
    print(
      '🔍 [WalletRepo] streamRecordedCustomerIdsForDay: Querying for txDay="$txDay"',
    );
    return _db
        .collectionGroup('ledger')
        .where('type', isEqualTo: 'DAILY_PAYMENT')
        .where('txDay', isEqualTo: txDay)
        .snapshots()
        .map((snap) {
          print(
            '🔍 [WalletRepo] Found ${snap.docs.length} ledger entries for $txDay',
          );
          final ids = snap.docs
              .map((d) {
                final data = d.data();
                // Try getting from data, otherwise parse from path: wallets/{customerId}/ledger/{txId}
                String custId = data['customerId'] as String? ?? '';
                if (custId.isEmpty && d.reference.parent.parent != null) {
                  custId = d.reference.parent.parent!.id;
                }
                return custId;
              })
              .where((id) => id.isNotEmpty)
              .toSet();
          print('   -> Unique Customer IDs: $ids');
          return ids;
        });
  }

  Future<void> recordDailySaving({
    required String customerId,
    required int amountCents,
    required int txDateMillis,
    String? note,
    String? idempotencyKey,
  }) async {
    final txDate = DateTime.fromMillisecondsSinceEpoch(txDateMillis);
    final txDay =
        "${txDate.year}-${txDate.month.toString().padLeft(2, '0')}-${txDate.day.toString().padLeft(2, '0')}";

    final callable = _functions.httpsCallable('recordDailySaving');
    await callable.call(<String, dynamic>{
      'customerId': customerId,
      'amountCents': amountCents,
      'txDateMillis': txDateMillis,
      'txDay': txDay,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
        'idempotencyKey': idempotencyKey.trim(),
    });
  }

  Future<void> recordDeposit({
    required String customerId,
    required int amountCents,
    int? txDateMillis,
    String? note,
    String? idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('recordDepositV2');
    await callable.call(<String, dynamic>{
      'customerId': customerId,
      'amountCents': amountCents,
      if (txDateMillis != null) 'txDateMillis': txDateMillis,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
        'idempotencyKey': idempotencyKey.trim(),
    });
  }

  Future<String> requestWithdrawForCustomer({
    required String customerId,
    required int amountCents,
    required String reason,
  }) async {
    final callable = _functions.httpsCallable('requestWithdraw');
    final result = await callable.call(<String, dynamic>{
      'customerId': customerId,
      'amountCents': amountCents,
      'reason': reason,
    });
    return result.data['requestId'] as String;
  }

  Future<void> approveWithdraw(
    String requestId, {
    String? idempotencyKey,
  }) async {
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

  Future<int> fetchTotalSaving() async {
    try {
      print('[WalletRepo] fetchTotalSaving: Fetching docs...');
      final snap = await _db
          .collection('wallets')
          .where('balanceCents', isGreaterThan: 0)
          .get(); // Client-side fetch

      print('[WalletRepo] fetchTotalSaving: Found ${snap.size} docs');
      int total = 0;
      for (final doc in snap.docs) {
        final val = (doc.data()['balanceCents'] as num?)?.toInt() ?? 0;
        total += val;
      }
      print('[WalletRepo] fetchTotalSaving: Calculated Total: $total');
      return total;
    } catch (e) {
      print('[WalletRepo] fetchTotalSaving Error: $e');
      return 0;
    }
  }

  Future<int> fetchTotalCredit() async {
    try {
      print('[WalletRepo] fetchTotalCredit: Fetching docs...');
      final snap = await _db
          .collection('wallets')
          .where('balanceCents', isLessThan: 0)
          .get(); // Client-side fetch

      print('[WalletRepo] fetchTotalCredit: Found ${snap.size} docs');
      int total = 0;
      for (final doc in snap.docs) {
        final val = (doc.data()['balanceCents'] as num?)?.toInt() ?? 0;
        total += val;
      }
      print('[WalletRepo] fetchTotalCredit: Calculated Total: $total');
      return total;
    } catch (e) {
      print('[WalletRepo] fetchTotalCredit Error: $e');
      return 0;
    }
  }
}
