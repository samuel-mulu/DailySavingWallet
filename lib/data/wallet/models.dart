import 'package:cloud_firestore/cloud_firestore.dart';

class WalletSnapshot {
  final String customerId;
  final int balanceCents;
  final DateTime? updatedAt;

  const WalletSnapshot({
    required this.customerId,
    required this.balanceCents,
    required this.updatedAt,
  });

  static WalletSnapshot fromDoc(
    String customerId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final bal = (data['balanceCents'] as num?)?.toInt() ?? 0;
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
    return WalletSnapshot(customerId: customerId, balanceCents: bal, updatedAt: updatedAt);
  }
}

class LedgerTx {
  final String id;
  final String type; // DAILY_PAYMENT|DEPOSIT|WITHDRAW_REQUEST|WITHDRAW_APPROVE|WITHDRAW_REJECT|ADJUSTMENT
  final String direction; // IN|OUT
  final int amountCents;
  final DateTime? createdAt;
  final String createdByUid;
  final Map<String, dynamic>? meta;

  const LedgerTx({
    required this.id,
    required this.type,
    required this.direction,
    required this.amountCents,
    required this.createdAt,
    required this.createdByUid,
    required this.meta,
  });

  static LedgerTx fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return LedgerTx(
      id: doc.id,
      type: (d['type'] as String?) ?? 'UNKNOWN',
      direction: (d['direction'] as String?) ?? 'IN',
      amountCents: (d['amountCents'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      createdByUid: (d['createdByUid'] as String?) ?? '',
      meta: d['meta'] is Map ? Map<String, dynamic>.from(d['meta'] as Map) : null,
    );
  }
}

class LedgerPage {
  final List<LedgerTx> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;

  const LedgerPage({required this.items, required this.lastDoc, required this.hasMore});
}

class WithdrawRequest {
  final String id;
  final String customerId;
  final int amountCents;
  final String reason;
  final String status; // PENDING|APPROVED|REJECTED
  final String requestedByUid;
  final String? reviewedByUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WithdrawRequest({
    required this.id,
    required this.customerId,
    required this.amountCents,
    required this.reason,
    required this.status,
    required this.requestedByUid,
    required this.reviewedByUid,
    required this.createdAt,
    required this.updatedAt,
  });

  static WithdrawRequest fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return WithdrawRequest(
      id: doc.id,
      customerId: (d['customerId'] as String?) ?? '',
      amountCents: (d['amountCents'] as num?)?.toInt() ?? 0,
      reason: (d['reason'] as String?) ?? '',
      status: (d['status'] as String?) ?? 'PENDING',
      requestedByUid: (d['requestedByUid'] as String?) ?? '',
      reviewedByUid: d['reviewedByUid'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

