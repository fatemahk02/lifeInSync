import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import 'fatigue_detector.dart';

class FatigueScreen extends StatefulWidget {
  const FatigueScreen({super.key});

  @override
  State<FatigueScreen> createState() => _FatigueScreenState();
}

class _FatigueScreenState extends State<FatigueScreen> {
  // Sample data — in production wire from app_usage + DB
  late final FatigueResult _result = FatigueDetector.analyze(
    totalScreenMinutes: 220,
    socialMinutes: 82,
    entertainmentMinutes: 65,
    gamingMinutes: 0,
    lateNightMinutes: 40,
    longestSessionMinutes: 95,
    focusSessionsCompleted: 2,
    habitsCompleted: 3,
  );

  // Mock 7-day history
  final List<int> _weekHistory = [18, 45, 62, 38, 71, 55, 48];
  final List<String> _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final color = Color(_result.level.colorValue);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fatigue Tracker',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Auto-detected from your usage patterns',
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
                  _buildWeekChart().animate().fadeIn(delay: 300.ms),
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
            _result.level.label,
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
          Text('Fatigue Score', style: Theme.of(context).textTheme.bodySmall),
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
          const Text(
            'Score Breakdown',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          _ScoreRow(
            label: 'Screen Time',
            value: b.screenTimeScore,
            max: 30,
            color: const Color(0xFF6C63FF),
          ),
          _ScoreRow(
            label: 'Draining Apps',
            value: b.drainingAppsScore,
            max: 25,
            color: const Color(0xFFFF6B6B),
          ),
          _ScoreRow(
            label: 'Late-Night Use',
            value: b.lateNightScore,
            max: 20,
            color: const Color(0xFFFF8A65),
          ),
          _ScoreRow(
            label: 'Long Sessions',
            value: b.longSessionScore,
            max: 15,
            color: const Color(0xFFFFCA28),
          ),
          _ScoreRow(
            label: 'Healthy Habits (−)',
            value: b.healthyDeduction,
            max: 25,
            color: AppTheme.primary,
            isDeduction: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekChart() {
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
          const Text(
            '7-Day Fatigue History',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _weekHistory.asMap().entries.map((e) {
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
                    _days[e.key],
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
          const Text(
            'Fatigue Triggers',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
                      t.text,
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
                const Text(
                  'Recommendation',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  _result.recommendation,
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
