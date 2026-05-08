import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../firebase_options.dart';
import '../../features/fatigue_tracker/fatigue_detector.dart';
import 'app_preferences_service.dart';
import 'firestore_service.dart';
import 'home_widget_service.dart';
import 'notification_service.dart';
import 'screen_time_service.dart';

class BackgroundUsageSyncService {
  BackgroundUsageSyncService._();

  static final BackgroundUsageSyncService instance =
      BackgroundUsageSyncService._();

  static const String taskName = 'lifeinsync_usage_sync_task';
  static const String taskUniqueName = 'lifeinsync_usage_sync_unique';

  Future<void> init() async {
    if (!Platform.isAndroid) return;

    await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
    await Workmanager().registerPeriodicTask(
      taskUniqueName,
      taskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      initialDelay: const Duration(minutes: 2),
      constraints: Constraints(networkType: NetworkType.not_required),
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final usage = await ScreenTimeService.instance.getUsageForRange(
        start: startOfDay,
        end: now,
      );

      final totalMinutes = usage.fold<int>(
        0,
        (total, item) => total + item.usageMinutes,
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final topApps = usage
            .take(10)
            .map(
              (e) => {
                'appName': e.appName,
                'packageName': e.packageName,
                'usageMinutes': e.usageMinutes,
              },
            )
            .toList(growable: false);

        await FirebaseFirestore.instance
            .collection('analytics')
            .doc(uid)
            .collection('live')
            .doc('usage')
            .set({
              'period': 'live',
              'updatedAt': FieldValue.serverTimestamp(),
              'deviceLocalUpdatedAt': Timestamp.fromDate(now),
              'totalScreenMinutesToday': totalMinutes,
              'trackedAppsCount': usage.length,
              'topApps': topApps,
            }, SetOptions(merge: true));

        await _runBackgroundNotificationChecks(
          uid: uid,
          totalMinutesToday: totalMinutes,
        );
      }
    } catch (e, st) {
      debugPrint('BG_USAGE_SYNC error: $e\n$st');
    }

    return true;
  });
}

Future<void> _runBackgroundNotificationChecks({
  required String uid,
  required int totalMinutesToday,
}) async {
  try {
    final notifications = NotificationService.instance;
    await notifications.init(requestPermissions: false);

    final dailyLimitHours = await AppPreferencesService.instance.getDailyLimitHours(uid);
    await notifications.maybeNotifyScreenTimeWarning(
      todayHours: totalMinutesToday / 60,
      dailyLimitHours: dailyLimitHours,
    );

    await notifications.maybeNotifyFocusNudge(uid: uid);

    final usage = await ScreenTimeService.instance.getFatigueUsageInputsForToday();
    final firestore = FirestoreService.instance;
    final focusCount = await firestore.getCompletedFocusSessionsToday(uid);
    final habitsCount = await firestore.getCompletedHabitsToday(uid);

    final fatigue = FatigueDetector.analyze(
      totalScreenMinutes: usage.totalScreenMinutes,
      socialMinutes: usage.socialMinutes,
      entertainmentMinutes: usage.entertainmentMinutes,
      gamingMinutes: usage.gamingMinutes,
      lateNightMinutes: usage.lateNightMinutes,
      longestSessionMinutes: usage.longestSessionMinutes,
      focusSessionsCompleted: focusCount,
      habitsCompleted: habitsCount,
    );

    await firestore.saveFatigueScore(
      uid: uid,
      date: DateTime.now(),
      score: fatigue.score,
      level: fatigue.level.name,
      breakdown: {
        'screenTimeScore': fatigue.breakdown.screenTimeScore,
        'drainingAppsScore': fatigue.breakdown.drainingAppsScore,
        'lateNightScore': fatigue.breakdown.lateNightScore,
        'longSessionScore': fatigue.breakdown.longSessionScore,
        'healthyDeduction': fatigue.breakdown.healthyDeduction,
      },
      triggers: fatigue.triggers
          .map(
            (t) => {
              'icon': t.icon,
              'text': t.text,
              'severity': t.severity.name,
            },
          )
          .toList(growable: false),
      recommendation: fatigue.recommendation,
    );

    await notifications.maybeNotifyFatigueRecommendation(
      fatigueScore: fatigue.score,
      recommendation: fatigue.recommendation,
    );

    await notifications.maybeNotifyWellbeingStatus(
      fatigueScore: fatigue.score,
      totalScreenMinutes: usage.totalScreenMinutes,
      focusSessionsCompleted: focusCount,
      habitsCompleted: habitsCount,
    );

    await notifications.maybeNotifyUsageInsights(
      uid: uid,
      fatigueScore: fatigue.score,
      totalScreenMinutes: usage.totalScreenMinutes,
      socialMinutes: usage.socialMinutes,
      entertainmentMinutes: usage.entertainmentMinutes,
      gamingMinutes: usage.gamingMinutes,
      lateNightMinutes: usage.lateNightMinutes,
      longestSessionMinutes: usage.longestSessionMinutes,
      focusSessionsCompleted: focusCount,
    );

    await HomeWidgetService.instance.updateWidgetSnapshot();
  } catch (e, st) {
    debugPrint('BG_NOTIFICATION_CHECK error: $e\n$st');
  }
}
