import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds user preferences (notifications, theme) and persists them locally.
class SettingsController extends GetxController {
  static const _kNotifications = 'pref_notifications';
  static const _kDarkMode = 'pref_dark_mode';

  final RxBool notificationsEnabled = true.obs;
  final RxBool isDarkMode = false.obs;

  SharedPreferences? _prefs;

  /// Synchronously seed values from already-loaded prefs (called from main()
  /// before the app builds so the initial theme is correct, no flash).
  void hydrate(SharedPreferences prefs) {
    _prefs = prefs;
    notificationsEnabled.value = prefs.getBool(_kNotifications) ?? true;
    isDarkMode.value = prefs.getBool(_kDarkMode) ?? false;
  }

  ThemeMode get themeMode =>
      isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  Future<void> setNotifications(bool value) async {
    notificationsEnabled.value = value;
    await _prefs?.setBool(_kNotifications, value);
  }

  Future<void> setDarkMode(bool value) async {
    isDarkMode.value = value;
    await _prefs?.setBool(_kDarkMode, value);
    Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }
}
