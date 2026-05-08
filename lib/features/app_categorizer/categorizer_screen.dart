import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import 'category_rules_engine.dart';
import '../../shared/services/screen_time_service.dart';

class AppInfo {
  final String name;
  final String packageName;
  final int usageMinutes;
  final AppCategory category;

  AppInfo({
    required this.name,
    required this.packageName,
    required this.usageMinutes,
  }) : category = CategoryRulesEngine.categorize(packageName, name);
}

class CategorizerScreen extends StatefulWidget {
  const CategorizerScreen({super.key});

  @override
  State<CategorizerScreen> createState() => _CategorizerScreenState();
}

class _CategorizerScreenState extends State<CategorizerScreen> {
  AppCategory? _selectedFilter;
  int? _touchedIndex;
  final _screenTimeService = ScreenTimeService.instance;
  bool _isLoading = true;
  bool _hasPermission = true;

  List<AppInfo> _apps = const <AppInfo>[];

  @override
  void initState() {
    super.initState();
    _loadUsageData();
  }

  Future<void> _loadUsageData() async {
    setState(() => _isLoading = true);
    final hasPermission = await _screenTimeService.hasUsagePermission();

    if (!hasPermission) {
      setState(() {
        _hasPermission = false;
        _apps = const <AppInfo>[];
        _isLoading = false;
      });
      return;
    }

    final usageEntries = await _screenTimeService.getTodayUsage(
      top: 30,
      minUsageMinutes: 2,
    );
    final apps = usageEntries
        .map(
          (e) => AppInfo(
            name: e.appName,
            packageName: e.packageName,
            usageMinutes: e.usageMinutes,
          ),
        )
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _hasPermission = true;
      _apps = apps;
      _isLoading = false;
    });
  }

  List<AppInfo> get _filteredApps => _selectedFilter == null
      ? _apps
      : _apps.where((a) => a.category == _selectedFilter).toList();

  Map<AppCategory, int> get _categoryTotals {
    final map = <AppCategory, int>{};
    for (final app in _apps) {
      map[app.category] = (map[app.category] ?? 0) + app.usageMinutes;
    }
    return map;
  }

  int get _totalMinutes => _apps.fold(0, (sum, a) => sum + a.usageMinutes);

  int get _drainingMinutes => _apps
      .where(
        (a) =>
            a.category == AppCategory.social ||
            a.category == AppCategory.entertainment ||
            a.category == AppCategory.gaming,
      )
      .fold(0, (sum, a) => sum + a.usageMinutes);

  // Healthy ratio is derived as total usage minus explicitly draining usage.
  int get _healthyMinutes => (_totalMinutes - _drainingMinutes).clamp(0, _totalMinutes);

  String _categoryLabel(AppCategory category) {
    final t = context.l10n;
    switch (category) {
      case AppCategory.productive:
        return t.tr('productive');
      case AppCategory.entertainment:
        return t.tr('entertainment');
      case AppCategory.social:
        return t.tr('social');
      default:
        return category.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.tr('appCategories'),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.tr('autoCategorizedByUsage'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

            // ── Body ─────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Health ratio banner
                  _buildHealthRatioCard()
                      .animate()
                      .fadeIn(delay: 100.ms)
                      .slideY(begin: 0.1),
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

                  // Pie chart — FIXED center layout
                  _buildPieChart().animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 20),

                  // Filter chips
                  _buildFilterChips().animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 16),

                  if (_filteredApps.isEmpty && !_isLoading)
                    Text(
                      _hasPermission
                          ? t.tr('noUsageToday')
                          : t.tr('grantUsagePermissionCategories'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (_filteredApps.isEmpty && !_isLoading)
                    const SizedBox(height: 12),

                  // App list
                  ..._filteredApps.asMap().entries.map(
                    (e) => _AppCategoryTile(
                      app: e.value,
                      categoryLabel: _categoryLabel(e.value.category),
                    )
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: 350 + e.key * 50))
                        .slideX(begin: 0.1),
                  ),

                  const SizedBox(height: 24),
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

  // ── Health Ratio Card ─────────────────────────────────────
  Widget _buildHealthRatioCard() {
    final t = context.l10n;
    final healthyPct = _totalMinutes == 0
        ? 0
        : (_healthyMinutes / _totalMinutes * 100).round();
    final healthyTime = '${_healthyMinutes ~/ 60}h ${_healthyMinutes % 60}m';
    final drainingMins = _drainingMinutes;
    final drainingTime = '${drainingMins ~/ 60}h ${drainingMins % 60}m';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3DBE7A), Color(0xFF2A8F58)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [AppTheme.primaryShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Text(
            t.tr('usageHealth'),
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // Big percentage
          Text(
            '$healthyPct% ${t.tr('healthy')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: healthyPct / 100,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 14),

          // Two stat pills side by side — BELOW the bar, not on the right
          Row(
            children: [
              _StatPill(emoji: '🎯', label: t.tr('healthy'), value: healthyTime),
              const SizedBox(width: 10),
              _StatPill(emoji: '📱', label: t.tr('draining'), value: drainingTime),
            ],
          ),
        ],
      ),
    );
  }

  // ── Pie Chart — FULLY FIXED ────────────────────────────────
  Widget _buildPieChart() {
    final totals = _categoryTotals;
    final entries = totals.entries.toList();

    // Build sections
    final sections = entries.asMap().entries.map((indexed) {
      final i = indexed.key;
      final e = indexed.value;
      final pct = _totalMinutes == 0 ? 0.0 : e.value / _totalMinutes;
      final isTouched = _touchedIndex == i;

      return PieChartSectionData(
        value: e.value.toDouble(),
        color: e.key.color,
        title: pct > 0.07 ? '${(pct * 100).round()}%' : '',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        // Slightly expand touched section
        radius: isTouched ? 72 : 62,
        titlePositionPercentageOffset: 0.6,
      );
    }).toList();

    return Container(
      width: double.infinity, // take full card width
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // center everything
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title left-aligned
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.l10n.tr('categoryBreakdown'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),

          // ── Pie Chart centered with fixed square size ──────
          SizedBox(
            width: double.infinity,
            height: 220,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 48,
                sectionsSpace: 3,
                startDegreeOffset: -90,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touchedIndex = null;
                        return;
                      }
                      _touchedIndex =
                          response.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
              ),
              swapAnimationDuration: const Duration(milliseconds: 400),
              swapAnimationCurve: Curves.easeInOut,
            ),
          ),

          const SizedBox(height: 24),

          // ── Legend — 2-column Wrap, centered ──────────────
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: entries.map((e) {
              final mins = e.value;
              final hStr = mins ~/ 60;
              final mStr = mins % 60;
              final timeStr = hStr > 0 ? '${hStr}h ${mStr}m' : '${mStr}m';

              return SizedBox(
                width: (MediaQuery.of(context).size.width - 88) / 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: e.key.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _categoryLabel(e.key),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: e.key.color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Filter Chips ──────────────────────────────────────────
  Widget _buildFilterChips() {
    final categories = _apps.map((a) => a.category).toSet().toList();

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _FilterChip(
              label: context.l10n.tr('all'),
              isSelected: _selectedFilter == null,
              color: AppTheme.primary,
              onTap: () => setState(() => _selectedFilter = null),
            );
          }
          final cat = categories[i - 1];
          return _FilterChip(
            label: _categoryLabel(cat),
            isSelected: _selectedFilter == cat,
            color: cat.color,
            onTap: () => setState(
              () => _selectedFilter = _selectedFilter == cat ? null : cat,
            ),
          );
        },
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.grey.shade200),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── App Category Tile ─────────────────────────────────────────
class _AppCategoryTile extends StatelessWidget {
  final AppInfo app;
  final String categoryLabel;

  const _AppCategoryTile({required this.app, required this.categoryLabel});

  @override
  Widget build(BuildContext context) {
    final color = app.category.color;
    final barValue = (app.usageMinutes / 120).clamp(0.0, 1.0);
    final timeStr = app.usageMinutes >= 60
        ? '${app.usageMinutes ~/ 60}h ${app.usageMinutes % 60}m'
        : '${app.usageMinutes}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Row(
        children: [
          // App icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                app.name[0],
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        app.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(app.category.icon, size: 10, color: color),
                          const SizedBox(width: 3),
                          Text(
                            categoryLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: barValue,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Time label
          Text(
            timeStr,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _StatPill({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
