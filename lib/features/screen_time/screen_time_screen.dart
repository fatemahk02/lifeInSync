import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';

class ScreenTimeScreen extends StatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen> {
  int _selectedDay = 6; // today (index 6)

  // Sample weekly data (hours)
  final List<double> _weeklyData = [3.5, 5.2, 4.8, 6.1, 3.9, 7.2, 3.7];
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Sample app list
  final List<Map<String, dynamic>> _apps = [
    {'name': 'Instagram',   'pkg': 'com.instagram.android',
     'mins': 82,  'category': 'Social',        'color': Color(0xFF6C63FF)},
    {'name': 'YouTube',     'pkg': 'com.youtube',
     'mins': 65,  'category': 'Entertainment', 'color': Color(0xFFFF6B6B)},
    {'name': 'WhatsApp',    'pkg': 'com.whatsapp',
     'mins': 45,  'category': 'Social',        'color': Color(0xFF6C63FF)},
    {'name': 'Notion',      'pkg': 'com.notion.id',
     'mins': 38,  'category': 'Productive',    'color': Color(0xFF3DBE7A)},
    {'name': 'Spotify',     'pkg': 'com.spotify',
     'mins': 34,  'category': 'Entertainment', 'color': Color(0xFFFF6B6B)},
    {'name': 'Gmail',       'pkg': 'com.google.android.gm',
     'mins': 22,  'category': 'Productive',    'color': Color(0xFF3DBE7A)},
    {'name': 'Twitter/X',   'pkg': 'com.twitter.android',
     'mins': 18,  'category': 'Social',        'color': Color(0xFF6C63FF)},
  ];

  @override
  Widget build(BuildContext context) {
    final todayHours = _weeklyData[_selectedDay];
    final isOverLimit = todayHours > 6;

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
                    Text('Screen Time',
                      style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 4),
                    Text("Here's how you used your phone",
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

                  // Weekly bar chart
                  _buildWeeklyChart()
                    .animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 20),

                  // Daily limit setter
                  _buildLimitCard()
                    .animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 20),

                  // App breakdown
                  Text('App Breakdown',
                    style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  ..._apps.asMap().entries.map((e) =>
                    _AppUsageTile(app: e.value)
                      .animate().fadeIn(delay: Duration(milliseconds: 350 + e.key * 60))
                      .slideX(begin: 0.1)
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCard(double hours, bool isOver) {
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
            const Text('Today',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 6),
            Text('${hours}h',
              style: const TextStyle(color: Colors.white,
                fontSize: 52, fontWeight: FontWeight.w800, height: 1)),
            const SizedBox(height: 8),
            Text(isOver ? '⚠️  Over daily limit' : '✅  Within daily limit',
              style: const TextStyle(color: Colors.white,
                fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        )),
        Column(children: [
          const Icon(Icons.phone_android_rounded,
            color: Colors.white70, size: 48),
          const SizedBox(height: 8),
          Text('Limit: 6h',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _buildWeeklyChart() {
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
          const Text('This Week',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: 10,
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
                      width: 22,
                      borderRadius: BorderRadius.circular(8),
                    )],
                  )
                ).toList(),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.shade100, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_days[v.toInt()],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: v.toInt() == _selectedDay
                              ? FontWeight.w700 : FontWeight.w500,
                            color: v.toInt() == _selectedDay
                              ? AppTheme.primary : AppTheme.textSecondary,
                          )),
                      ),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchCallback: (event, response) {
                    if (response?.spot != null) {
                      setState(() =>
                        _selectedDay = response!.spot!.touchedBarGroupIndex);
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
                      '${rod.toY}h',
                      const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700)),
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
    double _limit = 6;
    return StatefulBuilder(
      builder: (context, setInner) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [AppTheme.cardShadowLight],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Screen Limit',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Set how much screen time you want per day',
              style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Row(children: [
              Text('${_limit.round()}h',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 28)),
              Expanded(
                child: Slider(
                  value: _limit,
                  min: 1, max: 12, divisions: 11,
                  activeColor: AppTheme.primary,
                  inactiveColor: AppTheme.primary.withOpacity(0.15),
                  onChanged: (v) => setInner(() => _limit = v),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _AppUsageTile extends StatelessWidget {
  final Map<String, dynamic> app;
  const _AppUsageTile({required this.app});

  @override
  Widget build(BuildContext context) {
    final int mins = app['mins'] as int;
    final String name = app['name'] as String;
    final String category = app['category'] as String;
    final Color color = app['color'] as Color;
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
              Text(name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
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