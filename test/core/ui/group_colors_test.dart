import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/ui/group_colors.dart';

void main() {
  group('group color helpers', () {
    test('preferred color skips colors that are already used', () {
      final colorHex = preferredGroupColorHex(
        usedColorHexes: const <String>['#8B5CF6', '#6366F1', '#3B82F6'],
        preferredColorHex: '#8B5CF6',
      );

      expect(colorHex, '#0EA5E9');
    });

    test('rename keeps the group current color available', () {
      final colorHex = preferredGroupColorHex(
        usedColorHexes: const <String>['#8B5CF6', '#6366F1'],
        preferredColorHex: '#6366F1',
        allowedColorHexes: const <String>['#6366F1'],
      );

      expect(colorHex, '#6366F1');
    });

    test('reserved unassigned color is never offered from the palette', () {
      final available = availableGroupColorHexes(
        usedColorHexes: const <String>[],
        reservedColorHexes: const <String>[unassignedGroupColorHex],
      );

      expect(available, isNot(contains(unassignedGroupColorHex)));
    });

    test('invalid colors fall back safely for rendering', () {
      expect(groupColorFromHex('oops'), defaultGroupColor);
      expect(groupColorFromHex('#112233'), const Color(0xFF112233));
    });
  });
}
