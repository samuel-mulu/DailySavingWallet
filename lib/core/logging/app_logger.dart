import 'package:flutter/foundation.dart';

final class AppLogger {
  AppLogger._();

  static void debug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void info(String message) {
    debugPrint('[INFO] $message');
  }

  static void warn(String message, [Object? error]) {
    debugPrint('[WARN] $message');
    if (error != null) {
      debugPrint('$error');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[ERROR] $message');
    if (error != null) {
      debugPrint('$error');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint('$stackTrace');
    }
  }
}
