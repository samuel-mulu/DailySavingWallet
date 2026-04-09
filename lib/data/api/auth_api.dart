import 'api_client.dart';

class BackendAuthSession {
  final String accessToken;
  final String refreshToken;
  final BackendMe user;

  const BackendAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });
}

class BackendMe {
  final String userId;
  final String email;
  final String role;
  final String status;
  final String? customerId;

  const BackendMe({
    required this.userId,
    required this.email,
    required this.role,
    required this.status,
    required this.customerId,
  });
}

class AuthApi {
  final ApiClient _client;
  final BackendSessionStore _sessionStore;

  AuthApi({ApiClient? client, BackendSessionStore? sessionStore})
    : _sessionStore = sessionStore ?? const BackendSessionStore(),
      _client = client ?? ApiClient(sessionStore: sessionStore);

  Future<BackendAuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.postJson(
      '/auth/login',
      requiresAuth: false,
      body: {'email': email.trim(), 'password': password},
    );

    final accessToken = (data['accessToken'] as String?) ?? '';
    final refreshToken = (data['refreshToken'] as String?) ?? '';
    final user = _parseUser(asJsonMap(data['user'], fieldName: 'user'));

    await _sessionStore.saveSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    return BackendAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
    );
  }

  Future<BackendMe> fetchMe() async {
    final data = await _client.getJson('/auth/me');
    return _parseUser(asJsonMap(data['user'], fieldName: 'user'));
  }

  /// Optional [newPassword] when backend returns a dev-only reset token from
  /// [requestPasswordReset].
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _client.postJson(
      '/auth/reset-password',
      requiresAuth: false,
      body: {'token': token, 'newPassword': newPassword},
    );
  }

  Future<PasswordResetResponse> requestPasswordReset({
    required String email,
  }) async {
    final data = await _client.postJson(
      '/auth/forgot-password',
      requiresAuth: false,
      body: {'email': email.trim()},
    );
    final token = data['resetToken'] as String?;
    return PasswordResetResponse(resetToken: token);
  }

  Future<void> logoutBackendSession() async {
    try {
      await _client.postJson('/auth/logout', body: const <String, dynamic>{});
    } on BackendAuthUnavailableException {
      // No session is fine during teardown.
    } finally {
      await _sessionStore.clear();
    }
  }

  BackendMe _parseUser(Map<String, dynamic> user) {
    return BackendMe(
      userId: (user['id'] as String?) ?? '',
      email: (user['email'] as String?) ?? '',
      role: ((user['role'] as String?) ?? 'CUSTOMER').toLowerCase(),
      status: ((user['status'] as String?) ?? 'ACTIVE').toLowerCase(),
      customerId: user['customerId'] as String?,
    );
  }
}

class PasswordResetResponse {
  final String? resetToken;

  const PasswordResetResponse({this.resetToken});
}
