class RawUsageEvent {
  final String packageName;
  final DateTime timestamp;
  final int eventType;

  const RawUsageEvent({
    required this.packageName,
    required this.timestamp,
    required this.eventType,
  });
}

class UsageSession {
  final String packageName;
  final DateTime start;
  final DateTime end;

  const UsageSession({
    required this.packageName,
    required this.start,
    required this.end,
  });

  int get durationSeconds => end.difference(start).inSeconds;
}

class UsageEventTypes {
  // Android UsageEvents.Event constants.
  static const int moveToForeground = 1;
  static const int moveToBackground = 2;
  static const int activityResumed = 7;
  static const int activityPaused = 8;
  static const int activityStopped = 23;
  static const int screenNonInteractive = 15;
}

class UsageAggregation {
  static const Duration minSessionDuration = Duration(seconds: 10);

  static List<UsageSession> buildSessions({
    required List<RawUsageEvent> events,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    Duration minSession = minSessionDuration,
  }) {
    if (!rangeEnd.isAfter(rangeStart)) return const <UsageSession>[];

    final sorted = List<RawUsageEvent>.from(events)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final sessions = <UsageSession>[];
    String? currentApp;
    DateTime? currentStart;

    bool isStartEvent(int type) =>
        type == UsageEventTypes.moveToForeground ||
        type == UsageEventTypes.activityResumed;
    bool isEndEvent(int type) =>
        type == UsageEventTypes.moveToBackground ||
        type == UsageEventTypes.activityPaused ||
        type == UsageEventTypes.activityStopped ||
        type == UsageEventTypes.screenNonInteractive;

    void closeSession(DateTime endTime) {
      if (currentApp == null || currentStart == null) return;
        final safeStart = currentStart.isBefore(rangeStart)
          ? rangeStart
          : currentStart;
      final safeEnd = endTime.isAfter(rangeEnd) ? rangeEnd : endTime;
      if (!safeEnd.isAfter(safeStart)) return;
      if (safeEnd.difference(safeStart) < minSession) return;

      sessions.add(
        UsageSession(
          packageName: currentApp,
          start: safeStart,
          end: safeEnd,
        ),
      );
    }

    for (final event in sorted) {
      if (event.timestamp.isAfter(rangeEnd)) break;

      final type = event.eventType;
      if (isStartEvent(type)) {
        if (currentApp != null && currentStart != null) {
          closeSession(event.timestamp);
        }
        currentApp = event.packageName;
        currentStart = event.timestamp;
        continue;
      }

      if (isEndEvent(type)) {
        if (currentApp != null && currentStart != null) {
          if (currentApp == event.packageName ||
              type == UsageEventTypes.screenNonInteractive) {
            closeSession(event.timestamp);
            currentApp = null;
            currentStart = null;
          }
        }
      }
    }

    if (currentApp != null && currentStart != null) {
      closeSession(rangeEnd);
    }

    return sessions;
  }

  static Map<String, Map<String, int>> splitSessionsByDaySeconds(
    List<UsageSession> sessions,
  ) {
    final Map<String, Map<String, int>> byDay = {};

    for (final session in sessions) {
      var cursor = session.start;
      while (cursor.isBefore(session.end)) {
        final dayStart = DateTime(cursor.year, cursor.month, cursor.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final segmentEnd = session.end.isBefore(dayEnd) ? session.end : dayEnd;
        final seconds = segmentEnd.difference(cursor).inSeconds;

        final key = _dateKey(dayStart);
        final perApp = byDay.putIfAbsent(key, () => <String, int>{});
        perApp[session.packageName] = (perApp[session.packageName] ?? 0) + seconds;

        cursor = segmentEnd;
      }
    }

    return byDay;
  }

  static Map<String, int> aggregateSecondsByPackage(
    List<UsageSession> sessions,
  ) {
    final totals = <String, int>{};
    for (final session in sessions) {
      totals[session.packageName] =
          (totals[session.packageName] ?? 0) + session.durationSeconds;
    }
    return totals;
  }

  static int secondsToMinutes(int seconds) {
    if (seconds <= 0) return 0;
    return (seconds / 60).round();
  }

  static String _dateKey(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}
