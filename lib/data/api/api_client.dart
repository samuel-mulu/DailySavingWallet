import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../core/config/backend_feature_flags.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/reachability_host.dart';

class BackendApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final Object? details;

  const BackendApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => message;

  /// Zod [flatten](https://zod.dev/ERROR_HANDLING) `fieldErrors` from a 422 body.
  Map<String, String> get zodFieldErrors {
    final d = details;
    if (d is! Map) return const {};
    final raw = d['fieldErrors'];
    if (raw is! Map) return const {};
    final out = <String, String>{};
    for (final entry in raw.entries) {
      final msgs = entry.value;
      if (msgs is List && msgs.isNotEmpty) {
        out['${entry.key}'] = msgs.map((m) => '$m').join(' ');
      }
    }
    return out;
  }

  /// Top-level issues from the same flatten payload (e.g. refinements).
  List<String> get zodFormErrors {
    final d = details;
    if (d is! Map) return const [];
    final raw = d['formErrors'];
    if (raw is! List) return const [];
    return raw.map((e) => '$e').toList();
  }
}

class BackendAuthUnavailableException implements Exception {
  final String message;

  const BackendAuthUnavailableException([
    this.message = 'Backend session is not available yet.',
  ]);

  @override
  String toString() => message;
}

class BackendSessionStore {
  static const _accessTokenKey = 'backend_access_token';
  static const _refreshTokenKey = 'backend_refresh_token';

  final FlutterSecureStorage _storage;

  const BackendSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

Map<String, dynamic> asJsonMap(Object? value, {String fieldName = 'data'}) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  throw FormatException('Expected "$fieldName" to be a JSON object.');
}

List<dynamic> asJsonList(Object? value, {String fieldName = 'items'}) {
  if (value is List) {
    return value;
  }
  throw FormatException('Expected "$fieldName" to be a JSON array.');
}

class ApiClient {
  final String _baseUrl;
  final http.Client _httpClient;
  final BackendSessionStore _sessionStore;
  Future<String?>? _refreshInFlight;

  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    BackendSessionStore? sessionStore,
  }) : _baseUrl = _normalizeBaseUrl(baseUrl ?? BackendFeatureFlags.apiBaseUrl),
       _httpClient = httpClient ?? http.Client(),
       _sessionStore = sessionStore ?? const BackendSessionStore();

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, List<String>>? queryParametersAll,
    bool requiresAuth = true,
  }) async {
    final uri = _buildUri(
      path,
      queryParameters: queryParameters,
      queryParametersAll: queryParametersAll,
    );
    return _sendWithRetry(
      requiresAuth: requiresAuth,
      send: (headers) => _httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15)),
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = _buildUri(path);
    return _sendWithRetry(
      requiresAuth: requiresAuth,
      send: (headers) => _httpClient
          .post(
            uri,
            headers: {...headers, ...?extraHeaders},
            body: jsonEncode(body ?? const <String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 15)),
    );
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = _buildUri(path);
    return _sendWithRetry(
      requiresAuth: requiresAuth,
      send: (headers) => _httpClient
          .patch(
            uri,
            headers: {...headers, ...?extraHeaders},
            body: jsonEncode(body ?? const <String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 15)),
    );
  }

  Future<Map<String, String>> _buildHeaders({
    required bool requiresAuth,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final accessToken = await _ensureAccessToken(requiresAuth: requiresAuth);
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return headers;
  }

  Future<String?> _ensureAccessToken({required bool requiresAuth}) async {
    var accessToken = await _sessionStore.readAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      if (!requiresAuth) {
        return accessToken;
      }
      // Refresh before expiry so we don't spam invalid Bearer tokens (backend
      // returns 401; without this the first request after TTL used to fail).
      if (_shouldRefreshAccessToken(accessToken)) {
        final refreshed = await _refreshBackendSession();
        if (refreshed != null && refreshed.isNotEmpty) {
          return refreshed;
        }
        if (!_isAccessTokenPastExpiry(accessToken)) {
          return accessToken;
        }
        throw const BackendAuthUnavailableException();
      }
      return accessToken;
    }

    if (!requiresAuth) {
      return null;
    }

    final refreshedAccessToken = await _refreshBackendSession();
    if (refreshedAccessToken != null && refreshedAccessToken.isNotEmpty) {
      return refreshedAccessToken;
    }

    throw const BackendAuthUnavailableException();
  }

  /// JWT `exp` is seconds since epoch (UTC).
  DateTime? _accessTokenExpUtc(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1];
      final mod = payload.length % 4;
      if (mod != 0) {
        payload = payload.padRight(payload.length + (4 - mod), '=');
      }
      final json =
          jsonDecode(utf8.decode(base64Url.decode(payload))) as Object?;
      if (json is! Map<String, dynamic>) return null;
      final exp = json['exp'];
      final sec = exp is int ? exp : (exp is num ? exp.toInt() : null);
      if (sec == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }

  static const _proactiveRefreshLeeway = Duration(minutes: 2);

  bool _shouldRefreshAccessToken(String token) {
    final exp = _accessTokenExpUtc(token);
    if (exp == null) return false;
    final now = DateTime.now().toUtc();
    return !now.isBefore(exp.subtract(_proactiveRefreshLeeway));
  }

  bool _isAccessTokenPastExpiry(String token) {
    final exp = _accessTokenExpUtc(token);
    if (exp == null) return false;
    return !DateTime.now().toUtc().isBefore(exp);
  }

  Future<Map<String, dynamic>> _sendWithRetry({
    required bool requiresAuth,
    required Future<http.Response> Function(Map<String, String> headers) send,
  }) async {
    try {
      var headers = await _buildHeaders(requiresAuth: requiresAuth);
      http.Response response;
      try {
        response = await send(headers);
      } catch (e) {
        ReachabilityHost.instance.notifyApiTransportFailure(e);
        rethrow;
      }

      if (response.statusCode == 401 && requiresAuth) {
        if (BackendFeatureFlags.enableNodeReadLogging) {
          AppLogger.warn(
            '[ApiClient] Received 401 from backend, attempting refresh before retry',
          );
        }
        final refreshedAccessToken = await _refreshBackendSession();
        if (refreshedAccessToken != null && refreshedAccessToken.isNotEmpty) {
          headers = await _buildHeaders(requiresAuth: requiresAuth);
          try {
            response = await send(headers);
          } catch (e) {
            ReachabilityHost.instance.notifyApiTransportFailure(e);
            rethrow;
          }
        }
      }

      final data = _unwrapData(response);
      ReachabilityHost.instance.notifyApiSuccess();
      return data;
    } on BackendApiException {
      ReachabilityHost.instance.notifyApiSuccess();
      rethrow;
    }
  }

  Uri _buildUri(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, List<String>>? queryParametersAll,
  }) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalizedPath');
    final queryParts = <String>[
      if (queryParameters != null)
        for (final entry in queryParameters.entries)
          '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      if (queryParametersAll != null)
        for (final entry in queryParametersAll.entries)
          for (final value in entry.value)
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(value)}',
    ];

    return uri.replace(query: queryParts.isEmpty ? null : queryParts.join('&'));
  }

  Map<String, dynamic> _unwrapData(http.Response response) {
    final rawBody = response.bodyBytes.isEmpty
        ? '{}'
        : utf8.decode(response.bodyBytes);
    final decoded = rawBody.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(rawBody);
    final payload = asJsonMap(decoded, fieldName: 'response');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return asJsonMap(payload['data']);
    }

    final error = asJsonMap(payload['error'], fieldName: 'error');
    throw BackendApiException(
      statusCode: response.statusCode,
      code: (error['code'] as String?) ?? 'UNKNOWN_ERROR',
      message:
          (error['message'] as String?) ??
          'The backend returned an unexpected error.',
      details: error['details'],
    );
  }

  Future<String?> _refreshBackendSession() async {
    final inflight = _refreshInFlight;
    if (inflight != null) {
      return inflight;
    }
    final future = _performRefresh();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _sessionStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      if (BackendFeatureFlags.enableNodeReadLogging) {
        AppLogger.warn(
          '[ApiClient] Backend refresh skipped: no refresh token available',
        );
      }
      return null;
    }

    final response = await _httpClient
        .post(
          _buildUri('/auth/refresh'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (BackendFeatureFlags.enableNodeReadLogging) {
        AppLogger.warn(
          '[ApiClient] Backend refresh failed with status ${response.statusCode}; clearing stored backend session',
        );
      }
      await _sessionStore.clear();
      return null;
    }

    final data = _unwrapData(response);
    final accessToken = (data['accessToken'] as String?) ?? '';
    final nextRefreshToken = (data['refreshToken'] as String?) ?? '';
    if (accessToken.isEmpty || nextRefreshToken.isEmpty) {
      if (BackendFeatureFlags.enableNodeReadLogging) {
        AppLogger.warn(
          '[ApiClient] Backend refresh returned incomplete tokens; clearing stored backend session',
        );
      }
      await _sessionStore.clear();
      return null;
    }

    await _sessionStore.saveSession(
      accessToken: accessToken,
      refreshToken: nextRefreshToken,
    );
    if (BackendFeatureFlags.enableNodeReadLogging) {
      AppLogger.info('[ApiClient] Backend refresh succeeded');
    }
    return accessToken;
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
