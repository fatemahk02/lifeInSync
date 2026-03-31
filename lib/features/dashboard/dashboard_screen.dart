import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? user?.email ?? 'Friend';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Scaffold(
      backgroundColor: AppTheme.background,
      // FIX: No AppBar here — MainShell provides the AppBar
      // FIX: No avatar here — MainShell AppBar has the avatar
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Greeting header (no avatar — it's in AppBar now) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ).animate().fadeIn().slideX(begin: -0.1),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _WellbeingScoreCard()
                    .animate()
                    .fadeIn(delay: 100.ms)
                    .slideY(begin: 0.15),
                const SizedBox(height: 16),

                _QuickStatsRow()
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .slideY(begin: 0.15),
                const SizedBox(height: 16),

                _TodayFocusCard()
                    .animate()
                    .fadeIn(delay: 300.ms)
                    .slideY(begin: 0.15),
                const SizedBox(height: 16),

                _ScreenTimeSummaryCard()
                    .animate()
                    .fadeIn(delay: 400.ms)
                    .slideY(begin: 0.15),
                const SizedBox(height: 16),

                _HabitsSummaryCard()
                    .animate()
                    .fadeIn(delay: 500.ms)
                    .slideY(begin: 0.15),
                const SizedBox(height: 16),

                _FatigueBadgeCard()
                    .animate()
                    .fadeIn(delay: 600.ms)
                    .slideY(begin: 0.15),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wellbeing Score — FIXED: score visible, no overlap ────────
class _WellbeingScoreCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3DBE7A), Color(0xFF1E7A4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [AppTheme.primaryShadow],
      ),
      child: Row(
        children: [
          // FIX: Score on left, ring on right, no overlap
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wellbeing Score',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                // FIX: Large score text fully visible
                const Text(
                  '78',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '+6 from yesterday',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // FIX: Ring on right, properly sized, won't overlap left side
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: 0.78,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                const Text(
                  '78%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Stats ───────────────────────────────────────────────
class _QuickStatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.timer_rounded,
            iconColor: AppTheme.secondary,
            label: 'Focus',
            value: '2h 15m',
            sub: 'today',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_rounded,
            iconColor: AppTheme.primary,
            label: 'Habits',
            value: '4 / 6',
            sub: 'done',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.phone_android_rounded,
            iconColor: const Color(0xFFFF6B6B),
            label: 'Screen',
            value: '3h 40m',
            sub: 'today',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String sub;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          Text('$label $sub', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ── Focus Card ────────────────────────────────────────────────
class _TodayFocusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.secondary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('⏱️', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ready to focus?',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start a Pomodoro session',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Start',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Screen Time Summary ───────────────────────────────────────
class _ScreenTimeSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Screen Time',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const Spacer(),
              Text(
                '3h 40m today',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CategoryBar('Productive', 0.45, AppTheme.catProductive),
          const SizedBox(height: 10),
          _CategoryBar('Entertainment', 0.30, AppTheme.catEntertainment),
          const SizedBox(height: 10),
          _CategoryBar('Social', 0.25, AppTheme.catSocial),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _CategoryBar(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(value * 100).round()}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Habits Summary ────────────────────────────────────────────
class _HabitsSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final habits = [
      {'emoji': '💧', 'name': 'Drink Water', 'done': true},
      {'emoji': '🏃', 'name': 'Exercise', 'done': true},
      {'emoji': '📚', 'name': 'Read 20 min', 'done': false},
      {'emoji': '🧘', 'name': 'Meditate', 'done': true},
      {'emoji': '😴', 'name': 'Sleep by 11pm', 'done': false},
    ];

    final doneCount = habits.where((h) => h['done'] == true).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                "Today's Habits",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const Spacer(),
              Text(
                '$doneCount / ${habits.length}',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: habits
                .map(
                  (h) => _HabitChip(
                    emoji: h['emoji'] as String,
                    name: h['name'] as String,
                    done: h['done'] as bool,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _HabitChip extends StatelessWidget {
  final String emoji;
  final String name;
  final bool done;

  const _HabitChip({
    required this.emoji,
    required this.name,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done ? AppTheme.primary.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done
              ? AppTheme.primary.withOpacity(0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: done ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
          if (done) ...[
            const SizedBox(width: 4),
            Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 13),
          ],
        ],
      ),
    );
  }
}

// ── Fatigue Badge ─────────────────────────────────────────────
class _FatigueBadgeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8A65).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF8A65).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Text('😐', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Moderate Fatigue',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Heavy social/entertainment use detected',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8A65).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFFFF8A65),
            ),
          ),
        ],
      ),
    );
  }
}
