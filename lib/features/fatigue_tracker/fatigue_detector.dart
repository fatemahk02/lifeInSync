class FatigueDetector {
  /// Auto-detects fatigue score (0–100) from usage patterns.
  /// Higher score = more fatigued.
  static FatigueResult analyze({
    required int totalScreenMinutes,
    required int socialMinutes,
    required int entertainmentMinutes,
    required int gamingMinutes,
    required int lateNightMinutes,
    required int longestSessionMinutes,
    required int focusSessionsCompleted,
    required int habitsCompleted,
  }) {
    double score = 0;

    // 1. Total screen time (max 30 pts) — 8h = full score
    score += (totalScreenMinutes / 480 * 30).clamp(0, 30);

    // 2. Draining app categories (max 25 pts) — 3h = full score
    final draining = socialMinutes + entertainmentMinutes + gamingMinutes;
    score += (draining / 180 * 25).clamp(0, 25);

    // 3. Late night usage after 10pm (max 20 pts) — 1h = full score
    score += (lateNightMinutes / 60 * 20).clamp(0, 20);

    // 4. Longest unbroken session (max 15 pts) — 2h = full score
    score += (longestSessionMinutes / 120 * 15).clamp(0, 15);

    // 5. Healthy behavior deductions
    score -= (focusSessionsCompleted * 5).clamp(0, 15);
    score -= (habitsCompleted * 2).clamp(0, 10);

    final finalScore = score.clamp(0, 100).round();

    return FatigueResult(
      score: finalScore,
      level: _toLevel(finalScore),
      triggers: _buildTriggers(
        totalScreenMinutes: totalScreenMinutes,
        lateNightMinutes: lateNightMinutes,
        longestSessionMinutes: longestSessionMinutes,
        drainingMinutes: draining,
        focusSessionsCompleted: focusSessionsCompleted,
      ),
      recommendation: _recommend(finalScore),
      breakdown: FatigueBreakdown(
        screenTimeScore: (totalScreenMinutes / 480 * 30).clamp(0, 30).round(),
        drainingAppsScore: (draining / 180 * 25).clamp(0, 25).round(),
        lateNightScore: (lateNightMinutes / 60 * 20).clamp(0, 20).round(),
        longSessionScore: (longestSessionMinutes / 120 * 15).clamp(0, 15).round(),
        healthyDeduction: (focusSessionsCompleted * 5 + habitsCompleted * 2)
            .clamp(0, 25).round(),
      ),
    );
  }

  static FatigueLevel _toLevel(int score) {
    if (score < 25) return FatigueLevel.fresh;
    if (score < 50) return FatigueLevel.mild;
    if (score < 75) return FatigueLevel.moderate;
    return FatigueLevel.high;
  }

  static List<FatigueTrigger> _buildTriggers({
    required int totalScreenMinutes,
    required int lateNightMinutes,
    required int longestSessionMinutes,
    required int drainingMinutes,
    required int focusSessionsCompleted,
  }) {
    final triggers = <FatigueTrigger>[];

    if (totalScreenMinutes > 300)
      triggers.add(FatigueTrigger(
        icon: '📱',
        text: 'High screen time (${totalScreenMinutes ~/ 60}h ${totalScreenMinutes % 60}m today)',
        severity: totalScreenMinutes > 420 ? TriggerSeverity.high : TriggerSeverity.medium,
      ));

    if (lateNightMinutes > 30)
      triggers.add(FatigueTrigger(
        icon: '🌙',
        text: 'Late-night usage detected (${lateNightMinutes}m after 10pm)',
        severity: TriggerSeverity.high,
      ));

    if (longestSessionMinutes > 90)
      triggers.add(FatigueTrigger(
        icon: '⏳',
        text: 'Long unbroken session (${longestSessionMinutes}m without break)',
        severity: TriggerSeverity.medium,
      ));

    if (drainingMinutes > 120)
      triggers.add(FatigueTrigger(
        icon: '🎭',
        text: 'Heavy social/entertainment use (${drainingMinutes ~/ 60}h ${drainingMinutes % 60}m)',
        severity: TriggerSeverity.medium,
      ));

    if (focusSessionsCompleted == 0)
      triggers.add(FatigueTrigger(
        icon: '🧠',
        text: 'No focus sessions completed today',
        severity: TriggerSeverity.low,
      ));

    return triggers;
  }

  static String _recommend(int score) {
    if (score < 25) return 'You\'re in great shape! Your digital habits are healthy today.';
    if (score < 50) return 'Mild fatigue detected. Try a short walk or stretch break.';
    if (score < 75) return 'Moderate fatigue. Step away from screens for 30+ minutes.';
    return 'High digital fatigue. Rest your eyes, go outside, and avoid screens for a while.';
  }
}

// ── Models ────────────────────────────────────────────────────
enum FatigueLevel {
  fresh, mild, moderate, high;

  String get label => switch (this) {
    FatigueLevel.fresh    => 'Fresh',
    FatigueLevel.mild     => 'Mildly Tired',
    FatigueLevel.moderate => 'Moderately Fatigued',
    FatigueLevel.high     => 'High Fatigue',
  };

  String get emoji => switch (this) {
    FatigueLevel.fresh    => '⚡',
    FatigueLevel.mild     => '🙂',
    FatigueLevel.moderate => '😐',
    FatigueLevel.high     => '😩',
  };

  // Color returned as int to avoid Flutter import in pure logic file
  int get colorValue => switch (this) {
    FatigueLevel.fresh    => 0xFF3DBE7A,
    FatigueLevel.mild     => 0xFFFFD54F,
    FatigueLevel.moderate => 0xFFFF8A65,
    FatigueLevel.high     => 0xFFE05C5C,
  };
}

enum TriggerSeverity { low, medium, high }

class FatigueTrigger {
  final String icon;
  final String text;
  final TriggerSeverity severity;
  const FatigueTrigger({
    required this.icon, required this.text, required this.severity});
}

class FatigueBreakdown {
  final int screenTimeScore;
  final int drainingAppsScore;
  final int lateNightScore;
  final int longSessionScore;
  final int healthyDeduction;
  const FatigueBreakdown({
    required this.screenTimeScore,
    required this.drainingAppsScore,
    required this.lateNightScore,
    required this.longSessionScore,
    required this.healthyDeduction,
  });
}

class FatigueResult {
  final int score;
  final FatigueLevel level;
  final List<FatigueTrigger> triggers;
  final String recommendation;
  final FatigueBreakdown breakdown;
  const FatigueResult({
    required this.score, required this.level,
    required this.triggers, required this.recommendation,
    required this.breakdown,
  });
}