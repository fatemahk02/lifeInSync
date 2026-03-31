import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _selectedPeriod = 0; // 0=week, 1=month

  // Mock weekly wellbeing scores
  final List<double> _wellbeingScores = [62, 71, 58, 75, 68, 82, 78];
  final List<double> _fatigueScores = [42, 38, 55, 30, 45, 22, 35];
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // AI insights
  final List<Map<String, String>> _insights = [
    {
      'emoji': '📈',
      'text':
          'Your wellbeing score improved by 16 points this week. Great progress!',
    },
    {
      'emoji': '🧠',
      'text':
          'You focus better on Thursdays — your highest score was 75 this week.',
    },
    {
      'emoji': '📱',
      'text': 'Social app usage dropped 18% compared to last week. Keep it up!',
    },
    {
      'emoji': '🔥',
      'text': 'Your meditation habit streak is at 21 days — a personal best!',
    },
    {
      'emoji': '⚠️',
      'text':
          'Late-night screen use on Friday spiked your fatigue score by +23 points.',
    },
  ];

  @override
  Widget build(BuildContext context) {
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
                      'Insights',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your weekly wellbeing report',
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
                  // Period selector
                  _buildPeriodToggle().animate().fadeIn(delay: 50.ms),
                  const SizedBox(height: 20),

                  // Summary cards row
                  _buildSummaryRow()
                      .animate()
                      .fadeIn(delay: 100.ms)
                      .slideY(begin: 0.1),
                  const SizedBox(height: 20),

                  // Wellbeing trend chart
                  _buildWellbeingChart().animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 20),

                  // Productive vs Draining
                  _buildProductiveVsDrainingCard().animate().fadeIn(
                    delay: 300.ms,
                  ),
                  const SizedBox(height: 20),

                  // Habit consistency
                  _buildHabitConsistency().animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 20),

                  // AI Insights
                  _buildAIInsightsCard().animate().fadeIn(delay: 500.ms),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodToggle() {
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
            child: _PeriodTab(
              label: 'This Week',
              isSelected: _selectedPeriod == 0,
              onTap: () => setState(() => _selectedPeriod = 0),
            ),
          ),
          Expanded(
            child: _PeriodTab(
              label: 'This Month',
              isSelected: _selectedPeriod == 1,
              onTap: () => setState(() => _selectedPeriod = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            emoji: '✨',
            title: 'Avg Score',
            value: '70.6',
            sub: 'wellbeing',
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            emoji: '😴',
            title: 'Avg Fatigue',
            value: '38',
            sub: '/ 100',
            color: AppTheme.fatigueModerate,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            emoji: '⏱️',
            title: 'Focus',
            value: '12.5h',
            sub: 'this week',
            color: AppTheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWellbeingChart() {
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
          Row(
            children: [
              const Text(
                'Wellbeing Trend',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const Spacer(),
              _buildLegendDot(AppTheme.primary, 'Wellbeing'),
              const SizedBox(width: 12),
              _buildLegendDot(AppTheme.fatigueModerate, 'Fatigue'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _days[v.toInt()],
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  // Wellbeing line
                  LineChartBarData(
                    spots: _wellbeingScores
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 4,
                        color: AppTheme.primary,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withOpacity(0.2),
                          AppTheme.primary.withOpacity(0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Fatigue line
                  LineChartBarData(
                    spots: _fatigueScores
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: true,
                    color: AppTheme.fatigueModerate,
                    barWidth: 2,
                    dashArray: [5, 5],
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductiveVsDrainingCard() {
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
            'Productive vs Draining',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Weekly app usage breakdown',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),

          _ComparisonBar(
            leftLabel: 'Productive',
            rightLabel: 'Draining',
            leftValue: 0.42,
            rightValue: 0.58,
            leftColor: AppTheme.primary,
            rightColor: const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 16),

          // Category breakdown
          ...[
            ('Productive 🎯', '8h 30m', AppTheme.catProductive),
            ('Entertainment 🎬', '6h 20m', AppTheme.catEntertainment),
            ('Social 💬', '5h 10m', AppTheme.catSocial),
            ('Education 📚', '2h 45m', AppTheme.catEducation),
            ('Health ❤️', '1h 20m', AppTheme.catHealth),
          ].map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: row.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    row.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: row.$3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitConsistency() {
    final habits = [
      ('💧', 'Drink Water', 7, 7),
      ('🏃', 'Exercise', 5, 7),
      ('📚', 'Read', 4, 7),
      ('🧘', 'Meditate', 7, 7),
      ('📵', 'No phone 10pm', 3, 7),
    ];

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
            'Habit Consistency',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text('Past 7 days', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),

          ...habits.map((h) {
            final pct = h.$3 / h.$4;
            final color = pct >= 0.85
                ? AppTheme.primary
                : pct >= 0.57
                ? AppTheme.fatigueMild
                : AppTheme.fatigueModerate;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(h.$1, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              h.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${h.$3}/${h.$4} days',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 7,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ],
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

  Widget _buildAIInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.secondary.withOpacity(0.08),
            AppTheme.secondary.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.secondary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Weekly Insights',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._insights.asMap().entries.map(
            (e) =>
                Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.value['emoji']!,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              e.value['text']!,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 550 + e.key * 80))
                    .slideX(begin: 0.05),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    ],
  );
}

// ── Supporting Widgets ────────────────────────────────────────

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String value;
  final String sub;
  final Color color;

  const _SummaryCard({
    required this.emoji,
    required this.title,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: color,
            ),
          ),
          Text('$title $sub', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final double leftValue;
  final double rightValue;
  final Color leftColor;
  final Color rightColor;

  const _ComparisonBar({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftValue,
    required this.rightValue,
    required this.leftColor,
    required this.rightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              leftLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: leftColor,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              rightLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: rightColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                flex: (leftValue * 100).round(),
                child: Container(height: 14, color: leftColor),
              ),
              Expanded(
                flex: (rightValue * 100).round(),
                child: Container(height: 14, color: rightColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${(leftValue * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: leftColor,
              ),
            ),
            const Spacer(),
            Text(
              '${(rightValue * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: rightColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
