import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Calendar display mode - determines how dates are formatted and picked.
enum CalendarMode { gregorian, ethiopian }

/// Service for managing calendar mode preference.
/// Extends ValueNotifier so widgets can listen to changes.
class CalendarModeService extends ValueNotifier<CalendarMode> {
  static const _key = 'calendarMode';
  static CalendarModeService? _instance;
  static SharedPreferences? _prefs;

  CalendarModeService._(super.value);

  static Future<CalendarModeService> getInstance() async {
    if (_instance == null) {
      _prefs = await SharedPreferences.getInstance();
      final savedMode = _loadMode();
      _instance = CalendarModeService._(savedMode);
    }
    return _instance!;
  }

  static CalendarMode _loadMode() {
    final value = _prefs?.getString(_key);
    if (value == 'ethiopian') {
      return CalendarMode.ethiopian;
    }
    return CalendarMode.gregorian;
  }

  /// Get current calendar mode (synchronously accessing value).
  CalendarMode getMode() => value;

  /// Save calendar mode to local storage and notify listeners.
  Future<void> setMode(CalendarMode mode) async {
    value = mode; // Notify listeners
    await _prefs?.setString(
      _key,
      mode == CalendarMode.ethiopian ? 'ethiopian' : 'gregorian',
    );
  }
}
