import 'package:flutter/material.dart';

const String defaultGroupColorHex = '#8B5CF6';
const String unassignedGroupColorHex = '#6B7280';

const Color defaultGroupColor = Color(0xFF8B5CF6);
const Color unassignedGroupColor = Color(0xFF6B7280);

const List<String> groupColorPalette = <String>[
  '#8B5CF6',
  '#6366F1',
  '#3B82F6',
  '#0EA5E9',
  '#06B6D4',
  '#14B8A6',
  '#10B981',
  '#22C55E',
  '#84CC16',
  '#EAB308',
  '#F59E0B',
  '#F97316',
  '#EF4444',
  '#E11D48',
  '#EC4899',
  '#D946EF',
];

final RegExp _groupColorHexPattern = RegExp(r'^#[0-9A-F]{6}$');

String normalizeGroupColorHex(
  String? colorHex, {
  String fallback = defaultGroupColorHex,
}) {
  final normalized = tryNormalizeGroupColorHex(colorHex);
  return normalized ?? fallback;
}

String? tryNormalizeGroupColorHex(String? colorHex) {
  final raw = (colorHex ?? '').trim().toUpperCase();
  if (!_groupColorHexPattern.hasMatch(raw)) {
    return null;
  }
  return raw;
}

Color groupColorFromHex(
  String? colorHex, {
  Color fallback = defaultGroupColor,
}) {
  final normalized = tryNormalizeGroupColorHex(colorHex);
  if (normalized == null) {
    return fallback;
  }
  final value = int.parse(normalized.substring(1), radix: 16);
  return Color(0xFF000000 | value);
}

List<String> availableGroupColorHexes({
  required Iterable<String?> usedColorHexes,
  Iterable<String?> reservedColorHexes = const <String>[
    unassignedGroupColorHex,
  ],
  Iterable<String?> allowedColorHexes = const <String>[],
}) {
  final blocked = <String>{
    ..._normalizeGroupColorSet(usedColorHexes),
    ..._normalizeGroupColorSet(reservedColorHexes),
  }..removeAll(_normalizeGroupColorSet(allowedColorHexes));

  return groupColorPalette
      .where((colorHex) => !blocked.contains(colorHex))
      .toList(growable: false);
}

Set<String> unavailablePaletteGroupColorHexes({
  required Iterable<String?> usedColorHexes,
  Iterable<String?> reservedColorHexes = const <String>[
    unassignedGroupColorHex,
  ],
  Iterable<String?> allowedColorHexes = const <String>[],
}) {
  final available = availableGroupColorHexes(
    usedColorHexes: usedColorHexes,
    reservedColorHexes: reservedColorHexes,
    allowedColorHexes: allowedColorHexes,
  );
  if (available.isEmpty) {
    return <String>{};
  }
  return groupColorPalette
      .where((colorHex) => !available.contains(colorHex))
      .toSet();
}

String preferredGroupColorHex({
  required Iterable<String?> usedColorHexes,
  String? preferredColorHex,
  Iterable<String?> reservedColorHexes = const <String>[
    unassignedGroupColorHex,
  ],
  Iterable<String?> allowedColorHexes = const <String>[],
}) {
  final normalizedPreferred = tryNormalizeGroupColorHex(preferredColorHex);
  final allowed = _normalizeGroupColorSet(allowedColorHexes);
  final available = availableGroupColorHexes(
    usedColorHexes: usedColorHexes,
    reservedColorHexes: reservedColorHexes,
    allowedColorHexes: allowedColorHexes,
  );

  if (normalizedPreferred != null &&
      (allowed.contains(normalizedPreferred) ||
          available.contains(normalizedPreferred))) {
    return normalizedPreferred;
  }
  if (available.isNotEmpty) {
    return available.first;
  }
  return normalizedPreferred ?? defaultGroupColorHex;
}

Set<String> _normalizeGroupColorSet(Iterable<String?> colorHexes) {
  final normalized = <String>{};
  for (final colorHex in colorHexes) {
    final value = tryNormalizeGroupColorHex(colorHex);
    if (value != null) {
      normalized.add(value);
    }
  }
  return normalized;
}
