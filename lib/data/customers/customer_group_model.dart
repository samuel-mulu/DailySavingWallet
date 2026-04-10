class CustomerGroupSummary {
  final String id;
  final String name;
  final int customerCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomerGroupSummary({
    required this.id,
    required this.name,
    required this.customerCount,
    required this.createdAt,
    required this.updatedAt,
  });

  static CustomerGroupSummary fromBackendMap(Map<String, dynamic> json) {
    return CustomerGroupSummary(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      customerCount: _toInt(json['customerCount']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }
}

class CustomerGroupListResult {
  final List<CustomerGroupSummary> groups;
  final int unassignedCustomerCount;

  const CustomerGroupListResult({
    required this.groups,
    required this.unassignedCustomerCount,
  });
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
