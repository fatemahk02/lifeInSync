import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/app_preferences_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/notification_service.dart';
import '../../shared/services/screen_time_service.dart';
import '../app_categorizer/category_rules_engine.dart';

class ScreenTimeScreen extends StatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen> {
  final _screenTimeService = ScreenTimeService.instance;
  final _notifications = NotificationService.instance;
  final _firestore = FirestoreService.instance;

  int _selectedDay = DateTime.now().weekday - 1; // 0=Mon
  int _selectedWeekOffset = 0; // 0=this week, 1=last week
  double _dailyLimit = 6;
  bool _isLoading = true;
  bool _hasPermission = true;
  double _todayHours = 0;

  // Real weekly usage data (hours)
  List<double> _weeklyData = List<double>.filled(7, 0);
  List<String> _days = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  List<DailyUsageBucket> _weeklyBuckets = const <DailyUsageBucket>[];

  List<ScreenUsageEntry> _apps = const <ScreenUsageEntry>[];

  @override
  void initState() {
    super.initState();
    _loadInitialSettings();
  }

  Future<void> _loadInitialSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _dailyLimit = await AppPreferencesService.instance.getDailyLimitHours(uid);
    }
    if (mounted) setState(() {});
    await _loadUsageData();
  }

  Future<void> _loadUsageData() async {
    setState(() => _isLoading = true);
    final hasPermission = await _screenTimeService.hasUsagePermission();

    if (!hasPermission) {
      setState(() {
        _hasPermission = false;
        _weeklyData = List<double>.filled(7, 0);
        _apps = const <ScreenUsageEntry>[];
        _todayHours = 0;
        _isLoading = false;
      });
      return;
    }

    final now = DateTime.now();
    final weekStart = _weekStartFor(now)
        .subtract(Duration(days: 7 * _selectedWeekOffset));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final today = DateTime(now.year, now.month, now.day);
    final todayIndex = _todayIndex();

    final trackingStart = await _screenTimeService.getUsageTrackingStart();
    final effectiveStart = trackingStart.isAfter(weekStart)
        ? trackingStart
        : weekStart;

    final buckets = await _screenTimeService.getDailyUsageBucketsForRange(
      start: effectiveStart,
      end: weekEnd,
    );

    final dataByKey = {
      for (final b in buckets) _dateKey(b.date): b,
    };

    final weekly = <double>[];
    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      if (_selectedWeekOffset == 0 && day.isAfter(today)) {
        weekly.add(0);
        continue;
      }

      final bucket = dataByKey[_dateKey(day)];
      weekly.add((bucket?.totalMinutes ?? 0) / 60);
    }

    final days = _buildWeekLabels(weekStart);
    final selectedIndex = _selectedWeekOffset == 0
        ? todayIndex
        : _selectedDay.clamp(0, 6);
    final selectedBucket = dataByKey[_dateKey(weekStart.add(
      Duration(days: selectedIndex),
    ))];
    final apps = selectedBucket?.apps ?? const <ScreenUsageEntry>[];

    final todayStart = DateTime(now.year, now.month, now.day);
    final todayUsage = await _screenTimeService.getUsageForRange(
      start: todayStart,
      end: now,
    );
    final todayMinutes = todayUsage.fold<int>(0, (sum, e) => sum + e.usageMinutes);

    if (!mounted) return;
    setState(() {
      _hasPermission = true;
      _weeklyData = weekly;
      _days = days;
      _weeklyBuckets = buckets;
      _apps = apps;
      _selectedDay = selectedIndex;
      _todayHours = todayMinutes / 60;
      _isLoading = false;
    });

    unawaited(
      _notifications.maybeNotifyScreenTimeWarning(
        todayHours: _weeklyData.last,
        dailyLimitHours: _dailyLimit,
      ),
    );
  }

  List<String> _buildWeekLabels(DateTime weekStart) {
    const week = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List<String>.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      return week[day.weekday - 1];
    }, growable: false);
  }

  DateTime _weekStartFor(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  int _todayIndex() {
    final now = DateTime.now();
    return now.weekday - 1;
  }

  String _dateKey(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final todayHours = _todayHours;
    final isOverLimit = todayHours > _dailyLimit;
    final t = context.l10n;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.tr('screenTimeTitle'),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(t.tr('screenTimeSubtitle'),
                      style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // Today's total
                  _buildTodayCard(todayHours, isOverLimit)
                    .animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
                  const SizedBox(height: 20),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Center(child: CircularProgressIndicator()),
                    ),

                  if (!_hasPermission)
                    _buildPermissionCard()
                        .animate()
                        .fadeIn(delay: 140.ms)
                        .slideY(begin: 0.08),

                  if (!_hasPermission) const SizedBox(height: 20),

                  // Weekly bar chart
                  _buildWeekSelector()
                    .animate().fadeIn(delay: 190.ms),
                  const SizedBox(height: 12),
                  _buildWeeklyChart()
                    .animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 20),

                  // Daily limit setter
                  _buildLimitCard()
                    .animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 20),

                  // App breakdown
                  Text(t.tr('appBreakdown'),
                    style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  if (_apps.isEmpty && !_isLoading)
                    Text(
                      _hasPermission
                          ? t.tr('noUsageToday')
                          : t.tr('grantUsagePermission'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ..._apps.asMap().entries.map(
                    (e) => _AppUsageTile(app: e.value)
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: 350 + e.key * 60))
                        .slideX(begin: 0.1),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard() {
    final t = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.tr('usageAccessNeeded'),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            t.tr('usageAccessPrompt'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  await _screenTimeService.openUsageAccessSettings();
                  await _loadUsageData();
                },
                child: Text(t.tr('openSettings')),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _loadUsageData,
                child: Text(t.tr('refresh')),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildTodayCard(double hours, bool isOver) {
    final t = context.l10n;
    final hoursLabel = hours >= 10
        ? hours.toStringAsFixed(1)
        : hours.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOver
            ? [const Color(0xFFE05C5C), const Color(0xFFB83535)]
            : [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
          color: (isOver ? AppTheme.error : AppTheme.primary).withOpacity(0.3),
          blurRadius: 20, offset: const Offset(0, 8),
        )],
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.tr('today'),
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 6),
            Text('${hoursLabel}h',
              style: const TextStyle(color: Colors.white,
                fontSize: 52, fontWeight: FontWeight.w800, height: 1)),
            const SizedBox(height: 8),
            Text(
              isOver
                  ? '⚠️  ${t.tr('overDailyLimit')}'
                  : '✅  ${t.tr('withinDailyLimit')}',
              style: const TextStyle(color: Colors.white,
                fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        )),
        Column(children: [
          const Icon(Icons.phone_android_rounded,
            color: Colors.white70, size: 48),
          const SizedBox(height: 8),
          Text('Limit: ${_dailyLimit.round()}h',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _buildWeekSelector() {
    final selected = _selectedWeekOffset;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Row(
        children: [
          Expanded(
            child: _WeekTab(
              label: context.l10n.tr('thisWeek'),
              isSelected: selected == 0,
              onTap: () async {
                setState(() {
                  _selectedWeekOffset = 0;
                  _selectedDay = _todayIndex();
                });
                await _loadUsageData();
              },
            ),
          ),
          Expanded(
            child: _WeekTab(
              label: 'Last week',
              isSelected: selected == 1,
              onTap: () async {
                setState(() {
                  _selectedWeekOffset = 1;
                  _selectedDay = 6;
                });
                await _loadUsageData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final t = context.l10n;
    final maxUsage = _weeklyData.fold<double>(0, (m, v) => v > m ? v : m);
    final normalizedTop = (maxUsage + 1.5).clamp(6.0, 24.0);
    final chartMaxY = (normalizedTop / 2).ceil() * 2.0;
    final chartHeight = chartMaxY > 14 ? 205.0 : 188.0;
    final yInterval = chartMaxY <= 12 ? 2.0 : (chartMaxY <= 18 ? 3.0 : 4.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_selectedWeekOffset == 0 ? t.tr('thisWeek') : 'Last week',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            t.tr('tapBarToInspectDay'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: chartHeight,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: chartMaxY,
                barGroups: _weeklyData.asMap().entries.map((e) =>
                  BarChartGroupData(
                    x: e.key,
                    barRods: [BarChartRodData(
                      toY: e.value,
                      color: e.key == _selectedDay
                        ? AppTheme.primary
                        : e.value > 6
                          ? AppTheme.error.withOpacity(0.6)
                          : AppTheme.primary.withOpacity(0.35),
                      width: 18,
                      borderRadius: BorderRadius.circular(8),
                    )],
                  )
                ).toList(),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.shade100, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: yInterval,
                      getTitlesWidget: (value, _) {
                        if (value == 0 || value == chartMaxY || value % yInterval == 0) {
                          return Text(
                            '${value.toInt()}h',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          (v.toInt() >= 0 && v.toInt() < _days.length)
                              ? _days[v.toInt()]
                              : '',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: v.toInt() == _selectedDay
                              ? FontWeight.w700 : FontWeight.w500,
                            color: v.toInt() == _selectedDay
                              ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    if (!event.isInterestedForInteractions || response == null) {
                      return;
                    }
                    final index = response.spot?.touchedBarGroupIndex;
                    if (index == null || index < 0 || index >= 7) return;

                    final weekStart = _weekStartFor(DateTime.now())
                        .subtract(Duration(days: 7 * _selectedWeekOffset));
                    final day = weekStart.add(Duration(days: index));
                    final bucket = _weeklyBuckets.firstWhere(
                      (b) => _dateKey(b.date) == _dateKey(day),
                      orElse: () => DailyUsageBucket(
                        date: day,
                        totalMinutes: 0,
                        apps: const <ScreenUsageEntry>[],
                      ),
                    );

                    setState(() {
                      _selectedDay = index;
                      _apps = bucket.apps;
                    });
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
                      '${rod.toY.toStringAsFixed(1)}h',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitCard() {
    final t = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.tr('dailyScreenLimit'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(t.tr('setDailyScreenTimeHint'),
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Row(children: [
            Text('${_dailyLimit.round()}h',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 28)),
            Expanded(
              child: Slider(
                value: _dailyLimit,
                min: 1, max: 12, divisions: 11,
                activeColor: AppTheme.primary,
                inactiveColor: AppTheme.primary.withOpacity(0.15),
                onChanged: (v) => setState(() => _dailyLimit = v),
                onChangeEnd: (v) {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    unawaited(
                      AppPreferencesService.instance.setDailyLimitHours(uid, v),
                    );
                  }
                  unawaited(
                    _notifications.maybeNotifyScreenTimeWarning(
                      todayHours: _weeklyData.last,
                      dailyLimitHours: v,
                    ),
                  );
                },
              ),
            ),
          ]),
        ],
      ),
    );
  }

}

class _WeekTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _WeekTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppUsageTile extends StatelessWidget {
  final ScreenUsageEntry app;
  const _AppUsageTile({required this.app});

  @override
  Widget build(BuildContext context) {
    final int mins = app.usageMinutes;
    final String name = app.appName;
    final categoryObj = CategoryRulesEngine.categorize(app.packageName, app.appName);
    final String category = categoryObj.label;
    final Color color = categoryObj.color;
    final double barValue = (mins / 120).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(name[0],
              style: TextStyle(fontWeight: FontWeight.w800,
                color: color, fontSize: 18)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(category,
                  style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w600, color: color)),
              ),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: barValue,
                minHeight: 5,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        )),
        const SizedBox(width: 12),
        Text(mins >= 60
          ? '${mins ~/ 60}h ${mins % 60}m'
          : '${mins}m',
          style: TextStyle(fontWeight: FontWeight.w700,
            color: color, fontSize: 13)),
      ]),
    );
  }
}