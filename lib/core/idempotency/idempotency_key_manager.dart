import 'package:uuid/uuid.dart';

/// Keeps idempotency keys stable per logical action until explicitly cleared.
class IdempotencyKeyManager {
  IdempotencyKeyManager({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  final Map<String, String> _keysByAction = <String, String>{};

  String keyFor(String actionId) {
    final existing = _keysByAction[actionId];
    if (existing != null) return existing;
    final key = _uuid.v4();
    _keysByAction[actionId] = key;
    return key;
  }

  String? peek(String actionId) => _keysByAction[actionId];

  void clear(String actionId) {
    _keysByAction.remove(actionId);
  }

  void clearAll() {
    _keysByAction.clear();
  }
}
