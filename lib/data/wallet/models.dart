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
      status: parseWalletOperationalStatus(json),
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
      status: parseWalletOperationalStatus(json),
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

class WalletStatusCounts {
  final int all;
  final int active;
  final int frozen;
  final int closed;

  const WalletStatusCounts({
    required this.all,
    required this.active,
    required this.frozen,
    required this.closed,
  });

  int countForStatus(String status) {
    switch (status) {
      case 'ALL':
        return all;
      case 'ACTIVE':
        return active;
      case 'FROZEN':
        return frozen;
      case 'CLOSED':
        return closed;
      default:
        return 0;
    }
  }

  static WalletStatusCounts fromBackendMap(Map<String, dynamic> json) {
    return WalletStatusCounts(
      all: _toInt(json['ALL']),
      active: _toInt(json['ACTIVE']),
      frozen: _toInt(json['FROZEN']),
      closed: _toInt(json['CLOSED']),
    );
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

class WithdrawPreview {
  static const int _feeDivisor = 30;
  static const int _roundingOffset = _feeDivisor ~/ 2;

  final int requestedAmountCents;
  final int feeCents;
  final int netPayoutCents;

  const WithdrawPreview({
    required this.requestedAmountCents,
    required this.feeCents,
    required this.netPayoutCents,
  });

  static WithdrawPreview calculate(int amountCents) {
    final feeCents = (amountCents + _roundingOffset) ~/ _feeDivisor;
    return WithdrawPreview(
      requestedAmountCents: amountCents,
      feeCents: feeCents,
      netPayoutCents: amountCents - feeCents,
    );
  }

  static WithdrawPreview fromBackendMap(Map<String, dynamic> json) {
    final requestedAmountCents = json['requestedAmountCents'] == null
        ? _toInt(json['amountCents'])
        : _toInt(json['requestedAmountCents']);
    final amountCents = requestedAmountCents;
    final fallback = calculate(amountCents);

    return WithdrawPreview(
      requestedAmountCents: requestedAmountCents,
      feeCents: json['feeCents'] == null
          ? fallback.feeCents
          : _toInt(json['feeCents']),
      netPayoutCents: json['netPayoutCents'] == null
          ? fallback.netPayoutCents
          : _toInt(json['netPayoutCents']),
    );
  }
}

class WithdrawRequest {
  final String id;
  final String customerId;
  final String? walletId;
  final int amountCents;
  final int feeCents;
  final int netPayoutCents;
  final int approvalFeeCents;
  final int approvedNetPayoutCents;
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
    required this.feeCents,
    required this.netPayoutCents,
    required this.approvalFeeCents,
    required this.approvedNetPayoutCents,
    required this.reason,
    required this.status,
    required this.requestedByUid,
    required this.reviewedByUid,
    required this.createdAt,
    required this.updatedAt,
  });

  static WithdrawRequest fromBackendMap(Map<String, dynamic> json) {
    final amountCents = json['requestedAmountCents'] == null
        ? _toInt(json['amountCents'])
        : _toInt(json['requestedAmountCents']);
    final computedPreview = WithdrawPreview.calculate(amountCents);
    final approvalFeeCents = _toInt(json['approvalFeeCents']);
    final approvedNetPayoutCents = _toInt(json['approvedNetPayoutCents']);

    return WithdrawRequest(
      id: (json['id'] as String?) ?? '',
      customerId: (json['customerId'] as String?) ?? '',
      walletId: json['walletId'] as String?,
      amountCents: amountCents,
      feeCents: json['feeCents'] == null
          ? (json['approvalFeeCents'] == null
                ? computedPreview.feeCents
                : approvalFeeCents)
          : _toInt(json['feeCents']),
      netPayoutCents: json['netPayoutCents'] == null
          ? (json['approvedNetPayoutCents'] == null
                ? computedPreview.netPayoutCents
                : approvedNetPayoutCents)
          : _toInt(json['netPayoutCents']),
      approvalFeeCents: approvalFeeCents,
      approvedNetPayoutCents: approvedNetPayoutCents,
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

  WithdrawPreview get preview => WithdrawPreview(
    requestedAmountCents: amountCents,
    feeCents: feeCents,
    netPayoutCents: netPayoutCents,
  );
}

/// Wallet operational status from API payloads (`ACTIVE` / `FROZEN` / `CLOSED`).
///
/// Does not default missing values to Active (that hid real FROZEN/CLOSED in UI).
String parseWalletOperationalStatus(Map<String, dynamic> json) {
  final raw = json['status'] ?? json['walletStatus'];
  if (raw == null) return 'UNKNOWN';
  final s = raw.toString().trim();
  if (s.isEmpty) return 'UNKNOWN';
  final u = s.toUpperCase().replaceAll('-', '_');
  switch (u) {
    case 'ACTIVE':
      return 'ACTIVE';
    case 'FROZEN':
      return 'FROZEN';
    case 'CLOSED':
      return 'CLOSED';
    default:
      return u;
  }
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// Backend sends UTC ISO-8601 (e.g. `...Z`). Keep as UTC for stable EAT display.
DateTime? _parseDateTime(Object? value) {
  if (value is DateTime) return value.toUtc();
  if (value is String && value.isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    if (parsed.isUtc) return parsed;
    // Offset form `+00:00` etc.: normalize to UTC.
    return parsed.toUtc();
  }
  return null;
}

/// Riverpod family key: [walletId] null means primary wallet on the server.
typedef WalletFamilyKey = ({String customerId, String? walletId});
