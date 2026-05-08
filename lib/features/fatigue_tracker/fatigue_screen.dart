import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import 'fatigue_detector.dart';
import '../../shared/services/fastapi_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/notification_service.dart';
import '../../shared/services/screen_time_service.dart';

class FatigueScreen extends StatefulWidget {
  const FatigueScreen({super.key});

  @override
  State<FatigueScreen> createState() => _FatigueScreenState();
}

class _FatigueScreenState extends State<FatigueScreen> {
  final _firestore = FirestoreService.instance;
  final _screenTimeService = ScreenTimeService.instance;
  final _fastApi = FastApiService.instance;
  final _notifications = NotificationService.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool _isLoading = true;
  bool _hasUsagePermission = true;
  DateTime? _trackingStart;

  FatigueResult _result = FatigueDetector.analyze(
    totalScreenMinutes: 0,
    socialMinutes: 0,
    entertainmentMinutes: 0,
    gamingMinutes: 0,
    lateNightMinutes: 0,
    longestSessionMinutes: 0,
    focusSessionsCompleted: 0,
    habitsCompleted: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadDailyFatigue();
  }

  List<String> _buildLast7DayLabels() {
    final t = context.l10n;
    final week = <String>[
      t.tr('mon'),
      t.tr('tue'),
      t.tr('wed'),
      t.tr('thu'),
      t.tr('fri'),
      t.tr('sat'),
      t.tr('sun'),
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return List<String>.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return week[day.weekday - 1];
    }, growable: false);
  }

  String _localizedLevelLabel() {
    final t = context.l10n;
    switch (_result.level) {
      case FatigueLevel.fresh:
        return t.tr('fatigueLevelFresh');
      case FatigueLevel.mild:
        return t.tr('fatigueLevelMild');
      case FatigueLevel.moderate:
        return t.tr('fatigueLevelModerate');
      case FatigueLevel.high:
        return t.tr('fatigueLevelHigh');
    }
  }

  String _localizedRecommendation(String recommendation) {
    final t = context.l10n;
    if (recommendation ==
        "You're in great shape! Your digital habits are healthy today.") {
      return t.tr('fatigueRecoFresh');
    }
    if (recommendation ==
        'Mild fatigue detected. Try a short walk or stretch break.') {
      return t.tr('fatigueRecoMild');
    }
    if (recommendation ==
        'Moderate fatigue. Step away from screens for 30+ minutes.') {
      return t.tr('fatigueRecoModerate');
    }
    if (recommendation ==
        'High digital fatigue. Rest your eyes, go outside, and avoid screens for a while.') {
      return t.tr('fatigueRecoHigh');
    }
    return recommendation;
  }

  String _localizedTriggerText(FatigueTrigger trigger) {
    final t = context.l10n;
    final text = trigger.text;

    if (text.startsWith('High screen time (') && text.endsWith(' today)')) {
      final value = text
          .replaceFirst('High screen time (', '')
          .replaceFirst(' today)', '');
      return '${t.tr('fatigueTriggerHighScreenTime')} ($value ${t.tr('today')})';
    }
    if (text.startsWith('Late-night usage detected (') &&
        text.endsWith(' after 10pm)')) {
      final value = text
          .replaceFirst('Late-night usage detected (', '')
          .replaceFirst(' after 10pm)', '');
      return '${t.tr('fatigueTriggerLateNight')} ($value ${t.tr('after10pm')})';
    }
    if (text.startsWith('Long unbroken session (') &&
        text.endsWith(' without break)')) {
      final value = text
          .replaceFirst('Long unbroken session (', '')
          .replaceFirst(' without break)', '');
      return '${t.tr('fatigueTriggerLongSession')} ($value ${t.tr('withoutBreak')})';
    }
    if (text.startsWith('Heavy social/entertainment use (') &&
        text.endsWith(')')) {
      final value = text
          .replaceFirst('Heavy social/entertainment use (', '')
          .replaceFirst(')', '');
      return '${t.tr('fatigueTriggerHeavyDraining')} ($value)';
    }
    if (text == 'No focus sessions completed today') {
      return t.tr('fatigueTriggerNoFocusToday');
    }

    return text;
  }

  Future<void> _loadDailyFatigue() async {
    try {
      _trackingStart = await _screenTimeService.getUsageTrackingStart();

      final hasPermission = await _screenTimeService
          .hasUsagePermission()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      _hasUsagePermission = hasPermission;

      FatigueUsageInputs usage = const FatigueUsageInputs(
        totalScreenMinutes: 0,
        socialMinutes: 0,
        entertainmentMinutes: 0,
        gamingMinutes: 0,
        lateNightMinutes: 0,
        longestSessionMinutes: 0,
      );

      if (hasPermission) {
        try {
          usage = await _screenTimeService
              .getFatigueUsageInputsForToday()
              .timeout(const Duration(seconds: 8));
        } catch (_) {
          // Continue with partial data when usage APIs are flaky.
        }
      }

      DailyBehaviorMetrics daily;
      try {
        daily = await _loadDailyBehaviorMetrics().timeout(
          const Duration(seconds: 8),
          onTimeout: () => const DailyBehaviorMetrics(
            focusSessionsCompleted: 0,
            habitsCompleted: 0,
            hasFocusSessionToday: false,
          ),
        );
      } catch (_) {
        daily = const DailyBehaviorMetrics(
          focusSessionsCompleted: 0,
          habitsCompleted: 0,
          hasFocusSessionToday: false,
        );
      }

      final computed = FatigueDetector.analyze(
        totalScreenMinutes: usage.totalScreenMinutes,
        socialMinutes: usage.socialMinutes,
        entertainmentMinutes: usage.entertainmentMinutes,
        gamingMinutes: usage.gamingMinutes,
        lateNightMinutes: usage.lateNightMinutes,
        longestSessionMinutes: usage.longestSessionMinutes,
        focusSessionsCompleted: daily.focusSessionsCompleted,
        habitsCompleted: daily.habitsCompleted,
      );

      if (!mounted) return;
      setState(() {
        _result = computed;
      });

      await _saveDailyFatigue(computed);
      await _notifications.maybeNotifyFatigueRecommendation(
        fatigueScore: computed.score,
        recommendation: computed.recommendation,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<DailyBehaviorMetrics> _loadDailyBehaviorMetrics() async {
    final uid = _uid;
    if (uid == null) {
      return const DailyBehaviorMetrics(
        focusSessionsCompleted: 0,
        habitsCompleted: 0,
        hasFocusSessionToday: false,
      );
    }

    try {
      return await _fastApi.getDailyBehaviorMetrics(uid: uid);
    } catch (_) {
      final focusCount = await _firestore.getCompletedFocusSessionsToday(uid);
      final habitCount = await _firestore.getCompletedHabitsToday(uid);
      return DailyBehaviorMetrics(
        focusSessionsCompleted: focusCount,
        habitsCompleted: habitCount,
        hasFocusSessionToday: focusCount > 0,
      );
    }
  }

  Future<void> _saveDailyFatigue(FatigueResult result) async {
    final uid = _uid;
    if (uid == null) return;

    final breakdown = {
      'screenTimeScore': result.breakdown.screenTimeScore,
      'drainingAppsScore': result.breakdown.drainingAppsScore,
      'lateNightScore': result.breakdown.lateNightScore,
      'longSessionScore': result.breakdown.longSessionScore,
      'healthyDeduction': result.breakdown.healthyDeduction,
    };

    final triggers = result.triggers
        .map(
          (t) => {
            'icon': t.icon,
            'text': t.text,
            'severity': t.severity.name,
          },
        )
        .toList(growable: false);

    try {
      await _firestore.saveFatigueScore(
        uid: uid,
        date: DateTime.now(),
        score: result.score,
        level: result.level.name,
        breakdown: breakdown,
        triggers: triggers,
        recommendation: result.recommendation,
      );
    } catch (_) {
      // Ignore transient write failures to keep UI responsive.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final color = Color(_result.level.colorValue);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.tr('fatigueTracker'),
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.tr('fatigueAutoDetected'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (!_hasUsagePermission) ...[
                          _buildUsagePermissionHint(),
                          const SizedBox(height: 20),
                        ],
                        // Score card
                        _buildScoreCard(color)
                            .animate()
                            .fadeIn(delay: 100.ms)
                            .scale(begin: const Offset(0.95, 0.95)),
                        const SizedBox(height: 20),

                        // Score breakdown
                        _buildBreakdownCard()
                            .animate()
                            .fadeIn(delay: 200.ms)
                            .slideY(begin: 0.1),
                        const SizedBox(height: 20),

                        // 7-day chart
                        StreamBuilder<List<FatigueLog>>(
                          stream: _uid == null
                              ? null
                              : (() {
                                  final now = DateTime.now();
                                  final defaultStart = DateTime(now.year, now.month, now.day)
                                      .subtract(const Duration(days: 6));
                                  final customStart = (_trackingStart != null &&
                                          _trackingStart!.isAfter(defaultStart))
                                      ? _trackingStart!
                                      : defaultStart;
                                  return _firestore.streamFatigueHistory(
                                    _uid!,
                                    days: 7,
                                    startDate: customStart,
                                  );
                                })(),
                          builder: (context, snapshot) {
                            final values = _historyFromLogs(snapshot.data);
                            return _buildWeekChart(values)
                                .animate()
                                .fadeIn(delay: 300.ms);
                          },
                        ),
                        const SizedBox(height: 20),

                        // Triggers
                        if (_result.triggers.isNotEmpty) ...[
                          _buildTriggersCard().animate().fadeIn(delay: 400.ms),
                          const SizedBox(height: 20),
                        ],

                        // Recommendation
                        _buildRecommendationCard(
                          color,
                        ).animate().fadeIn(delay: 500.ms),
                        const SizedBox(height: 32),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildUsagePermissionHint() {
    final t = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.tr('fatigueUsageLimited'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () async {
              await _screenTimeService.openUsageAccessSettings();
              await _loadDailyFatigue();
            },
            child: Text(t.tr('enable')),
          ),
        ],
      ),
    );
  }

  List<int> _historyFromLogs(List<FatigueLog>? logs) {
    if (logs == null || logs.isEmpty) {
      return const <int>[];
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final byDay = <String, int>{
      for (final l in logs)
        _dateKey(l.date): l.score,
    };

    return List<int>.generate(7, (i) {
      final day = start.add(Duration(days: i));
      return byDay[_dateKey(day)] ?? 0;
    }, growable: false);
  }

  static String _dateKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Widget _buildScoreCard(Color color) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Emoji + level
          Text(
            _result.level.emoji,
            style: const TextStyle(fontSize: 60),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 12),
          Text(
            _localizedLevelLabel(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 20),

          // Big gauge ring
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 12,
                    valueColor: AlwaysStoppedAnimation(color.withOpacity(0.12)),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: _result.score / 100,
                    strokeWidth: 12,
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_result.score}',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    Text('/ 100', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(context.l10n.tr('fatigueScore'), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard() {
    final b = _result.breakdown;
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
          Text(
            context.l10n.tr('scoreBreakdown'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          _ScoreRow(
            label: context.l10n.tr('screenTimeTitle'),
            value: b.screenTimeScore,
            max: 30,
            color: const Color(0xFF6C63FF),
          ),
          _ScoreRow(
            label: context.l10n.tr('drainingApps'),
            value: b.drainingAppsScore,
            max: 25,
            color: const Color(0xFFFF6B6B),
          ),
          _ScoreRow(
            label: context.l10n.tr('lateNightUse'),
            value: b.lateNightScore,
            max: 20,
            color: const Color(0xFFFF8A65),
          ),
          _ScoreRow(
            label: context.l10n.tr('longSessions'),
            value: b.longSessionScore,
            max: 15,
            color: const Color(0xFFFFCA28),
          ),
          _ScoreRow(
            label: context.l10n.tr('healthyHabitsMinus'),
            value: b.healthyDeduction,
            max: 25,
            color: AppTheme.primary,
            isDeduction: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekChart(List<int> weekHistory) {
    final days = _buildLast7DayLabels();

    if (weekHistory.isEmpty) {
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
            Text(
              context.l10n.tr('fatigueHistory7Days'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tr('noFatigueDataYet'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

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
          Text(
            context.l10n.tr('fatigueHistory7Days'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekHistory.asMap().entries.map((e) {
              final score = e.value;
              final isToday = e.key == 6;
              final barColor = score < 25
                  ? AppTheme.fatigueFresh
                  : score < 50
                  ? AppTheme.fatigueMild
                  : score < 75
                  ? AppTheme.fatigueModerate
                  : AppTheme.fatigueHigh;
              final barHeight = (score / 100 * 100).clamp(8.0, 100.0);

              return Column(
                children: [
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Text(
                      '$score',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 500 + e.key * 80),
                    curve: Curves.easeOutCubic,
                    width: 28,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: isToday ? barColor : barColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    days[e.key],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                      color: isToday ? barColor : AppTheme.textSecondary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTriggersCard() {
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
          Text(
            context.l10n.tr('fatigueTriggers'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 14),
          ..._result.triggers.map((t) {
            final severityColor = t.severity == TriggerSeverity.high
                ? AppTheme.fatigueHigh
                : t.severity == TriggerSeverity.medium
                ? AppTheme.fatigueModerate
                : AppTheme.fatigueMild;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: severityColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Text(t.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _localizedTriggerText(t),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: severityColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.tr('recommendation'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  _localizedRecommendation(_result.recommendation),
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  final bool isDeduction;

  const _ScoreRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    this.isDeduction = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                isDeduction ? '−$value' : '+$value',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDeduction ? AppTheme.primary : color,
                ),
              ),
              Text(' / $max', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value / max,
              minHeight: 7,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(
                isDeduction ? AppTheme.primary : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
