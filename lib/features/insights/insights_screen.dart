import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/weekly_report_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _selectedPeriod = 0; // 0=week, 1=month
  int _refreshNonce = 0;
  bool _exporting = false;

  final _firestore = FirestoreService.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _refresh() async {
    setState(() => _refreshNonce++);
  }
  
  String _localizedInsightText(String text) {
    final t = context.l10n;
    if (text.startsWith('Your average wellbeing this period is ')) {
      final value = text
          .replaceFirst('Your average wellbeing this period is ', '')
          .replaceFirst('.', '');
      return '${t.tr('insightAvgWellbeingPrefix')} $value.';
    }
    if (text.startsWith('Average fatigue is ') && text.endsWith(' out of 100.')) {
      final value = text
          .replaceFirst('Average fatigue is ', '')
          .replaceFirst(' out of 100.', '');
      return '${t.tr('insightAvgFatiguePrefix')} $value ${t.tr('insightOutOf100')}.';
    }
    if (text.startsWith('You completed ') && text.contains(' of focus sessions in the last ')) {
      final mid = text
          .replaceFirst('You completed ', '')
          .replaceFirst(' of focus sessions in the last ', '|')
          .replaceFirst(' days.', '');
      final parts = mid.split('|');
      if (parts.length == 2) {
        return '${t.tr('insightFocusCompletedPrefix')} ${parts[0]} ${t.tr('insightFocusCompletedSuffix')} ${parts[1]} ${t.tr('daysWord')}.';
      }
    }
    if (text.startsWith('Productive usage ratio is ') && text.endsWith(' based on your logged data.')) {
      final value = text
          .replaceFirst('Productive usage ratio is ', '')
          .replaceFirst(' based on your logged data.', '');
      return '${t.tr('insightProductiveRatioPrefix')} $value ${t.tr('insightProductiveRatioSuffix')}.';
    }
    return text;
  }

  String _localizedCategoryLabel(String label) {
    final t = context.l10n;
    final lower = label.toLowerCase();
    if (lower.contains('productive')) return t.tr('productive');
    if (lower.contains('entertainment')) return t.tr('entertainment');
    if (lower.contains('social')) return t.tr('social');
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final uid = _uid;
    final days = _selectedPeriod == 0 ? 7 : 30;

    if (uid == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Center(child: Text(t.tr('signInToViewInsights'))),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: StreamBuilder<InsightData>(
        key: ValueKey('insights_stream_$_refreshNonce'),
        stream: _firestore.streamInsights(uid, days: days),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return SafeArea(
              child: Center(
                child: Text(
                  t.tr('insightsLoadFailed'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildSkeleton(height: 48),
                  const SizedBox(height: 12),
                  _buildSkeleton(height: 96),
                  const SizedBox(height: 12),
                  _buildSkeleton(height: 220),
                  const SizedBox(height: 12),
                  _buildSkeleton(height: 180),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final isEmpty =
              data.focusHours == 0 &&
              data.avgFatigue == 0 &&
              data.avgWellbeing == 100 &&
              data.habitConsistency.isEmpty;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.tr('insights'),
                                style: Theme.of(context).textTheme.headlineLarge,
                              ),
                            ),
                            if (_selectedPeriod == 0)
                              IconButton(
                                tooltip: 'Export weekly report',
                                onPressed: _exporting
                                    ? null
                                    : () => _exportWeeklyReport(uid),
                                icon: _exporting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.picture_as_pdf_outlined),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.tr('insightsSubtitle'),
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
                      _buildPeriodToggle(t).animate().fadeIn(delay: 50.ms),
                      const SizedBox(height: 20),

                      if (isEmpty)
                        _buildEmptyState(context, t)
                      else ...[
                        _buildSummaryRow(data)
                            .animate()
                            .fadeIn(delay: 100.ms)
                            .slideY(begin: 0.1),
                        const SizedBox(height: 20),
                        _buildWellbeingChart(data).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 20),
                        _buildProductiveVsDrainingCard(data).animate().fadeIn(
                          delay: 300.ms,
                        ),
                        const SizedBox(height: 20),
                        _buildHabitConsistency(data)
                            .animate()
                            .fadeIn(delay: 400.ms),
                        const SizedBox(height: 20),
                        _buildAIInsightsCard(data).animate().fadeIn(delay: 500.ms),
                      ],
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportWeeklyReport(String uid) async {
    setState(() => _exporting = true);
    try {
      await WeeklyReportService.instance.exportWeeklyReport(
        context: context,
        uid: uid,
        days: 7,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.tr('insightsLoadFailed'))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _buildSkeleton({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadowLight],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Column(
        children: [
          const Text('📊', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(t.tr('noInsightsYet'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            t.tr('unlockInsightsHint'),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodToggle(AppLocalizations t) {
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
              label: t.tr('thisWeek'),
              isSelected: _selectedPeriod == 0,
              onTap: () => setState(() => _selectedPeriod = 0),
            ),
          ),
          Expanded(
            child: _PeriodTab(
              label: t.tr('thisMonth'),
              isSelected: _selectedPeriod == 1,
              onTap: () => setState(() => _selectedPeriod = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(InsightData data) {
    final t = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            emoji: '✨',
            title: t.tr('avgScore'),
            value: data.avgWellbeing.toStringAsFixed(1),
            sub: t.tr('wellbeingWord'),
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            emoji: '😴',
            title: t.tr('avgFatigue'),
            value: data.avgFatigue.toStringAsFixed(1),
            sub: '/ 100',
            color: AppTheme.fatigueModerate,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            emoji: '⏱️',
            title: t.tr('focusShort'),
            value: '${data.focusHours.toStringAsFixed(1)}h',
            sub: _selectedPeriod == 0
                ? t.tr('thisWeekLower')
                : t.tr('thisMonthLower'),
            color: AppTheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWellbeingChart(InsightData data) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.tr('wellbeingTrend'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _buildLegendDot(
                    AppTheme.primary,
                    context.l10n.tr('wellbeingWord'),
                  ),
                  _buildLegendDot(
                    AppTheme.fatigueModerate,
                    context.l10n.tr('fatigueScore'),
                  ),
                ],
              ),
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
                          (v.toInt() >= 0 && v.toInt() < data.labels.length)
                              ? data.labels[v.toInt()]
                              : '',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  // Wellbeing line
                  LineChartBarData(
                    spots: data.wellbeingScores
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
                    spots: data.fatigueScores
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

  Widget _buildProductiveVsDrainingCard(InsightData data) {
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
            context.l10n.tr('productiveVsDraining'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.tr('weeklyAppUsageBreakdown'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),

          _ComparisonBar(
            leftLabel: context.l10n.tr('productive'),
            rightLabel: context.l10n.tr('draining'),
            leftValue: data.productiveRatio,
            rightValue: data.drainingRatio,
            leftColor: AppTheme.primary,
            rightColor: const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 16),

          // Category breakdown
          ...data.categoryRows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(row.$3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _localizedCategoryLabel(row.$1),
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
                      color: Color(row.$3),
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

  Widget _buildHabitConsistency(InsightData data) {
    final habits = data.habitConsistency;

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
            context.l10n.tr('habitConsistency'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedPeriod == 0
                ? context.l10n.tr('past7Days')
                : context.l10n.tr('past30Days'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          if (habits.isEmpty)
            Text(
              context.l10n.tr('noHabitLogsYet'),
              style: Theme.of(context).textTheme.bodySmall,
            ),

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
                              '${h.$3}/${h.$4} ${context.l10n.tr('daysWord')}',
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

  Widget _buildAIInsightsCard(InsightData data) {
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
                context.l10n.tr('weeklyInsights'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...data.insights.asMap().entries.map(
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
                              _localizedInsightText(e.value['text'] ?? ''),
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
