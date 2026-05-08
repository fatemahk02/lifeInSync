import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../firebase_options.dart';
import 'fastapi_service.dart';
import 'firestore_service.dart';

const _habitActionMarkCompleted = 'habit_mark_completed';
const _habitCategoryId = 'habit_reminder_actions';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  await NotificationService.instance.handleNotificationResponse(response);
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'lifeinsync_wellbeing';
  static const _channelName = 'LifeInSync Wellbeing';
  static const _channelDescription =
      'Habit reminders, screen time alerts, and focus nudges.';

  static const _screenWarningKey = 'notified_screen_warning_';
  static const _focusNudgeKey = 'notified_focus_nudge_';
  static const _habitIdsKeyPrefix = 'habit_notification_ids_';
  static const _fatigueLastSentKey = 'notified_fatigue_last_sent_ms';
  static const _fatigueHighDayKey = 'notified_fatigue_high_day_';
  static const _wellbeingStatusKey = 'notified_wellbeing_status_';
  static const _insightCountKey = 'notified_insight_count_';
  static const _insightSentKey = 'notified_insight_sent_';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FirestoreService _firestore = FirestoreService.instance;
  final FastApiService _fastApi = FastApiService.instance;

  bool _initialized = false;

  Future<void> init({bool requestPermissions = true}) async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          _habitCategoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              _habitActionMarkCompleted,
              'Mark as completed',
            ),
          ],
        ),
      ],
    );
    final settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    if (requestPermissions) {
      try {
        await androidImpl?.requestNotificationsPermission();
      } catch (_) {}
      try {
        await androidImpl?.requestExactAlarmsPermission();
      } catch (_) {}
    }

    final iosImpl =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    if (requestPermissions) {
      try {
        await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
      } catch (_) {}
    }

    tz.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    _initialized = true;
  }

  Future<void> handleNotificationResponse(NotificationResponse response) async {
    final payload = _parsePayload(response.payload);
    final type = payload['type'] as String?;
    if (type != 'habit_reminder') return;

    if (response.actionId != _habitActionMarkCompleted) return;

    final uid = payload['uid'] as String?;
    final habitId = payload['habitId'] as String?;
    final habitName = payload['habitName'] as String?;
    if (uid == null || habitId == null || habitName == null) return;

    await _ensureFirebase();

    await _firestore.markHabitCompletedFromReminder(
      uid: uid,
      habitId: habitId,
      habitName: habitName,
    );

    await cancelHabitReminders(uid: uid, habitId: habitId);
  }

  Future<void> syncHabitReminders({
    required String uid,
    required List<HabitItem> habits,
  }) async {
    await init();
    await _firestore.resetHabitsForNewDay(uid);

    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_habitIdsKeyPrefix$uid';
    final previousIds = prefs.getStringList(storageKey) ?? const <String>[];

    for (final raw in previousIds) {
      final id = int.tryParse(raw);
      if (id != null) {
        await _plugin.cancel(id);
      }
    }

    final created = <String>[];
    for (final habit in habits) {
      if (habit.completedToday) continue;

      final dailyId = _stableId('habit_${uid}_${habit.id}_daily');
      final scheduled = _nextInstanceOfTime(
        habit.reminderHour,
        habit.reminderMinute,
      );
      final payload = _habitPayload(
        uid: uid,
        habitId: habit.id,
        habitName: habit.name,
      );

      try {
        await _plugin.zonedSchedule(
          dailyId,
          'Habit reminder ${habit.emoji}',
          'Do not forget: ${habit.name}',
          scheduled,
          _habitNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
      } on PlatformException catch (e) {
        if (e.code != 'exact_alarms_not_permitted') rethrow;

        await _plugin.zonedSchedule(
          dailyId,
          'Habit reminder ${habit.emoji}',
          'Do not forget: ${habit.name}',
          scheduled,
          _habitNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
      }

      created.add(dailyId.toString());

      final repeatEvery = habit.reminderIntervalMinutes;
      if (repeatEvery != null && repeatEvery > 0) {
        final intervalId = _stableId('habit_${uid}_${habit.id}_interval');
        final intervalBody =
            'Still pending: ${habit.name} (every $repeatEvery minutes)';
        try {
          await _plugin.periodicallyShowWithDuration(
            intervalId,
            'Habit reminder ${habit.emoji}',
            intervalBody,
            Duration(minutes: repeatEvery),
            _habitNotificationDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: payload,
          );
        } on PlatformException catch (e) {
          if (e.code != 'exact_alarms_not_permitted') rethrow;
          await _plugin.periodicallyShowWithDuration(
            intervalId,
            'Habit reminder ${habit.emoji}',
            intervalBody,
            Duration(minutes: repeatEvery),
            _habitNotificationDetails(),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: payload,
          );
        }
        created.add(intervalId.toString());
      }
    }

    await prefs.setStringList(storageKey, created);
  }

  Future<void> cancelHabitReminders({
    required String uid,
    required String habitId,
  }) async {
    await init();

    final dailyId = _stableId('habit_${uid}_${habitId}_daily');
    final intervalId = _stableId('habit_${uid}_${habitId}_interval');
    await _plugin.cancel(dailyId);
    await _plugin.cancel(intervalId);

    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_habitIdsKeyPrefix$uid';
    final current = prefs.getStringList(storageKey) ?? const <String>[];
    final updated = current.where((raw) {
      final id = int.tryParse(raw);
      if (id == null) return false;
      return id != dailyId && id != intervalId;
    }).toList(growable: false);
    await prefs.setStringList(storageKey, updated);
  }

  Future<void> maybeNotifyScreenTimeWarning({
    required double todayHours,
    required double dailyLimitHours,
  }) async {
    await init();
    if (dailyLimitHours <= 0) return;

    final today = _dayKey(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final key = '$_screenWarningKey$today';
    if (prefs.getBool(key) == true) return;

    final threshold = dailyLimitHours * 0.9;
    if (todayHours >= threshold) {
      await _plugin.show(
        19001,
        'Screen time warning',
        'You are at ${todayHours.toStringAsFixed(1)}h of ${dailyLimitHours.toStringAsFixed(1)}h. Consider a short break.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      await prefs.setBool(key, true);
    }
  }

  Future<void> maybeNotifyFocusNudge({required String uid}) async {
    await init();

    final now = DateTime.now();
    if (now.hour < 20) return;

    final day = _dayKey(now);
    final prefs = await SharedPreferences.getInstance();
    final key = '$_focusNudgeKey$day';
    if (prefs.getBool(key) == true) return;

    bool hasFocused;
    try {
      hasFocused = await _fastApi.hasCompletedFocusSessionToday(uid: uid);
    } catch (_) {
      hasFocused = await _firestore.hasCompletedFocusSessionToday(uid);
    }

    if (!hasFocused) {
      await _plugin.show(
        19002,
        'Focus nudge',
        'You have not focused today yet. Try one short session before you wrap up.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }

    await prefs.setBool(key, true);
  }

  Future<void> maybeNotifyStreakMilestone({
    required String habitName,
    required int streak,
    required bool completed,
  }) async {
    await init();
    if (!completed) return;

    const milestones = <int>{7, 21, 30};
    if (!milestones.contains(streak)) return;

    await _plugin.show(
      20000 + streak,
      'Streak milestone',
      '$habitName reached a $streak-day streak. Keep it going.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> maybeNotifyFatigueRecommendation({
    required int fatigueScore,
    required String recommendation,
  }) async {
    await init();
    if (fatigueScore <= 50) return;

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final today = _dayKey(now);
    final highDayKey = '$_fatigueHighDayKey$today';

    if (fatigueScore >= 90 && prefs.getBool(highDayKey) != true) {
      await _plugin.show(
        19003,
        'High fatigue detected ($fatigueScore)',
        recommendation,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      await prefs.setBool(highDayKey, true);
      await prefs.setInt(_fatigueLastSentKey, now.millisecondsSinceEpoch);
      return;
    }

    final cooldown = fatigueScore >= 75
        ? const Duration(minutes: 60)
        : const Duration(minutes: 120);
    final lastMs = prefs.getInt(_fatigueLastSentKey);
    if (lastMs != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (now.difference(last) < cooldown) return;
    }

    final title = fatigueScore >= 75
        ? 'Fatigue alert ($fatigueScore)'
        : 'Take a short recovery break';

    await _plugin.show(
      19004,
      title,
      recommendation,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );

    await prefs.setInt(_fatigueLastSentKey, now.millisecondsSinceEpoch);
  }

  Future<void> maybeNotifyWellbeingStatus({
    required int fatigueScore,
    required int totalScreenMinutes,
    required int focusSessionsCompleted,
    required int habitsCompleted,
  }) async {
    await init();

    final now = DateTime.now();
    final today = _dayKey(now);
    final prefs = await SharedPreferences.getInstance();
    final key = '$_wellbeingStatusKey$today';
    if (prefs.getBool(key) == true) return;

    final wellbeing = (100 - fatigueScore).clamp(0, 100);
    String? title;
    String? body;

    if (fatigueScore >= 75) {
      title = 'High fatigue today ($fatigueScore)';
      body = 'You logged ${_fmtMinutes(totalScreenMinutes)} of screen time. Try a break or a short walk.';
    } else if (fatigueScore <= 25) {
      title = 'Great balance today ($wellbeing)';
      body = 'Nice work. ${_fmtSessions(focusSessionsCompleted)} and ${_fmtHabits(habitsCompleted)} so far.';
    }

    if (title == null || body == null) return;

    await _plugin.show(
      19100,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );

    await prefs.setBool(key, true);
  }

  Future<void> maybeNotifyUsageInsights({
    required String uid,
    required int fatigueScore,
    required int totalScreenMinutes,
    required int socialMinutes,
    required int entertainmentMinutes,
    required int gamingMinutes,
    required int lateNightMinutes,
    required int longestSessionMinutes,
    required int focusSessionsCompleted,
  }) async {
    await init();

    final now = DateTime.now();
    final day = _dayKey(now);
    final prefs = await SharedPreferences.getInstance();
    final sentKey = '$_insightSentKey$day';
    final sent = prefs.getStringList(sentKey) ?? const <String>[];

    int count = prefs.getInt('$_insightCountKey$day') ?? 0;
    if (count >= 3) return;

    List<String> aiInsights = const <String>[];
    try {
      aiInsights = await _fastApi.getAiInsights(uid: uid);
    } catch (_) {}

    if (aiInsights.isNotEmpty) {
      for (final insight in aiInsights) {
        if (count >= 3) break;
        final trimmed = insight.trim();
        if (trimmed.isEmpty) continue;
        if (sent.contains(trimmed)) continue;

        await _plugin.show(
          19110 + count,
          'Insight',
          trimmed,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );

        sent.add(trimmed);
        count += 1;
      }

      await prefs.setStringList(sentKey, sent);
      await prefs.setInt('$_insightCountKey$day', count);
      return;
    }

    final draining = socialMinutes + entertainmentMinutes + gamingMinutes;
    final candidates = <(String, String, String)>[];

    if (lateNightMinutes >= 30) {
      candidates.add((
        'late_night',
        'Late-night usage detected',
        'You used your phone for ${_fmtMinutes(lateNightMinutes)} after 10pm. Try winding down earlier tonight.',
      ));
    }

    if (longestSessionMinutes >= 90) {
      candidates.add((
        'long_session',
        'Long screen session',
        'Your longest session was ${_fmtMinutes(longestSessionMinutes)}. Add a short break to reset focus.',
      ));
    }

    if (draining >= 180) {
      candidates.add((
        'draining_apps',
        'Heavy social/entertainment use',
        'You spent ${_fmtMinutes(draining)} on draining apps today. Balance it with a focus block.',
      ));
    }

    if (totalScreenMinutes >= 360) {
      candidates.add((
        'high_total',
        'High screen time today',
        'You crossed ${_fmtMinutes(totalScreenMinutes)} today. Consider a 10-minute offline break.',
      ));
    }

    if (focusSessionsCompleted == 0 && now.hour >= 18) {
      candidates.add((
        'no_focus',
        'No focus session yet',
        'Try a short focus session this evening to finish strong.',
      ));
    }

    if (fatigueScore >= 75) {
      candidates.add((
        'high_fatigue',
        'Fatigue is high',
        'Your fatigue score is $fatigueScore. Slow down and protect your sleep tonight.',
      ));
    }

    for (final candidate in candidates) {
      if (count >= 3) break;
      if (sent.contains(candidate.$1)) continue;

      await _plugin.show(
        19110 + count,
        'Insight',
        candidate.$3,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );

      sent.add(candidate.$1);
      count += 1;
    }

    await prefs.setStringList(sentKey, sent);
    await prefs.setInt('$_insightCountKey$day', count);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    var scheduled = tz.TZDateTime(
      tz.local,
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      hour,
      minute,
    );

    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static String _dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _fmtMinutes(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  static String _fmtSessions(int count) {
    if (count <= 0) return 'no focus sessions';
    return count == 1 ? '1 focus session' : '$count focus sessions';
  }

  static String _fmtHabits(int count) {
    if (count <= 0) return 'no habits completed';
    return count == 1 ? '1 habit completed' : '$count habits completed';
  }

  static int _stableId(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return 1000 + (hash % 900000);
  }

  NotificationDetails _habitNotificationDetails() {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _habitActionMarkCompleted,
          'Mark as completed',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const ios = DarwinNotificationDetails(
      categoryIdentifier: _habitCategoryId,
      interruptionLevel: InterruptionLevel.active,
    );

    return const NotificationDetails(android: android, iOS: ios);
  }

  String _habitPayload({
    required String uid,
    required String habitId,
    required String habitName,
  }) {
    return jsonEncode({
      'type': 'habit_reminder',
      'uid': uid,
      'habitId': habitId,
      'habitName': habitName,
    });
  }

  Map<String, Object?> _parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) return const <String, Object?>{};
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore malformed payloads from older scheduled notifications.
    }
    return const <String, Object?>{};
  }

  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
