import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App preferences, remembered on this device between sessions.
class SettingsState extends ChangeNotifier {
  static const _kNotifications = 'pref_notifications';
  static const _kAutoSave = 'pref_auto_save';
  static const _kDarkMode = 'pref_dark_mode';

  /// Scans at or above this confidence are saved to the library automatically
  /// when "Auto-save to library" is on.
  static const int autoSaveThreshold = 90;

  bool _notifications = true;
  bool _autoSave = false;
  bool _darkMode = false;

  bool get notifications => _notifications;
  bool get autoSave => _autoSave;
  bool get darkMode => _darkMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _notifications = prefs.getBool(_kNotifications) ?? true;
    _autoSave = prefs.getBool(_kAutoSave) ?? false;
    _darkMode = prefs.getBool(_kDarkMode) ?? false;
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    _notifications = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifications, value);
  }

  Future<void> setAutoSave(bool value) async {
    _autoSave = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoSave, value);
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkMode, value);
  }
}