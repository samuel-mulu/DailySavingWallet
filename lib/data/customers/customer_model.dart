import 'customer_media.dart';
import 'customer_group_model.dart';

/// Canonical lifecycle values stored on [Customer.status] (lowercase snake).
abstract final class CustomerLifecycleStatus {
  static const String active = 'active';
  static const String onHold = 'on_hold';
  static const String frozen = 'frozen';
  static const String deactive = 'deactive';

  static const List<String> all = [active, onHold, frozen, deactive];

  /// Uppercase enum string for query/body payloads (e.g. [CustomerApi]).
  static String toApiValue(String canonical) {
    switch (canonical) {
      case active:
        return 'ACTIVE';
      case onHold:
        return 'ON_HOLD';
      case frozen:
        return 'FROZEN';
      case deactive:
        return 'DEACTIVE';
      default:
        return 'ACTIVE';
    }
  }

  static String displayLabel(String canonical) {
    switch (canonical) {
      case active:
        return 'Active';
      case onHold:
        return 'On hold';
      case frozen:
        return 'Frozen';
      case deactive:
        return 'Inactive';
      default:
        if (canonical.isEmpty) return 'Unknown';
        return canonical
            .split('_')
            .map(
              (w) => w.isEmpty
                  ? w
                  : '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1).toLowerCase() : ''}',
            )
            .join(' ');
    }
  }
}

class Customer {
  final String customerId;
  final String fullName;
  final String phone;
  final String companyName;
  final String address;
  final String email;
  final int dailyTargetCents;
  final int creditLimitCents;
  final String status;
  final DateTime? createdAt;
  final String createdByUid;
  final CustomerMedia media;
  final CustomerGroupSummary? group;

  /// Balance from list endpoint when present (avoids per-row wallet GET).
  final int balanceCents;

  const Customer({
    required this.customerId,
    required this.fullName,
    required this.phone,
    required this.companyName,
    required this.address,
    required this.email,
    required this.dailyTargetCents,
    required this.creditLimitCents,
    required this.status,
    required this.createdAt,
    required this.createdByUid,
    required this.media,
    required this.group,
    this.balanceCents = 0,
  });

  static Customer fromBackendMap(Map<String, dynamic> json) {
    final rawMedia = json['media'];
    return Customer(
      customerId:
          (json['id'] as String?) ?? (json['customerId'] as String?) ?? '',
      fullName: (json['fullName'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      companyName: (json['companyName'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      dailyTargetCents: _toInt(json['dailyTargetCents']),
      creditLimitCents: _toInt(json['creditLimitCents']),
      status: _normalizeStatus(json['status']),
      createdAt: _parseDateTime(json['createdAt']),
      createdByUid:
          (json['createdByUserId'] as String?) ??
          (json['createdByUid'] as String?) ??
          '',
      media: CustomerMedia.fromMap(
        rawMedia is Map
            ? rawMedia.map((key, value) => MapEntry('$key', value))
            : null,
      ),
      group: _parseGroup(json['group']),
      balanceCents: _toInt(json['balanceCents']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phone': phone,
      'companyName': companyName,
      'address': address,
      'email': email,
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

  String get groupName => group?.name ?? 'Not assigned';
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

String _normalizeStatus(Object? value) {
  final raw = (value as String?)?.trim();
  if (raw == null || raw.isEmpty) return CustomerLifecycleStatus.active;
  final upper = raw.toUpperCase().replaceAll('-', '_');
  switch (upper) {
    case 'ACTIVE':
      return CustomerLifecycleStatus.active;
    case 'ON_HOLD':
      return CustomerLifecycleStatus.onHold;
    case 'FROZEN':
      return CustomerLifecycleStatus.frozen;
    case 'DEACTIVE':
    case 'INACTIVE':
      return CustomerLifecycleStatus.deactive;
    default:
      if (raw.toLowerCase() == 'inactive') {
        return CustomerLifecycleStatus.deactive;
      }
      final snake = raw.toLowerCase().replaceAll('-', '_');
      if (CustomerLifecycleStatus.all.contains(snake)) {
        return snake;
      }
      // Do not coerce unknown server values to Active (misleading in admin UI).
      return snake;
  }
}

CustomerGroupSummary? _parseGroup(Object? value) {
  if (value is Map<String, dynamic>) {
    return CustomerGroupSummary.fromBackendMap(value);
  }
  if (value is Map) {
    return CustomerGroupSummary.fromBackendMap(
      value.map((key, item) => MapEntry('$key', item)),
    );
  }
  return null;
}
