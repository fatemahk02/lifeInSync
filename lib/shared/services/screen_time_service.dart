import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/app_categorizer/category_rules_engine.dart';
import 'usage_aggregation.dart';

class ScreenUsageEntry {
  final String appName;
  final String packageName;
  final int usageMinutes;

  const ScreenUsageEntry({
    required this.appName,
    required this.packageName,
    required this.usageMinutes,
  });
}

class DailyUsageBucket {
  final DateTime date;
  final int totalMinutes;
  final List<ScreenUsageEntry> apps;

  const DailyUsageBucket({
    required this.date,
    required this.totalMinutes,
    required this.apps,
  });
}

class UsageDebugSnapshot {
  final List<RawUsageEvent> events;
  final List<UsageSession> sessions;
  final Map<String, int> minutesByPackage;

  const UsageDebugSnapshot({
    required this.events,
    required this.sessions,
    required this.minutesByPackage,
  });
}

class FatigueUsageInputs {
  final int totalScreenMinutes;
  final int socialMinutes;
  final int entertainmentMinutes;
  final int gamingMinutes;
  final int lateNightMinutes;
  final int longestSessionMinutes;

  const FatigueUsageInputs({
    required this.totalScreenMinutes,
    required this.socialMinutes,
    required this.entertainmentMinutes,
    required this.gamingMinutes,
    required this.lateNightMinutes,
    required this.longestSessionMinutes,
  });
}

class ScreenTimeService {
  ScreenTimeService._();

  static final ScreenTimeService instance = ScreenTimeService._();

  static const MethodChannel _channel = MethodChannel('lifeinsync/screen_time');
  final Map<String, String> _appLabelCache = <String, String>{};
  static const String _firstLaunchPromptKey =
      'screen_time_permission_prompted';
  static const String _trackingStartEpochKey =
      'screen_time_tracking_start_epoch_ms';

  static const Set<String> _blockedPackages = {
    'android',
    'com.android.systemui',
    'com.android.launcher',
    'com.google.android.packageinstaller',
    'com.android.packageinstaller',
    'com.android.settings',
  };

  static const List<String> _blockedPackageContains = [
    'quicksearchbox',
    'packageinstaller',
    'permissioncontroller',
    'inputmethod',
    'launcher',
    'systemui',
    'hotword',
    'wallpaper',
    'android.dialer',
    'gallery3d',
    'alarmclock',
    'adservices',
    'providers.',
  ];

  static const List<String> _blockedNameContains = [
    'quicksearch',
    'launcher',
    'system ui',
    'gallery3d',
    'alarmclock',
    'ad services',
  ];

  Future<DateTime> getUsageTrackingStart() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final fallback = startOfDay.subtract(const Duration(days: 6));

    final saved = prefs.getInt(_trackingStartEpochKey);
    if (saved != null) {
      final savedDate = DateTime.fromMillisecondsSinceEpoch(saved);
      if (savedDate.isAfter(fallback)) {
        await prefs.setInt(
          _trackingStartEpochKey,
          fallback.millisecondsSinceEpoch,
        );
        return fallback;
      }
      return savedDate;
    }

    await prefs.setInt(_trackingStartEpochKey, fallback.millisecondsSinceEpoch);
    return fallback;
  }

  Future<bool> hasUsagePermission() async {
    if (!Platform.isAndroid) return true;
    final result = await _channel.invokeMethod<bool>('hasUsageAccess');
    return result ?? false;
  }

  Future<void> openUsageAccessSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('openUsageAccessSettings');
  }

  Future<bool> requestPermissionOnFirstLaunch() async {
    if (!Platform.isAndroid) return true;

    final prefs = await SharedPreferences.getInstance();
    final wasPrompted = prefs.getBool(_firstLaunchPromptKey) ?? false;
    final hasPermissionNow = await hasUsagePermission();
    if (hasPermissionNow) return true;

    if (!wasPrompted) {
      await prefs.setBool(_firstLaunchPromptKey, true);
      await openUsageAccessSettings();
      return false;
    }

    return false;
  }

  Future<List<ScreenUsageEntry>> getUsageForRange({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!Platform.isAndroid) return const <ScreenUsageEntry>[];

    final now = DateTime.now();
    final effectiveEnd = end.isAfter(now) ? now : end;
    if (!effectiveEnd.isAfter(start)) {
      return const <ScreenUsageEntry>[];
    }

    final debugStart = DateTime.now();
    final events = await _getUsageEvents(start: start, end: effectiveEnd);
    final sessions = UsageAggregation.buildSessions(
      events: events,
      rangeStart: start,
      rangeEnd: effectiveEnd,
    );

    final secondsByPackage = UsageAggregation.aggregateSecondsByPackage(sessions);
    final entries = await _entriesFromSeconds(secondsByPackage);

    if (kDebugMode) {
      final durationMs = DateTime.now().difference(debugStart).inMilliseconds;
      debugPrint(
        'USAGE_AGG range=${_fmtRange(start, end)} '
        'events=${events.length} sessions=${sessions.length} '
        'apps=${entries.length} in ${durationMs}ms',
      );
    }

    return entries;
  }

  Future<List<DailyUsageBucket>> getDailyUsageBucketsForRange({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!Platform.isAndroid) return const <DailyUsageBucket>[];
    if (!end.isAfter(start)) return const <DailyUsageBucket>[];

    final now = DateTime.now();
    final effectiveEnd = end.isAfter(now) ? now : end;
    if (!effectiveEnd.isAfter(start)) {
      return const <DailyUsageBucket>[];
    }

    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(
      effectiveEnd.year,
      effectiveEnd.month,
      effectiveEnd.day,
    ).add(const Duration(days: 1));

    final events = await _getUsageEvents(start: rangeStart, end: effectiveEnd);
    final sessions = UsageAggregation.buildSessions(
      events: events,
      rangeStart: rangeStart,
      rangeEnd: effectiveEnd,
    );

    final byDaySeconds = UsageAggregation.splitSessionsByDaySeconds(sessions);
    final buckets = <DailyUsageBucket>[];

    var cursor = rangeStart;
    while (cursor.isBefore(rangeEnd)) {
      final key = _dateKey(cursor);
      final secondsByPackage = byDaySeconds[key] ?? const <String, int>{};
      final apps = await _entriesFromSeconds(secondsByPackage);
      final totalSeconds = secondsByPackage.values.fold<int>(0, (a, b) => a + b);

      buckets.add(
        DailyUsageBucket(
          date: cursor,
          totalMinutes: UsageAggregation.secondsToMinutes(totalSeconds),
          apps: apps,
        ),
      );

      cursor = cursor.add(const Duration(days: 1));
    }

    return buckets;
  }

  Future<List<ScreenUsageEntry>> getTodayUsage({
    int top = 25,
    int minUsageMinutes = 1,
  }) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final trackingStart = await getUsageTrackingStart();
    final start = trackingStart.isAfter(startOfDay) ? trackingStart : startOfDay;
    if (!start.isBefore(now)) return const <ScreenUsageEntry>[];

    final all = await getUsageForRange(start: start, end: now);
    final filteredByUsage = all
      .where((e) => e.usageMinutes >= minUsageMinutes)
      .toList(growable: false);
    if (top <= 0 || filteredByUsage.length <= top) return filteredByUsage;
    return filteredByUsage.take(top).toList(growable: false);
  }

  Future<List<double>> getLast7DaysHours() async {
    if (!Platform.isAndroid) return List<double>.filled(7, 0);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final trackingStart = await getUsageTrackingStart();

    final effectiveStart = trackingStart.isAfter(start) ? trackingStart : start;
    if (!effectiveStart.isBefore(now)) {
      return List<double>.filled(7, 0);
    }

    final buckets = await getDailyUsageBucketsForRange(
      start: effectiveStart,
      end: today.add(const Duration(days: 1)),
    );

    final dataByKey = {
      for (final b in buckets) _dateKey(b.date): b.totalMinutes,
    };

    final hours = <double>[];
    for (var i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final minutes = dataByKey[_dateKey(day)] ?? 0;
      hours.add(minutes / 60);
    }

    return hours;
  }

  Future<FatigueUsageInputs> getFatigueUsageInputsForToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final trackingStart = await getUsageTrackingStart();
    final effectiveStart =
        trackingStart.isAfter(startOfDay) ? trackingStart : startOfDay;

    if (!effectiveStart.isBefore(now)) {
      return const FatigueUsageInputs(
        totalScreenMinutes: 0,
        socialMinutes: 0,
        entertainmentMinutes: 0,
        gamingMinutes: 0,
        lateNightMinutes: 0,
        longestSessionMinutes: 0,
      );
    }

    final events = await _getUsageEvents(start: effectiveStart, end: now);
    final sessions = UsageAggregation.buildSessions(
      events: events,
      rangeStart: effectiveStart,
      rangeEnd: now,
    );

    final secondsByPackage = UsageAggregation.aggregateSecondsByPackage(sessions);
    final entries = await _entriesFromSeconds(secondsByPackage);

    var totalScreenMinutes = 0;
    var socialMinutes = 0;
    var entertainmentMinutes = 0;
    var gamingMinutes = 0;
    var longestSessionMinutes = 0;

    for (final entry in entries) {
      totalScreenMinutes += entry.usageMinutes;
      if (entry.usageMinutes > longestSessionMinutes) {
        longestSessionMinutes = entry.usageMinutes;
      }

      final category = CategoryRulesEngine.categorize(
        entry.packageName,
        entry.appName,
      );
      switch (category) {
        case AppCategory.social:
          socialMinutes += entry.usageMinutes;
          break;
        case AppCategory.entertainment:
          entertainmentMinutes += entry.usageMinutes;
          break;
        case AppCategory.gaming:
          gamingMinutes += entry.usageMinutes;
          break;
        default:
          break;
      }
    }

    var lateNightMinutes = 0;
    final tenPm = DateTime(now.year, now.month, now.day, 22);
    if (now.isAfter(tenPm)) {
      final lateStart = trackingStart.isAfter(tenPm) ? trackingStart : tenPm;
      if (lateStart.isBefore(now)) {
        lateNightMinutes = UsageAggregation.secondsToMinutes(
          _sumSessionOverlapSeconds(sessions, lateStart, now),
        );
      }
    }

    return FatigueUsageInputs(
      totalScreenMinutes: totalScreenMinutes,
      socialMinutes: socialMinutes,
      entertainmentMinutes: entertainmentMinutes,
      gamingMinutes: gamingMinutes,
      lateNightMinutes: lateNightMinutes,
      longestSessionMinutes: longestSessionMinutes,
    );
  }

  Future<UsageDebugSnapshot> getDebugSnapshot({
    required DateTime start,
    required DateTime end,
  }) async {
    final events = await _getUsageEvents(start: start, end: end);
    final sessions = UsageAggregation.buildSessions(
      events: events,
      rangeStart: start,
      rangeEnd: end,
    );
    final secondsByPackage = UsageAggregation.aggregateSecondsByPackage(sessions);
    final minutesByPackage = <String, int>{
      for (final entry in secondsByPackage.entries)
        entry.key: UsageAggregation.secondsToMinutes(entry.value),
    };

    return UsageDebugSnapshot(
      events: events,
      sessions: sessions,
      minutesByPackage: minutesByPackage,
    );
  }

  Future<List<RawUsageEvent>> _getUsageEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!Platform.isAndroid) return const <RawUsageEvent>[];

    List<dynamic>? raw;
    try {
      raw = await _channel.invokeMethod<List<dynamic>>(
        'getUsageEvents',
        <String, dynamic>{
          'startMs': start.toUtc().millisecondsSinceEpoch,
          'endMs': end.toUtc().millisecondsSinceEpoch,
        },
      );
    } catch (_) {
      return const <RawUsageEvent>[];
    }

    final events = <RawUsageEvent>[];
    for (final item in raw ?? const <dynamic>[]) {
      if (item is! Map) continue;
      final packageName = (item['packageName'] as String? ?? '').trim();
      final timestamp = (item['timestamp'] as num?)?.toInt();
      final eventType = (item['eventType'] as num?)?.toInt();
      if (packageName.isEmpty || timestamp == null || eventType == null) continue;

      events.add(
        RawUsageEvent(
          packageName: packageName,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            timestamp,
            isUtc: true,
          ).toLocal(),
          eventType: eventType,
        ),
      );
    }

    return events;
  }

  Future<List<ScreenUsageEntry>> _entriesFromSeconds(
    Map<String, int> secondsByPackage,
  ) async {
    final entries = <ScreenUsageEntry>[];

    for (final entry in secondsByPackage.entries) {
      final packageName = entry.key;
      final minutes = UsageAggregation.secondsToMinutes(entry.value);
      if (minutes <= 0) continue;

      final fallback = _friendlyName('', packageName);
      final resolvedName = await _resolveOriginalAppName(packageName, fallback);
      if (!_shouldIncludeUsageEntry(packageName, resolvedName)) continue;

      entries.add(
        ScreenUsageEntry(
          appName: resolvedName,
          packageName: packageName,
          usageMinutes: minutes,
        ),
      );
    }

    entries.sort((a, b) => b.usageMinutes.compareTo(a.usageMinutes));
    return entries;
  }

  int _sumSessionOverlapSeconds(
    List<UsageSession> sessions,
    DateTime start,
    DateTime end,
  ) {
    var total = 0;
    for (final session in sessions) {
      final overlapStart = session.start.isAfter(start) ? session.start : start;
      final overlapEnd = session.end.isBefore(end) ? session.end : end;
      if (overlapEnd.isAfter(overlapStart)) {
        total += overlapEnd.difference(overlapStart).inSeconds;
      }
    }
    return total;
  }

  static String _friendlyName(String rawName, String packageName) {
    final cleaned = rawName.trim();
    if (cleaned.isNotEmpty && !cleaned.contains('.')) return cleaned;

    final pkg = packageName.trim();
    if (pkg.isEmpty) return 'App';
    final parts = pkg.split('.');
    if (parts.isEmpty) return 'App';
    final last = parts.last.toLowerCase();
    if (last == 'android' || last == 'app' || last == 'mobile') {
      return parts.length > 1 ? parts[parts.length - 2] : parts.last;
    }
    return parts.last;
  }

  Future<String> _resolveOriginalAppName(
    String packageName,
    String fallback,
  ) async {
    final cached = _appLabelCache[packageName];
    if (cached != null && cached.trim().isNotEmpty) return cached;

    try {
      final label = await _channel.invokeMethod<String>(
        'getAppLabel',
        <String, dynamic>{'packageName': packageName},
      );
      final cleaned = label?.trim() ?? '';
      if (cleaned.isNotEmpty) {
        _appLabelCache[packageName] = cleaned;
        return cleaned;
      }
    } catch (_) {
      // If platform lookup fails, gracefully fall back to app_usage name.
    }

    final fallbackName = fallback.trim().isEmpty ? 'App' : fallback.trim();
    _appLabelCache[packageName] = fallbackName;
    return fallbackName;
  }

  static bool _shouldIncludeUsageEntry(String packageName, String appName) {
    final pkg = packageName.toLowerCase();
    final name = appName.toLowerCase();

    if (_blockedPackages.contains(pkg)) return false;

    for (final token in _blockedPackageContains) {
      if (pkg.contains(token)) return false;
    }

    for (final token in _blockedNameContains) {
      if (name.contains(token)) return false;
    }

    // Hide this app's own usage from wellbeing analytics.
    if (pkg.contains('lifeinsync') || name.contains('lifeinsync')) return false;

    // Hide generic/OS placeholders that are not meaningful app usage.
    if (name == 'android' || name == 'system ui') return false;

    return true;
  }

  static String _dateKey(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  static String _fmtRange(DateTime start, DateTime end) {
    final s = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}'
        ' ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final e = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}'
        ' ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$s -> $e';
  }
}