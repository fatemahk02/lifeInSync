import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../shared/services/app_preferences_service.dart';
import '../../shared/services/fastapi_service.dart';
import '../../shared/services/firestore_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  double _dailyLimit = 6;
  bool _notificationsEnabled = true;
  ThemeMode _themeMode = ThemeMode.light;
  String _languageCode = 'en';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;

    final prefs = AppPreferencesService.instance;
    final limit = await prefs.getDailyLimitHours(uid);
    final notif = await prefs.getNotificationsEnabled(uid);

    if (!mounted) return;
    setState(() {
      _dailyLimit = limit;
      _notificationsEnabled = notif;
      _themeMode = prefs.themeMode.value;
      _languageCode = prefs.locale.value?.languageCode ?? 'en';
      _loading = false;
    });
  }

  Future<void> _saveLimit(double v) async {
    final uid = _uid;
    if (uid == null) return;
    _dailyLimit = v;
    await AppPreferencesService.instance.setDailyLimitHours(uid, v);
    try {
      await FastApiService.instance.upsertUserProfile(
        uid: uid,
        dailyScreenLimitMinutes: (v * 60).round(),
      );
    } catch (_) {
      await FirestoreService.instance.updateUserPreferences(
        uid: uid,
        dailyScreenLimitMinutes: (v * 60).round(),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveNotifications(bool enabled) async {
    final uid = _uid;
    if (uid == null) return;
    setState(() => _notificationsEnabled = enabled);
    await AppPreferencesService.instance.setNotificationsEnabled(uid, enabled);
    try {
      await FastApiService.instance.upsertUserProfile(
        uid: uid,
        notificationsEnabled: enabled,
      );
    } catch (_) {
      await FirestoreService.instance.updateUserPreferences(
        uid: uid,
        notificationsEnabled: enabled,
      );
    }
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await AppPreferencesService.instance.setThemeMode(mode);
    final uid = _uid;
    if (uid != null) {
      try {
        await FastApiService.instance.upsertUserProfile(
          uid: uid,
          theme: mode.name,
        );
      } catch (_) {
        await FirestoreService.instance.updateUserPreferences(
          uid: uid,
          theme: mode.name,
        );
      }
    }
  }

  Future<void> _saveLanguage(String code) async {
    setState(() => _languageCode = code);
    await AppPreferencesService.instance.setLocaleCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = context.l10n;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(title: Text(t.tr('settings'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _sectionCard(
                  context: context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.tr('dailyScreenLimit'), style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text('${_dailyLimit.toStringAsFixed(0)}h', style: Theme.of(context).textTheme.headlineSmall),
                      Slider(
                        value: _dailyLimit,
                        min: 1,
                        max: 12,
                        divisions: 11,
                        onChanged: (v) => setState(() => _dailyLimit = v),
                        onChangeEnd: _saveLimit,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  context: context,
                  child: SwitchListTile(
                    value: _notificationsEnabled,
                    onChanged: _saveNotifications,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.tr('notifications')),
                    subtitle: Text(t.tr('notificationsSubtitle')),
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  context: context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.tr('theme')),
                      const SizedBox(height: 8),
                      SegmentedButton<ThemeMode>(
                        segments: [
                          ButtonSegment(value: ThemeMode.light, label: Text(t.tr('light'))),
                          ButtonSegment(value: ThemeMode.dark, label: Text(t.tr('dark'))),
                          ButtonSegment(value: ThemeMode.system, label: Text(t.tr('system'))),
                        ],
                        selected: {_themeMode},
                        onSelectionChanged: (v) => _saveTheme(v.first),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  context: context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.tr('language')),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _languageCode,
                        items: [
                          DropdownMenuItem(value: 'en', child: Text(t.tr('english'))),
                          DropdownMenuItem(value: 'hi', child: Text(t.tr('hindi'))),
                          DropdownMenuItem(value: 'gu', child: Text(t.tr('gujarati'))),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            _saveLanguage(v);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionCard({required BuildContext context, required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? null
            : [
                const BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }
}
