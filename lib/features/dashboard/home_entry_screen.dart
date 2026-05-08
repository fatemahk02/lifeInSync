import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../shared/services/app_preferences_service.dart';
import '../../shared/services/fastapi_service.dart';
import '../../shared/services/firestore_service.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'main_shell.dart';

class HomeEntryScreen extends StatelessWidget {
  const HomeEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const LoginScreen();
    }

    return FutureBuilder<bool>(
      future: _resolveOnboarding(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final done = snapshot.data ?? false;
        if (done) return const MainShell();
        return const OnboardingScreen();
      },
    );
  }

  Future<bool> _resolveOnboarding(String uid) async {
    try {
      await FirestoreService.instance.removeLegacyRoleField(uid);
    } catch (_) {}

    final local = await AppPreferencesService.instance.isOnboardingComplete(uid);

    try {
      final profile = await FastApiService.instance
          .getUserProfile(uid: uid)
          .timeout(const Duration(seconds: 6));

      await AppPreferencesService.instance.setDailyLimitHours(
        uid,
        profile.preferences.dailyScreenLimitMinutes / 60,
      );
      await AppPreferencesService.instance.setNotificationsEnabled(
        uid,
        profile.preferences.notificationsEnabled,
      );
      await AppPreferencesService.instance.setThemeMode(
        _themeFromString(profile.preferences.theme),
      );

      if (profile.preferences.onboardingCompleted && !local) {
        await AppPreferencesService.instance.setOnboardingComplete(uid, true);
      }

      return local || profile.preferences.onboardingCompleted;
    } catch (_) {}

    try {
      final profile = await FirestoreService.instance.getUserProfile(uid);
      final prefs = (profile?['preferences'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final remoteDone = (prefs['onboardingCompleted'] as bool?) ?? false;

      final limitMinutes = (prefs['dailyScreenLimitMinutes'] as num?)?.toInt();
      if (limitMinutes != null) {
        await AppPreferencesService.instance.setDailyLimitHours(
          uid,
          limitMinutes / 60,
        );
      }

      if (remoteDone && !local) {
        await AppPreferencesService.instance.setOnboardingComplete(uid, true);
      }
      return local || remoteDone;
    } catch (_) {
      return local;
    }
  }

  ThemeMode _themeFromString(String raw) {
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }
}
