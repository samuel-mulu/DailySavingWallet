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

  static const bool enableNodeReadLogging = bool.fromEnvironment(
    'ENABLE_NODE_READ_LOGGING',
    defaultValue: false,
  );
}
