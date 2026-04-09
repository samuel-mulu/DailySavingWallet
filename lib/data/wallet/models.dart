class WalletSnapshot {
  /// Wallet row id (uuid).
  final String id;
  final String customerId;
  final int balanceCents;
  final int dailyTargetCents;
  final int creditLimitCents;
  final String status;
  final String type;
  final String displayName;
  final String? code;
  final DateTime? lastSavingAt;
  final DateTime? lastActivityAt;
  final DateTime? updatedAt;

  const WalletSnapshot({
    required this.id,
    required this.customerId,
    required this.balanceCents,
    required this.dailyTargetCents,
    required this.creditLimitCents,
    required this.status,
    required this.type,
    required this.displayName,
    this.code,
    this.lastSavingAt,
    this.lastActivityAt,
    this.updatedAt,
  });

  static WalletSnapshot fromBackendMap(Map<String, dynamic> json) {
    return WalletSnapshot(
      id: (json['id'] as String?) ?? '',
      customerId: (json['customerId'] as String?) ?? '',
      balanceCents: _toInt(json['balanceCents']),
      dailyTargetCents: _toInt(json['dailyTargetCents']),
      creditLimitCents: _toInt(json['creditLimitCents']),
      status: (json['status'] as String?) ?? 'ACTIVE',
      type: (json['type'] as String?) ?? 'PRIMARY',
      displayName: (json['displayName'] as String?) ?? '',
      code: json['code'] as String?,
      lastSavingAt: _parseDateTime(json['lastSavingAt']),
      lastActivityAt: _parseDateTime(json['lastActivityAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  /// Short label for UI (e.g. chips).
  String get label {
    final c = code?.trim();
    if (c != null && c.isNotEmpty) return '$displayName ($c)';
    return displayName.isNotEmpty ? displayName : type;
  }
}

/// Row from `GET /customers/:id/wallets`.
class CustomerWallet {
  final String id;
  final String customerId;
  final String type;
  final String displayName;
  final String? code;
  final String status;
  final int balanceCents;
  final int dailyTargetCents;
  final int creditLimitCents;
  final DateTime? lastSavingAt;
  final DateTime? lastActivityAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isPrimary;

  const CustomerWallet({
    required this.id,
    required this.customerId,
    required this.type,
    required this.displayName,
    this.code,
    required this.status,
    required this.balanceCents,
    required this.dailyTargetCents,
    required this.creditLimitCents,
    this.lastSavingAt,
    this.lastActivityAt,
    this.createdAt,
    this.updatedAt,
    required this.isPrimary,
  });

  static CustomerWallet fromBackendMap(Map<String, dynamic> json) {
    return CustomerWallet(
      id: (json['id'] as String?) ?? '',
      customerId: (json['customerId'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'PRIMARY',
      displayName: (json['displayName'] as String?) ?? '',
      code: json['code'] as String?,
      status: (json['status'] as String?) ?? 'ACTIVE',
      balanceCents: _toInt(json['balanceCents']),
      dailyTargetCents: _toInt(json['dailyTargetCents']),
      creditLimitCents: _toInt(json['creditLimitCents']),
      lastSavingAt: _parseDateTime(json['lastSavingAt']),
      lastActivityAt: _parseDateTime(json['lastActivityAt']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      isPrimary: json['isPrimary'] == true,
    );
  }

  WalletSnapshot toSnapshot() {
    return WalletSnapshot(
      id: id,
      customerId: customerId,
      balanceCents: balanceCents,
      dailyTargetCents: dailyTargetCents,
      creditLimitCents: creditLimitCents,
      status: status,
      type: type,
      displayName: displayName,
      code: code,
      lastSavingAt: lastSavingAt,
      lastActivityAt: lastActivityAt,
      updatedAt: updatedAt,
    );
  }

  String get label {
    final c = code?.trim();
    if (c != null && c.isNotEmpty) return '$displayName ($c)';
    return displayName.isNotEmpty ? displayName : type;
  }
}

class WalletStatusHealth {
  final int freezeCount;
  final int closeCount;
  final int reactivateCount;
  final String? latestReason;
  final DateTime? latestChangedAt;

  const WalletStatusHealth({
    required this.freezeCount,
    required this.closeCount,
    required this.reactivateCount,
    required this.latestReason,
    required this.latestChangedAt,
  });

  static WalletStatusHealth fromBackendMap(Map<String, dynamic> json) {
    return WalletStatusHealth(
      freezeCount: _toInt(json['freezeCount']),
      closeCount: _toInt(json['closeCount']),
      reactivateCount: _toInt(json['reactivateCount']),
      latestReason: json['latestReason'] as String?,
      latestChangedAt: _parseDateTime(json['latestChangedAt']),
    );
  }
}

class WalletStatusEvent {
  final String id;
  final String fromStatus;
  final String toStatus;
  final String reason;
  final DateTime? changedAt;
  final String changedByUserId;
  final String? changedByEmail;

  const WalletStatusEvent({
    required this.id,
    required this.fromStatus,
    required this.toStatus,
    required this.reason,
    required this.changedAt,
    required this.changedByUserId,
    required this.changedByEmail,
  });

  static WalletStatusEvent fromBackendMap(Map<String, dynamic> json) {
    return WalletStatusEvent(
      id: (json['id'] as String?) ?? '',
      fromStatus: (json['fromStatus'] as String?) ?? '',
      toStatus: (json['toStatus'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
      changedAt: _parseDateTime(json['changedAt']),
      changedByUserId: (json['changedByUserId'] as String?) ?? '',
      changedByEmail: json['changedByEmail'] as String?,
    );
  }
}

class LedgerTx {
  final String id;
  final String type;
  final String direction;
  final int amountCents;
  final int? balanceAfterCents;
  final DateTime? txDate;
  final DateTime? createdAt;
  final String createdByUid;
  final Map<String, dynamic>? meta;

  const LedgerTx({
    required this.id,
    required this.type,
    required this.direction,
    required this.amountCents,
    required this.balanceAfterCents,
    required this.txDate,
    required this.createdAt,
    required this.createdByUid,
    required this.meta,
  });

  DateTime? get displayDate => txDate ?? createdAt;

  static LedgerTx fromBackendMap(Map<String, dynamic> json) {
    return LedgerTx(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'UNKNOWN',
      direction: (json['direction'] as String?) ?? 'IN',
      amountCents: _toInt(json['amountCents']),
      balanceAfterCents: json['balanceAfterCents'] == null
          ? null
          : _toInt(json['balanceAfterCents']),
      txDate: _parseDateTime(json['txDate']),
      createdAt: _parseDateTime(json['createdAt']),
      createdByUid:
          (json['createdByUserId'] as String?) ??
          (json['createdByUid'] as String?) ??
          '',
      meta: json['meta'] is Map
          ? Map<String, dynamic>.from(json['meta'] as Map)
          : null,
    );
  }
}

class LedgerPage {
  final List<LedgerTx> items;
  final Object? lastDoc;
  final bool hasMore;

  const LedgerPage({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });
}

class WithdrawRequest {
  final String id;
  final String customerId;
  final String? walletId;
  final int amountCents;
  final int approvalFeeCents;
  final int approvedTotalDebitCents;
  final String reason;
  final String status;
  final String requestedByUid;
  final String? reviewedByUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WithdrawRequest({
    required this.id,
    required this.customerId,
    required this.walletId,
    required this.amountCents,
    required this.approvalFeeCents,
    required this.approvedTotalDebitCents,
    required this.reason,
    required this.status,
    required this.requestedByUid,
    required this.reviewedByUid,
    required this.createdAt,
    required this.updatedAt,
  });

  static WithdrawRequest fromBackendMap(Map<String, dynamic> json) {
    return WithdrawRequest(
      id: (json['id'] as String?) ?? '',
      customerId: (json['customerId'] as String?) ?? '',
      walletId: json['walletId'] as String?,
      amountCents: _toInt(json['amountCents']),
      approvalFeeCents: _toInt(json['approvalFeeCents']),
      approvedTotalDebitCents: _toInt(json['approvedTotalDebitCents']),
      reason: (json['reason'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'PENDING',
      requestedByUid:
          (json['requestedByUserId'] as String?) ??
          (json['requestedByUid'] as String?) ??
          '',
      reviewedByUid:
          (json['reviewedByUserId'] as String?) ??
          (json['reviewedByUid'] as String?),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _parseDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}

/// Riverpod family key: [walletId] null means primary wallet on the server.
typedef WalletFamilyKey = ({String customerId, String? walletId});
