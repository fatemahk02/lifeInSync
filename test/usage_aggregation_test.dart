import 'package:flutter_test/flutter_test.dart';
import 'package:lifeinSync/shared/services/usage_aggregation.dart';

void main() {
  test('splits session across midnight', () {
    final start = DateTime(2026, 5, 2, 23, 50);
    final end = DateTime(2026, 5, 3, 0, 10);

    final events = [
      RawUsageEvent(
        packageName: 'com.instagram.android',
        timestamp: start,
        eventType: UsageEventTypes.moveToForeground,
      ),
      RawUsageEvent(
        packageName: 'com.instagram.android',
        timestamp: end,
        eventType: UsageEventTypes.moveToBackground,
      ),
    ];

    final sessions = UsageAggregation.buildSessions(
      events: events,
      rangeStart: start,
      rangeEnd: end,
    );

    final byDay = UsageAggregation.splitSessionsByDaySeconds(sessions);
    final day1 = byDay['2026-05-02']?['com.instagram.android'] ?? 0;
    final day2 = byDay['2026-05-03']?['com.instagram.android'] ?? 0;

    expect(UsageAggregation.secondsToMinutes(day1), 10);
    expect(UsageAggregation.secondsToMinutes(day2), 10);
  });

  test('handles multiple sessions and app switches', () {
    final start = DateTime(2026, 5, 2, 10, 0);
    final events = [
      RawUsageEvent(
        packageName: 'com.a',
        timestamp: start,
        eventType: UsageEventTypes.moveToForeground,
      ),
      RawUsageEvent(
        packageName: 'com.b',
        timestamp: start.add(const Duration(minutes: 10)),
        eventType: UsageEventTypes.moveToForeground,
      ),
      RawUsageEvent(
        packageName: 'com.b',
        timestamp: start.add(const Duration(minutes: 20)),
        eventType: UsageEventTypes.moveToBackground,
      ),
    ];

    final sessions = UsageAggregation.buildSessions(
      events: events,
      rangeStart: start,
      rangeEnd: start.add(const Duration(minutes: 30)),
    );

    final totals = UsageAggregation.aggregateSecondsByPackage(sessions);
    expect(UsageAggregation.secondsToMinutes(totals['com.a'] ?? 0), 10);
    expect(UsageAggregation.secondsToMinutes(totals['com.b'] ?? 0), 10);
  });

  test('debounces very short sessions', () {
    final start = DateTime(2026, 5, 2, 12, 0);
    final events = [
      RawUsageEvent(
        packageName: 'com.short',
        timestamp: start,
        eventType: UsageEventTypes.moveToForeground,
      ),
      RawUsageEvent(
        packageName: 'com.short',
        timestamp: start.add(const Duration(seconds: 5)),
        eventType: UsageEventTypes.moveToBackground,
      ),
      RawUsageEvent(
        packageName: 'com.long',
        timestamp: start.add(const Duration(seconds: 15)),
        eventType: UsageEventTypes.moveToForeground,
      ),
      RawUsageEvent(
        packageName: 'com.long',
        timestamp: start.add(const Duration(minutes: 1)),
        eventType: UsageEventTypes.moveToBackground,
      ),
    ];

    final sessions = UsageAggregation.buildSessions(
      events: events,
      rangeStart: start,
      rangeEnd: start.add(const Duration(minutes: 2)),
    );

    final totals = UsageAggregation.aggregateSecondsByPackage(sessions);
    expect(totals.containsKey('com.short'), isFalse);
    expect(UsageAggregation.secondsToMinutes(totals['com.long'] ?? 0), 1);
  });

  test('closes ongoing session at range end', () {
    final start = DateTime(2026, 5, 2, 8, 0);
    final events = [
      RawUsageEvent(
        packageName: 'com.streaming',
        timestamp: start,
        eventType: UsageEventTypes.moveToForeground,
      ),
    ];

    final sessions = UsageAggregation.buildSessions(
      events: events,
      rangeStart: start,
      rangeEnd: start.add(const Duration(minutes: 15)),
    );

    final totals = UsageAggregation.aggregateSecondsByPackage(sessions);
    expect(UsageAggregation.secondsToMinutes(totals['com.streaming'] ?? 0), 15);
  });
}
