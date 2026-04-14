import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/idempotency/idempotency_key_manager.dart';

void main() {
  group('IdempotencyKeyManager', () {
    test('same action reuses same key', () {
      final manager = IdempotencyKeyManager();

      final first = manager.keyFor('action-1');
      final second = manager.keyFor('action-1');

      expect(second, first);
    });

    test('clear removes key and next call gets new key', () {
      final manager = IdempotencyKeyManager();

      final first = manager.keyFor('action-1');
      manager.clear('action-1');
      final second = manager.keyFor('action-1');

      expect(second, isNot(first));
    });
  });
}
