import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/backend_feature_flags.dart';
import '../routing/app_navigator_key.dart';

/// Combines device connectivity, optional `GET /health` probes, and [ApiClient] transport outcomes.
///
/// Recovery sound respects the platform (may be silent when the device is muted).
class ReachabilityHost extends ChangeNotifier {
  ReachabilityHost._();

  static final ReachabilityHost instance = ReachabilityHost._();

  final Connectivity _connectivity = Connectivity();
  final http.Client _probeClient = http.Client();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _initialized = false;
  bool _deviceOnline = true;
  bool? _serverReachable;
  String? _lastServerError;
  DateTime? _lastChecked;
  Future<void>? _probeInFlight;
  DateTime? _lastFailNotifyAt;

  bool get deviceOnline => _deviceOnline;

  /// `null` until first probe or API outcome while the device is online.
  bool? get serverReachable => _serverReachable;

  String? get lastServerError => _lastServerError;

  DateTime? get lastChecked => _lastChecked;

  static bool _resultsOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  void init() {
    if (_initialized) return;
    _initialized = true;
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      (results) => unawaited(_onConnectivityResults(results)),
    );
    scheduleMicrotask(() async {
      await _syncDeviceFromSystem();
      await probeServer();
    });
  }

  Future<void> _onConnectivityResults(List<ConnectivityResult> results) async {
    final online = _resultsOnline(results);
    final wasOnline = _deviceOnline;
    _deviceOnline = online;
    if (!online) {
      _serverReachable = null;
      _lastServerError = null;
      notifyListeners();
      return;
    }
    notifyListeners();
    if (!wasOnline && online) {
      await probeServer();
    }
  }

  Future<void> _syncDeviceFromSystem() async {
    final results = await _connectivity.checkConnectivity();
    _deviceOnline = _resultsOnline(results);
    notifyListeners();
  }

  /// Public health check (e.g. pull-to-retry, app resume).
  Future<void> probeServer() async {
    if (!_deviceOnline) return;
    if (_probeInFlight != null) {
      await _probeInFlight;
      return;
    }
    final run = _runHealthProbe();
    _probeInFlight = run;
    try {
      await run;
    } finally {
      _probeInFlight = null;
    }
  }

  Future<void> _runHealthProbe() async {
    try {
      final uri = BackendFeatureFlags.healthCheckUri;
      final res = await _probeClient
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 5));
      _lastChecked = DateTime.now();
      if (res.statusCode != 200) {
        _applyServerUnreachable('HTTP ${res.statusCode}');
        return;
      }
      final ok = _parseHealthOk(res.body);
      if (ok) {
        _applyServerOk();
      } else {
        _applyServerUnreachable('Unexpected health response');
      }
    } catch (e) {
      _lastChecked = DateTime.now();
      _applyServerUnreachable(_shortError(e));
    }
  }

  bool _parseHealthOk(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return false;
      final data = decoded['data'];
      return data is Map && data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  void notifyApiTransportFailure(Object error) {
    if (!_deviceOnline) return;
    _lastChecked = DateTime.now();
    final wasReachable = _serverReachable != false;
    _serverReachable = false;
    _lastServerError = _shortError(error);
    if (wasReachable) {
      notifyListeners();
    } else {
      _notifyDebouncedFailure();
    }
  }

  void notifyApiSuccess() {
    if (!_deviceOnline) return;
    final wasUnreachable = _serverReachable == false;
    final prev = _serverReachable;
    _serverReachable = true;
    _lastServerError = null;
    _lastChecked = DateTime.now();
    if (wasUnreachable) {
      _playRecoveryFeedback();
    }
    if (prev != true) {
      notifyListeners();
    }
  }

  void _applyServerUnreachable(String message) {
    final wasReachable = _serverReachable != false;
    _serverReachable = false;
    _lastServerError = message;
    if (wasReachable) {
      notifyListeners();
    } else {
      _notifyDebouncedFailure();
    }
  }

  void _applyServerOk() {
    final wasUnreachable = _serverReachable == false;
    final prev = _serverReachable;
    _serverReachable = true;
    _lastServerError = null;
    if (wasUnreachable) {
      _playRecoveryFeedback();
    }
    if (prev != true) {
      notifyListeners();
    }
  }

  void _notifyDebouncedFailure() {
    final now = DateTime.now();
    if (_lastFailNotifyAt != null &&
        now.difference(_lastFailNotifyAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastFailNotifyAt = now;
    notifyListeners();
  }

  void _playRecoveryFeedback() {
    unawaited(SystemSound.play(SystemSoundType.click));
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(
        content: Text('Back online — server is responding.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _shortError(Object e) {
    if (e is SocketException) {
      return 'No connection (${e.message})';
    }
    if (e is http.ClientException) {
      final m = e.message;
      return m.isNotEmpty ? m : 'Network error';
    }
    if (e is TimeoutException) {
      return 'Request timed out';
    }
    final s = e.toString();
    if (s.length > 120) {
      return '${s.substring(0, 117)}...';
    }
    return s;
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
