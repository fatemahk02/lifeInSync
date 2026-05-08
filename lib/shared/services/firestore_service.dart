import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/app_categorizer/category_rules_engine.dart';

class HabitItem {
  final String id;
  final String name;
  final String emoji;
  final String frequency;
  final int streak;
  final bool completedToday;
  final int reminderHour;
  final int reminderMinute;
  final int? reminderIntervalMinutes;

  const HabitItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.frequency,
    required this.streak,
    required this.completedToday,
    required this.reminderHour,
    required this.reminderMinute,
    required this.reminderIntervalMinutes,
  });

  factory HabitItem.fromMap(String id, Map<String, dynamic> data) {
    return HabitItem(
      id: id,
      name: (data['name'] as String?) ?? '',
      emoji: (data['emoji'] as String?) ?? '⭐',
      frequency: (data['frequency'] as String?) ?? 'Daily',
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      completedToday: (data['completedToday'] as bool?) ?? false,
      reminderHour: (data['reminderHour'] as num?)?.toInt() ?? 20,
      reminderMinute: (data['reminderMinute'] as num?)?.toInt() ?? 0,
      reminderIntervalMinutes:
          (data['reminderIntervalMinutes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'emoji': emoji,
      'frequency': frequency,
      'streak': streak,
      'completedToday': completedToday,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      if (reminderIntervalMinutes != null)
        'reminderIntervalMinutes': reminderIntervalMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class FatigueLog {
  final DateTime date;
  final int score;
  final String level;
  final Map<String, dynamic> breakdown;

  const FatigueLog({
    required this.date,
    required this.score,
    required this.level,
    required this.breakdown,
  });

  factory FatigueLog.fromMap(Map<String, dynamic> data) {
    final ts = data['date'] as Timestamp?;
    return FatigueLog(
      date: ts?.toDate() ?? DateTime.now(),
      score: (data['score'] as num?)?.toInt() ?? 0,
      level: (data['level'] as String?) ?? 'fresh',
      breakdown: (data['breakdown'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class InsightData {
  final List<double> wellbeingScores;
  final List<double> fatigueScores;
  final List<String> labels;
  final double avgWellbeing;
  final double avgFatigue;
  final double focusHours;
  final double productiveRatio;
  final double drainingRatio;
  final List<(String, String, int)> categoryRows;
  final List<(String, String, int, int)> habitConsistency;
  final List<Map<String, String>> insights;

  const InsightData({
    required this.wellbeingScores,
    required this.fatigueScores,
    required this.labels,
    required this.avgWellbeing,
    required this.avgFatigue,
    required this.focusHours,
    required this.productiveRatio,
    required this.drainingRatio,
    required this.categoryRows,
    required this.habitConsistency,
    required this.insights,
  });
}

class AnalyticsSnapshotInput {
  final DateTime date;
  final int wellbeingScore;
  final int focusScore;
  final int fatigueScore;
  final int totalScreenTimeMinutes;
  final int screenTimeLimitMinutes;
  final int habitsDone;
  final int totalHabits;
  final int focusMinutes;
  final int focusGoalMinutes;
  final double habitConsistencyDaily;
  final double habitConsistencyWeekly;
  final double habitConsistencyMonthly;

  const AnalyticsSnapshotInput({
    required this.date,
    required this.wellbeingScore,
    required this.focusScore,
    required this.fatigueScore,
    required this.totalScreenTimeMinutes,
    required this.screenTimeLimitMinutes,
    required this.habitsDone,
    required this.totalHabits,
    required this.focusMinutes,
    required this.focusGoalMinutes,
    required this.habitConsistencyDaily,
    required this.habitConsistencyWeekly,
    required this.habitConsistencyMonthly,
  });
}

class LiveUsageSnapshot {
  final DateTime? updatedAt;
  final int totalScreenMinutesToday;
  final int trackedAppsCount;
  final List<Map<String, dynamic>> topApps;

  const LiveUsageSnapshot({
    required this.updatedAt,
    required this.totalScreenMinutesToday,
    required this.trackedAppsCount,
    required this.topApps,
  });

  factory LiveUsageSnapshot.fromMap(Map<String, dynamic> data) {
    final rawTopApps = (data['topApps'] as List?) ?? const <dynamic>[];
    return LiveUsageSnapshot(
      updatedAt: (data['deviceLocalUpdatedAt'] as Timestamp?)?.toDate() ??
          (data['updatedAt'] as Timestamp?)?.toDate(),
      totalScreenMinutesToday:
          (data['totalScreenMinutesToday'] as num?)?.toInt() ?? 0,
      trackedAppsCount: (data['trackedAppsCount'] as num?)?.toInt() ?? 0,
      topApps: rawTopApps
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false),
    );
  }
}

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> configureOfflinePersistence() async {
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  CollectionReference<Map<String, dynamic>> _habitItems(String uid) =>
      _db.collection('habits').doc(uid).collection('items');

  CollectionReference<Map<String, dynamic>> _habitLogs(String uid) =>
      _db.collection('habitLogs').doc(uid).collection('logs');

  CollectionReference<Map<String, dynamic>> _focusSessions(String uid) =>
      _db.collection('focusSessions').doc(uid).collection('sessions');

  CollectionReference<Map<String, dynamic>> _fatigueLogs(String uid) =>
      _db.collection('fatigueHistory').doc(uid).collection('logs');

    CollectionReference<Map<String, dynamic>> _analyticsDaily(String uid) =>
      _db.collection('analytics').doc(uid).collection('daily');

    CollectionReference<Map<String, dynamic>> _analyticsWeekly(String uid) =>
      _db.collection('analytics').doc(uid).collection('weekly');

    CollectionReference<Map<String, dynamic>> _analyticsMonthly(String uid) =>
      _db.collection('analytics').doc(uid).collection('monthly');

    DocumentReference<Map<String, dynamic>> _analyticsLiveUsage(String uid) =>
      _db.collection('analytics').doc(uid).collection('live').doc('usage');

  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    String? mobileNumber,
  }) async {
    await _db.collection('users').doc(uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'mobileNumber': (mobileNumber ?? '').trim(),
      'gender': '',
      'age': 0,
      'preferences': {
        'dailyScreenLimitMinutes': 180,
        'notificationsEnabled': true,
        'focusGoalMinutes': 60,
        'onboardingCompleted': false,
        'theme': 'light',
      },
      'avatarEmoji': '🙂',
      'timezone': 'UTC',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>?> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) => doc.data());
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? avatarEmoji,
    String? timezone,
    String? mobileNumber,
    String? gender,
    int? age,
  }) async {
    final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (name != null) updates['name'] = name.trim();
    if (avatarEmoji != null) updates['avatarEmoji'] = avatarEmoji;
    if (timezone != null) updates['timezone'] = timezone;
    if (mobileNumber != null) updates['mobileNumber'] = mobileNumber.trim();
    if (gender != null) updates['gender'] = gender;
    if (age != null) updates['age'] = age;

    await _db.collection('users').doc(uid).set(updates, SetOptions(merge: true));
  }

  Future<void> removeLegacyRoleField(String uid) async {
    await _db.collection('users').doc(uid).set({
      'role': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserPreferences({
    required String uid,
    int? dailyScreenLimitMinutes,
    bool? notificationsEnabled,
    int? focusGoalMinutes,
    bool? onboardingCompleted,
    String? theme,
  }) async {
    final prefs = <String, dynamic>{};
    if (dailyScreenLimitMinutes != null) {
      prefs['dailyScreenLimitMinutes'] = dailyScreenLimitMinutes;
    }
    if (notificationsEnabled != null) {
      prefs['notificationsEnabled'] = notificationsEnabled;
    }
    if (focusGoalMinutes != null) {
      prefs['focusGoalMinutes'] = focusGoalMinutes;
    }
    if (onboardingCompleted != null) {
      prefs['onboardingCompleted'] = onboardingCompleted;
    }
    if (theme != null) {
      prefs['theme'] = theme;
    }
    if (prefs.isEmpty) return;

    await _db.collection('users').doc(uid).set({
      'preferences': prefs,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> ensureDefaultHabits(String uid) async {
    final snap = await _habitItems(uid).limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final defaults = [
      HabitItem(
        id: 'default_water',
        name: 'Drink 8 glasses of water',
        emoji: '💧',
        frequency: 'Daily',
        streak: 12,
        completedToday: true,
        reminderHour: 20,
        reminderMinute: 0,
        reminderIntervalMinutes: null,
      ),
      HabitItem(
        id: 'default_exercise',
        name: 'Exercise 30 minutes',
        emoji: '🏃',
        frequency: 'Daily',
        streak: 7,
        completedToday: true,
        reminderHour: 20,
        reminderMinute: 0,
        reminderIntervalMinutes: null,
      ),
      HabitItem(
        id: 'default_read',
        name: 'Read for 20 minutes',
        emoji: '📚',
        frequency: 'Daily',
        streak: 5,
        completedToday: false,
        reminderHour: 20,
        reminderMinute: 0,
        reminderIntervalMinutes: null,
      ),
      HabitItem(
        id: 'default_meditate',
        name: 'Meditate',
        emoji: '🧘',
        frequency: 'Daily',
        streak: 21,
        completedToday: true,
        reminderHour: 20,
        reminderMinute: 0,
        reminderIntervalMinutes: null,
      ),
      HabitItem(
        id: 'default_no_phone',
        name: 'No phone after 10pm',
        emoji: '📵',
        frequency: 'Daily',
        streak: 3,
        completedToday: false,
        reminderHour: 20,
        reminderMinute: 0,
        reminderIntervalMinutes: null,
      ),
      HabitItem(
        id: 'default_journaling',
        name: 'Journaling',
        emoji: '✍️',
        frequency: 'Daily',
        streak: 9,
        completedToday: false,
        reminderHour: 20,
        reminderMinute: 0,
        reminderIntervalMinutes: null,
      ),
    ];

    final batch = _db.batch();
    for (final habit in defaults) {
      batch.set(_habitItems(uid).doc(habit.id), {
        ...habit.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Stream<List<HabitItem>> streamHabits(String uid) {
    return _habitItems(uid)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => HabitItem.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> addHabit({
    required String uid,
    required String name,
    required String emoji,
    String frequency = 'Daily',
    int reminderHour = 20,
    int reminderMinute = 0,
    int? reminderIntervalMinutes,
  }) async {
    await _habitItems(uid).add({
      'name': name.trim(),
      'emoji': emoji,
      'frequency': frequency,
      'streak': 0,
      'completedToday': false,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      if (reminderIntervalMinutes != null)
        'reminderIntervalMinutes': reminderIntervalMinutes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> hasCompletedFocusSessionToday(String uid) async {
    final count = await getCompletedFocusSessionsToday(uid);
    return count > 0;
  }

  Future<int> getCompletedFocusSessionsToday(String uid) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Query by time window only to avoid requiring a composite index.
    final snap = await _focusSessions(uid)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('completedAt', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(20)
        .get();

    final completed = snap.docs.where((doc) {
      final data = doc.data();
      return data['completed'] == true;
    }).length;

    return completed;
  }

  Future<int> getCompletedHabitsToday(String uid) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snap = await _habitLogs(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return snap.docs.where((d) => d.data()['completed'] == true).length;
  }

  Future<int> getTotalHabits(String uid) async {
    final snap = await _habitItems(uid).get();
    return snap.docs.length;
  }

  Future<int> getCompletedHabitsInRange({
    required String uid,
    required DateTime start,
    required DateTime end,
  }) async {
    final snap = await _habitLogs(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.where((d) => d.data()['completed'] == true).length;
  }

  Future<int> getCompletedFocusMinutesInRange({
    required String uid,
    required DateTime start,
    required DateTime end,
  }) async {
    final snap = await _focusSessions(uid)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThan: Timestamp.fromDate(end))
        .get();

    var seconds = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if ((data['completed'] as bool?) != true) continue;
      seconds += (data['plannedSeconds'] as num?)?.toInt() ?? 0;
    }
    return (seconds / 60).round();
  }

  Future<int> getFatigueScoreForDate(String uid, DateTime date) async {
    final key = _dateKey(date);
    final doc = await _fatigueLogs(uid).doc(key).get();
    final data = doc.data();
    return (data?['score'] as num?)?.toInt() ?? 0;
  }

  Future<void> saveAnalyticsSnapshots({
    required String uid,
    required AnalyticsSnapshotInput input,
  }) async {
    final dayKey = _dateKey(input.date);
    final weeklyKey = _weekKey(input.date);
    final monthlyKey = _monthKey(input.date);

    final dayStart = DateTime(input.date.year, input.date.month, input.date.day);
    final weekStart = dayStart.subtract(Duration(days: dayStart.weekday - 1));
    final monthStart = DateTime(input.date.year, input.date.month, 1);

    await _analyticsDaily(uid).doc(dayKey).set({
      'period': 'daily',
      'date': Timestamp.fromDate(dayStart),
      'wellbeingScore': input.wellbeingScore,
      'focusScore': input.focusScore,
      'fatigueScore': input.fatigueScore,
      'totalScreenTimeMinutes': input.totalScreenTimeMinutes,
      'screenTimeLimitMinutes': input.screenTimeLimitMinutes,
      'habitsDone': input.habitsDone,
      'totalHabits': input.totalHabits,
      'focusMinutes': input.focusMinutes,
      'focusGoalMinutes': input.focusGoalMinutes,
      'habitConsistency': {
        'daily': input.habitConsistencyDaily,
        'weekly': input.habitConsistencyWeekly,
        'monthly': input.habitConsistencyMonthly,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final sevenDayStart = dayStart.subtract(const Duration(days: 6));
    final weekDaily = await _analyticsDaily(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDayStart))
        .where('date', isLessThan: Timestamp.fromDate(dayStart.add(const Duration(days: 1))))
        .get();

    await _analyticsWeekly(uid).doc(weeklyKey).set(
      _aggregatePeriod(
        docs: weekDaily.docs,
        period: 'weekly',
        periodKey: weeklyKey,
        start: weekStart,
        end: weekStart.add(const Duration(days: 7)),
      ),
      SetOptions(merge: true),
    );

    final thirtyDayStart = dayStart.subtract(const Duration(days: 29));
    final monthDaily = await _analyticsDaily(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDayStart))
        .where('date', isLessThan: Timestamp.fromDate(dayStart.add(const Duration(days: 1))))
        .get();

    await _analyticsMonthly(uid).doc(monthlyKey).set(
      _aggregatePeriod(
        docs: monthDaily.docs,
        period: 'monthly',
        periodKey: monthlyKey,
        start: monthStart,
        end: DateTime(monthStart.year, monthStart.month + 1, 1),
      ),
      SetOptions(merge: true),
    );
  }

  Map<String, dynamic> _aggregatePeriod({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String period,
    required String periodKey,
    required DateTime start,
    required DateTime end,
  }) {
    if (docs.isEmpty) {
      return {
        'period': period,
        'periodKey': periodKey,
        'startDate': Timestamp.fromDate(start),
        'endDate': Timestamp.fromDate(end),
        'samples': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      };
    }

    double sum(String field) {
      return docs
          .map((d) => (d.data()[field] as num?)?.toDouble() ?? 0)
          .fold(0.0, (a, b) => a + b);
    }

    final count = docs.length;
    double avg(String field) => sum(field) / count;

    return {
      'period': period,
      'periodKey': periodKey,
      'startDate': Timestamp.fromDate(start),
      'endDate': Timestamp.fromDate(end),
      'samples': count,
      'wellbeingScoreAvg': avg('wellbeingScore'),
      'focusScoreAvg': avg('focusScore'),
      'fatigueScoreAvg': avg('fatigueScore'),
      'totalScreenTimeMinutes': sum('totalScreenTimeMinutes').round(),
      'screenTimeLimitMinutesAvg': avg('screenTimeLimitMinutes'),
      'habitsDoneTotal': sum('habitsDone').round(),
      'focusMinutesTotal': sum('focusMinutes').round(),
      'habitConsistencyDailyAvg': docs
              .map(
                (d) =>
                    ((d.data()['habitConsistency'] as Map<String, dynamic>?)?['daily']
                            as num?)
                        ?.toDouble() ??
                    0,
              )
              .fold(0.0, (a, b) => a + b) /
          count,
      'habitConsistencyWeeklyAvg': docs
              .map(
                (d) =>
                    ((d.data()['habitConsistency'] as Map<String, dynamic>?)?['weekly']
                            as num?)
                        ?.toDouble() ??
                    0,
              )
              .fold(0.0, (a, b) => a + b) /
          count,
      'habitConsistencyMonthlyAvg': docs
              .map(
                (d) =>
                    ((d.data()['habitConsistency'] as Map<String, dynamic>?)?['monthly']
                            as num?)
                        ?.toDouble() ??
                    0,
              )
              .fold(0.0, (a, b) => a + b) /
          count,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> updateHabit({
    required String uid,
    required String habitId,
    required bool completedToday,
    required int streak,
  }) async {
    await _habitItems(uid).doc(habitId).set({
      'completedToday': completedToday,
      'streak': streak,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateHabitDetails({
    required String uid,
    required String habitId,
    required String name,
    required String emoji,
    int? reminderHour,
    int? reminderMinute,
    int? reminderIntervalMinutes,
  }) async {
    final updates = <String, dynamic>{
      'name': name.trim(),
      'emoji': emoji,
      if (reminderHour != null) 'reminderHour': reminderHour,
      if (reminderMinute != null) 'reminderMinute': reminderMinute,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (reminderIntervalMinutes == null || reminderIntervalMinutes <= 0) {
      updates['reminderIntervalMinutes'] = FieldValue.delete();
    } else {
      updates['reminderIntervalMinutes'] = reminderIntervalMinutes;
    }

    await _habitItems(uid).doc(habitId).set(updates, SetOptions(merge: true));
  }

  Future<void> markHabitCompletedFromReminder({
    required String uid,
    required String habitId,
    required String habitName,
  }) async {
    final ref = _habitItems(uid).doc(habitId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? const <String, dynamic>{};
      final alreadyCompleted = (data['completedToday'] as bool?) ?? false;
      final currentStreak = (data['streak'] as num?)?.toInt() ?? 0;

      tx.set(ref, {
        'completedToday': true,
        'streak': alreadyCompleted ? currentStreak : currentStreak + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    await logHabitCompletion(
      uid: uid,
      habitId: habitId,
      habitName: habitName,
      completed: true,
    );
  }

  Future<void> resetHabitsForNewDay(String uid) async {
    final today = _dateKey(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final markerKey = 'habit_daily_reset_key_$uid';
    final lastResetDay = prefs.getString(markerKey);
    if (lastResetDay == today) return;

    final items = await _habitItems(uid).get();
    final batch = _db.batch();
    for (final doc in items.docs) {
      if ((doc.data()['completedToday'] as bool?) != true) continue;
      batch.set(doc.reference, {
        'completedToday': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
    await prefs.setString(markerKey, today);
  }

  Future<void> deleteHabit({
    required String uid,
    required String habitId,
  }) async {
    await _habitItems(uid).doc(habitId).delete();
  }

  Future<void> logHabitCompletion({
    required String uid,
    required String habitId,
    required String habitName,
    required bool completed,
    DateTime? date,
  }) async {
    final now = date ?? DateTime.now();
    final day = _dateKey(now);
    await _habitLogs(uid).doc('${habitId}_$day').set({
      'habitId': habitId,
      'habitName': habitName,
      'completed': completed,
      'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveFocusSession({
    required String uid,
    required String sessionType,
    required int plannedSeconds,
    required bool completed,
    DateTime? completedAt,
  }) async {
    final at = completedAt ?? DateTime.now();
    await _focusSessions(uid).add({
      'sessionType': sessionType,
      'plannedSeconds': plannedSeconds,
      'completed': completed,
      'completedAt': Timestamp.fromDate(at),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveFatigueScore({
    required String uid,
    required DateTime date,
    required int score,
    required String level,
    required Map<String, dynamic> breakdown,
    required List<Map<String, dynamic>> triggers,
    required String recommendation,
  }) async {
    final day = _dateKey(date);
    await _fatigueLogs(uid).doc(day).set({
      'score': score,
      'level': level,
      'breakdown': breakdown,
      'triggers': triggers,
      'recommendation': recommendation,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<LiveUsageSnapshot?> streamLiveUsageSnapshot(String uid) {
    return _analyticsLiveUsage(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return LiveUsageSnapshot.fromMap(data);
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamLiveUsageDocument(
    String uid, {
    bool includeMetadataChanges = true,
  }) {
    return _analyticsLiveUsage(uid).snapshots(
      includeMetadataChanges: includeMetadataChanges,
    );
  }

  Future<LiveUsageSnapshot?> getLiveUsageSnapshot(String uid) async {
    final doc = await _analyticsLiveUsage(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return LiveUsageSnapshot.fromMap(data);
  }

  Stream<List<FatigueLog>> streamFatigueHistory(
    String uid, {
    int days = 7,
    DateTime? startDate,
  }) {
    final start = startDate ?? DateTime.now().subtract(Duration(days: days - 1));
    final startDay = DateTime(start.year, start.month, start.day);
    return _fatigueLogs(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDay))
        .orderBy('date')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => FatigueLog.fromMap(d.data()))
              .toList(growable: false),
        );
  }

  Stream<InsightData> streamInsights(String uid, {int days = 7}) {
    final controller = StreamController<InsightData>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? fatigueSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? focusSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? habitSub;

    Future<void> emit() async {
      final data = await _buildInsights(uid, days: days);
      if (!controller.isClosed) controller.add(data);
    }

    controller.onListen = () async {
      await emit();
      fatigueSub = _fatigueLogs(uid).snapshots().listen((_) => emit());
      focusSub = _focusSessions(uid).snapshots().listen((_) => emit());
      habitSub = _habitLogs(uid).snapshots().listen((_) => emit());
    };

    controller.onCancel = () async {
      await fatigueSub?.cancel();
      await focusSub?.cancel();
      await habitSub?.cancel();
    };

    return controller.stream;
  }

  Future<InsightData> getInsightsOnce(String uid, {int days = 7}) async {
    return _buildInsights(uid, days: days);
  }

  Future<InsightData> _buildInsights(String uid, {int days = 7}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));

    final fatigueSnap = await _fatigueLogs(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('date')
        .get();

    final focusSnap = await _focusSessions(uid)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();

    final habitSnap = await _habitLogs(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();

    final fatigueByDay = <String, FatigueLog>{};
    for (final d in fatigueSnap.docs) {
      final log = FatigueLog.fromMap(d.data());
      fatigueByDay[_dateKey(log.date)] = log;
    }

    final labels = <String>[];
    final fatigueScores = <double>[];
    final wellbeingScores = <double>[];
    for (var i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      final label = _weekdayLabel(day.weekday, short: true);
      final key = _dateKey(day);
      final log = fatigueByDay[key];
      final fatigue = (log?.score ?? 0).toDouble();
      final wellbeing = (100 - fatigue).clamp(0, 100).toDouble();
      labels.add(label);
      fatigueScores.add(fatigue);
      wellbeingScores.add(wellbeing);
    }

    final avgFatigue =
        fatigueScores.isEmpty ? 0.0 : fatigueScores.reduce((a, b) => a + b) / fatigueScores.length;
    final avgWellbeing =
        wellbeingScores.isEmpty ? 0.0 : wellbeingScores.reduce((a, b) => a + b) / wellbeingScores.length;

    var focusSeconds = 0;
    for (final d in focusSnap.docs) {
      final data = d.data();
      if ((data['completed'] as bool?) ?? false) {
        focusSeconds += (data['plannedSeconds'] as num?)?.toInt() ?? 0;
      }
    }
    final focusHours = focusSeconds / 3600;

    var drainingScoreSum = 0;
    for (final d in fatigueSnap.docs) {
      final data = d.data();
      final breakdown = (data['breakdown'] as Map<String, dynamic>?) ?? {};
      drainingScoreSum += (breakdown['drainingAppsScore'] as num?)?.toInt() ?? 0;
    }
    final drainingRatio = (drainingScoreSum / (days * 25)).clamp(0.0, 1.0);
    final productiveRatio = (1 - drainingRatio).clamp(0.0, 1.0);

    var productiveMinutes = 0;
    var entertainmentMinutes = 0;
    var socialMinutes = 0;
    var otherMinutes = 0;
    final liveUsage = await getLiveUsageSnapshot(uid);

    for (final app in liveUsage?.topApps ?? const <Map<String, dynamic>>[]) {
      final mins = (app['usageMinutes'] as num?)?.toInt() ?? 0;
      if (mins <= 0) continue;

      final packageName = (app['packageName'] as String?) ?? '';
      final appName = (app['appName'] as String?) ?? '';
      final category = CategoryRulesEngine.categorize(packageName, appName);

      switch (category) {
        case AppCategory.productive:
        case AppCategory.education:
        case AppCategory.health:
        case AppCategory.finance:
          productiveMinutes += mins;
          break;
        case AppCategory.entertainment:
        case AppCategory.gaming:
          entertainmentMinutes += mins;
          break;
        case AppCategory.social:
          socialMinutes += mins;
          break;
        default:
          otherMinutes += mins;
          break;
      }
    }

    final fallbackFocusMins = (focusSeconds / 60).round();
    if (productiveMinutes == 0 && entertainmentMinutes == 0 && socialMinutes == 0 && otherMinutes == 0) {
      productiveMinutes = fallbackFocusMins;
    }

    final categoryRows = <(String, String, int)>[
      ('Productive 🎯', _fmtMinutes(productiveMinutes), 0xFF3DBE7A),
      ('Entertainment 🎬', _fmtMinutes(entertainmentMinutes), 0xFFFFB74D),
      ('Social 💬', _fmtMinutes(socialMinutes), 0xFF64B5F6),
      ('Other 📦', _fmtMinutes(otherMinutes), 0xFFB0BEC5),
    ];

    final logsByHabit = <String, Set<String>>{};
    for (final d in habitSnap.docs) {
      final data = d.data();
      if ((data['completed'] as bool?) != true) continue;
      final habitId = (data['habitId'] as String?) ?? 'habit';
      final habitName = (data['habitName'] as String?) ?? 'Habit';
      final ts = data['date'] as Timestamp?;
      final dayKey = _dateKey(ts?.toDate() ?? now);
      final key = '$habitId|$habitName';
      logsByHabit.putIfAbsent(key, () => <String>{}).add(dayKey);
    }

    final habitConsistency = logsByHabit.entries
        .take(5)
        .map((e) {
          final parts = e.key.split('|');
          final name = parts.length > 1 ? parts[1] : 'Habit';
          final completedDays = e.value.length;
          return ('⭐', name, completedDays, days);
        })
        .toList();

    final insights = _buildInsightCards(
      avgWellbeing: avgWellbeing,
      avgFatigue: avgFatigue,
      focusHours: focusHours,
      productiveRatio: productiveRatio,
      habitConsistency: habitConsistency,
      days: days,
    );

    return InsightData(
      wellbeingScores: wellbeingScores,
      fatigueScores: fatigueScores,
      labels: labels,
      avgWellbeing: avgWellbeing,
      avgFatigue: avgFatigue,
      focusHours: focusHours,
      productiveRatio: productiveRatio,
      drainingRatio: drainingRatio,
      categoryRows: categoryRows,
      habitConsistency: habitConsistency,
      insights: insights,
    );
  }

  List<Map<String, String>> _buildInsightCards({
    required double avgWellbeing,
    required double avgFatigue,
    required double focusHours,
    required double productiveRatio,
    required List<(String, String, int, int)> habitConsistency,
    required int days,
  }) {
    final topHabit = habitConsistency.isEmpty
        ? null
        : (habitConsistency.toList()
          ..sort((a, b) => b.$3.compareTo(a.$3))).first;

    return [
      {
        'emoji': '📈',
        'text':
            'Your average wellbeing this period is ${avgWellbeing.toStringAsFixed(1)}.',
      },
      {
        'emoji': '😴',
        'text':
            'Average fatigue is ${avgFatigue.toStringAsFixed(1)} out of 100.',
      },
      {
        'emoji': '⏱️',
        'text':
            'You completed ${focusHours.toStringAsFixed(1)}h of focus sessions in the last $days days.',
      },
      {
        'emoji': '📱',
        'text':
            'Productive usage ratio is ${(productiveRatio * 100).round()}% based on your logged data.',
      },
      if (topHabit != null)
        {
          'emoji': '🔥',
          'text':
              '${topHabit.$2} was your most consistent habit (${topHabit.$3}/${topHabit.$4} days).',
        },
    ];
  }

  static String _dateKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static String _monthKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    return '${d.year}-$m';
  }

  static String _weekKey(DateTime d) {
    final dayOfYear =
      DateTime(d.year, d.month, d.day)
        .difference(DateTime(d.year, 1, 1))
        .inDays +
      1;
    final week = ((dayOfYear - d.weekday + 10) / 7).floor();
    return '${d.year}-W${week.toString().padLeft(2, '0')}';
  }

  static String _weekdayLabel(int weekday, {bool short = false}) {
    const shortMap = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const longMap = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return short ? shortMap[weekday - 1] : longMap[weekday - 1];
  }

  static String _fmtMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }
}
