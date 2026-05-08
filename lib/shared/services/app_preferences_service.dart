import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesService {
  AppPreferencesService._();

  static final AppPreferencesService instance = AppPreferencesService._();

  static const _keyThemeMode = 'theme_mode';
  static const _keyLocaleCode = 'locale_code';
  static const _keyAuthLocaleCode = 'auth_locale_code';
  static const _keyOnboardingPrefix = 'onboarding_done_';
  static const _keyLimitPrefix = 'daily_limit_hours_';
  static const _keyNotificationsPrefix = 'notifications_enabled_';
  static const _keyFocusPomodoroPrefix = 'focus_pomodoro_minutes_';
  static const _keyFocusDeepWorkPrefix = 'focus_deep_work_minutes_';
  static const _keyFocusFlowStatePrefix = 'focus_flow_state_minutes_';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);
  final ValueNotifier<Locale?> authLocale = ValueNotifier<Locale?>(null);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyThemeMode) ?? 'light';
    themeMode.value = _decodeThemeMode(saved);
    final localeCode = prefs.getString(_keyLocaleCode);
    if (localeCode != null && localeCode.isNotEmpty) {
      locale.value = Locale(localeCode);
    }

    final authLocaleCode = prefs.getString(_keyAuthLocaleCode);
    if (authLocaleCode != null && authLocaleCode.isNotEmpty) {
      authLocale.value = Locale(authLocaleCode);
    }
  }

  Future<void> setLocaleCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocaleCode, code);
    locale.value = Locale(code);
  }

  Future<void> clearLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLocaleCode);
    locale.value = null;
  }

  Future<void> setAuthLocaleCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAuthLocaleCode, code);
    authLocale.value = Locale(code);
  }

  Future<void> clearAuthLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthLocaleCode);
    authLocale.value = null;
  }

  Future<bool> isOnboardingComplete(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_keyOnboardingPrefix$uid') ?? false;
  }

  Future<void> setOnboardingComplete(String uid, bool done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyOnboardingPrefix$uid', done);
  }

  Future<double> getDailyLimitHours(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_keyLimitPrefix$uid') ?? 6.0;
  }

  Future<void> setDailyLimitHours(String uid, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_keyLimitPrefix$uid', value);
  }

  Future<bool> getNotificationsEnabled(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_keyNotificationsPrefix$uid') ?? true;
  }

  Future<void> setNotificationsEnabled(String uid, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyNotificationsPrefix$uid', value);
  }

  Future<int> getPomodoroMinutes(String uid, {int fallback = 25}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyFocusPomodoroPrefix$uid') ?? fallback;
  }

  Future<void> setPomodoroMinutes(String uid, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_keyFocusPomodoroPrefix$uid', minutes);
  }

  Future<int> getDeepWorkMinutes(String uid, {int fallback = 50}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyFocusDeepWorkPrefix$uid') ?? fallback;
  }

  Future<void> setDeepWorkMinutes(String uid, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_keyFocusDeepWorkPrefix$uid', minutes);
  }

  Future<int> getFlowStateMinutes(String uid, {int fallback = 90}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyFocusFlowStatePrefix$uid') ?? fallback;
  }

  Future<void> setFlowStateMinutes(String uid, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_keyFocusFlowStatePrefix$uid', minutes);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, _encodeThemeMode(mode));
    themeMode.value = mode;
  }

  static ThemeMode _decodeThemeMode(String mode) {
    switch (mode) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  static String _encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }
}
