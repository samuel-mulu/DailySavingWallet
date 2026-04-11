/// Compile-time configuration for the Node API client.
class BackendFeatureFlags {
  static const String _localApiBaseUrl = 'http://127.0.0.1:4000/api/v1';
  static const String _productionApiBaseUrl =
      'https://backend-for-mahtot.onrender.com/api/v1';
  static const bool _isReleaseBuild = bool.fromEnvironment('dart.vm.product');

  static const String apiBaseUrl = String.fromEnvironment(
    'NODE_API_BASE_URL',
    defaultValue: _isReleaseBuild ? _productionApiBaseUrl : _localApiBaseUrl,
  );

  /// `GET /health` on the API host (not under `/api/v1`). Used for wake-up probes.
  static Uri get healthCheckUri {
    final trimmed = apiBaseUrl.trim();
    if (trimmed.isEmpty) {
      return Uri.parse('http://127.0.0.1:4000/health');
    }
    final base = Uri.parse(trimmed);
    if (!base.hasScheme || base.host.isEmpty) {
      return Uri.parse('http://127.0.0.1:4000/health');
    }
    return base.replace(path: '/health', query: null);
  }

  static const bool enableNodeReadLogging = bool.fromEnvironment(
    'ENABLE_NODE_READ_LOGGING',
    defaultValue: false,
  );
}
