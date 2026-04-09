import 'dart:async';

import '../../../data/api/auth_api.dart';

abstract class AuthClient {
  Stream<String?> authUidChanges();

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();
}

class NodeAuthClient implements AuthClient {
  NodeAuthClient({required AuthApi authApi}) : _authApi = authApi {
    _stream = _createSessionStream();
  }

  final AuthApi _authApi;
  late final Stream<String?> _stream;

  Stream<String?> _createSessionStream() {
    return Stream<String?>.multi((emitter) async {
      emitter.add(await _readUidOrNull());
      await for (final uid in _updates.stream) {
        emitter.add(uid);
      }
    });
  }

  final _updates = StreamController<String?>.broadcast();

  @override
  Stream<String?> authUidChanges() => _stream;

  Future<String?> _readUidOrNull() async {
    try {
      final me = await _authApi.fetchMe();
      return me.userId.isEmpty ? null : me.userId;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _authApi.login(email: email, password: password);
    final me = await _authApi.fetchMe();
    _updates.add(me.userId.isEmpty ? null : me.userId);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _authApi.requestPasswordReset(email: email);
  }

  @override
  Future<void> signOut() async {
    await _authApi.logoutBackendSession();
    _updates.add(null);
  }
}
