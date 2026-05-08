import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';

import 'firestore_service.dart';
import 'screen_time_service.dart';

class HomeWidgetService {
  HomeWidgetService._();

  static final HomeWidgetService instance = HomeWidgetService._();

  final _screenTime = ScreenTimeService.instance;
  final _firestore = FirestoreService.instance;

  Future<void> updateWidgetSnapshot() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final usage = await _screenTime.getUsageForRange(
      start: startOfDay,
      end: now,
    );
    final totalMinutes = usage.fold<int>(0, (sum, e) => sum + e.usageMinutes);
    final hours = totalMinutes / 60;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    int? wellbeing;
    if (uid != null) {
      final fatigue = await _firestore.getFatigueScoreForDate(uid, now);
      wellbeing = (100 - fatigue).clamp(0, 100);
    }

    await HomeWidget.saveWidgetData<String>(
      'daily_hours',
      hours.toStringAsFixed(1),
    );
    await HomeWidget.saveWidgetData<int>('daily_minutes', totalMinutes);
    await HomeWidget.saveWidgetData<String>(
      'wellbeing_score',
      wellbeing?.toString() ?? '--',
    );

    await HomeWidget.updateWidget(
      name: 'LifeInSyncWidgetProvider',
    );
  }
}
