import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/otp_screen.dart';
import 'features/dashboard/home_entry_screen.dart';
import 'shared/services/app_preferences_service.dart';
import 'shared/services/background_usage_sync_service.dart';
import 'shared/services/firestore_service.dart';
import 'shared/services/home_widget_service.dart';
import 'shared/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user == null) return;
    final token = await user.getIdToken();
    debugPrint('ID_TOKEN: $token');
  });
}
  await FirestoreService.instance.configureOfflinePersistence();
  if (kReleaseMode) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.debug,
    );
  } else {
    debugPrint('APP_CHECK: Skipped in debug mode for local development.');
  }

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await AppPreferencesService.instance.init();
  await NotificationService.instance.init();
  await BackgroundUsageSyncService.instance.init();
  unawaited(HomeWidgetService.instance.updateWidgetSnapshot());
  runApp(
    const ProviderScope(
      // Riverpod wrapper
      child: LifeInSyncApp(),
    ),
  );
}

class LifeInSyncApp extends StatelessWidget {
  const LifeInSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppPreferencesService.instance.themeMode,
      builder: (context, mode, _) => ValueListenableBuilder<Locale?>(
        valueListenable: AppPreferencesService.instance.locale,
        builder: (context, locale, __) {
          return MaterialApp(
            title: 'LifeInSync',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeEntryScreen(),
            routes: {
              '/otp': (_) => const OtpScreen(),
            },
          );
        },
      ),
    );
  }
}
