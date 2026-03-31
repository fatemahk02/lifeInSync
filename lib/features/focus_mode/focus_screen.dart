import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';

enum SessionType { pomodoro, deepWork, flowState }

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with TickerProviderStateMixin {
  // ── Session config ─────────────────────────────────────────
  static const Map<SessionType, int> _durations = {
    SessionType.pomodoro: 25 * 60,
    SessionType.deepWork: 50 * 60,
    SessionType.flowState: 90 * 60,
  };
  static const Map<SessionType, String> _labels = {
    SessionType.pomodoro: 'Pomodoro',
    SessionType.deepWork: 'Deep Work',
    SessionType.flowState: 'Flow State',
  };
  static const Map<SessionType, String> _emojis = {
    SessionType.pomodoro: '🍅',
    SessionType.deepWork: '🧠',
    SessionType.flowState: '🌊',
  };
  static const int _shortBreak = 5 * 60;
  static const int _longBreak = 15 * 60;

  // ── State ──────────────────────────────────────────────────
  SessionType _sessionType = SessionType.pomodoro;
  int _secondsLeft = 25 * 60;
  bool _isRunning = false;
  bool _isBreak = false;
  int _pomodorosToday = 0;
  int _focusStreak = 4; // days streak
  Timer? _timer;

  late AnimationController _pulseController;
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  // ── Timer logic ────────────────────────────────────────────
  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _onTimerComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isBreak = false;
      _secondsLeft = _durations[_sessionType]!;
    });
  }

  void _onTimerComplete() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      if (!_isBreak) {
        _pomodorosToday++;
        _isBreak = true;
        _secondsLeft = _pomodorosToday % 4 == 0 ? _longBreak : _shortBreak;
      } else {
        _isBreak = false;
        _secondsLeft = _durations[_sessionType]!;
      }
    });
    _showCompletionSnackbar();
  }

  void _selectSession(SessionType type) {
    _timer?.cancel();
    setState(() {
      _sessionType = type;
      _isRunning = false;
      _isBreak = false;
      _secondsLeft = _durations[type]!;
    });
  }

  void _showCompletionSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBreak
              ? '🎉 Session complete! Take a break.'
              : '⚡ Break over. Ready to focus?',
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────
  String get _formattedTime {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progress {
    final total = _isBreak
        ? (_pomodorosToday % 4 == 0 ? _longBreak : _shortBreak).toDouble()
        : _durations[_sessionType]!.toDouble();
    return 1 - (_secondsLeft / total);
  }

  Color get _accentColor =>
      _isBreak ? const Color(0xFF29B6F6) : AppTheme.primary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Focus Mode',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      Text(
                        _isBreak ? 'Take a breather 😌' : 'Stay in the zone 🎯',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  // Streak badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A65).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(
                          '$_focusStreak day streak',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF8A65),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(),
              const SizedBox(height: 32),

              // Session type selector
              _buildSessionSelector().animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 40),

              // Timer ring
              _buildTimerRing()
                  .animate()
                  .fadeIn(delay: 200.ms)
                  .scale(begin: const Offset(0.9, 0.9)),
              const SizedBox(height: 40),

              // Controls
              _buildControls().animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 32),

              // Stats row
              _buildStatsRow().animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 32),

              // Tips card
              _buildTipCard().animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Row(
        children: SessionType.values.map((type) {
          final isSelected = _sessionType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () => _selectSession(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: isSelected ? [AppTheme.primaryShadow] : null,
                ),
                child: Column(
                  children: [
                    Text(_emojis[type]!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(
                      _labels[type]!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimerRing() {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 14,
              valueColor: AlwaysStoppedAnimation(_accentColor.withOpacity(0.1)),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Progress ring
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: _progress,
              strokeWidth: 14,
              valueColor: AlwaysStoppedAnimation(_accentColor),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Pulse when running
          if (_isRunning)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Container(
                width: 200 + (_pulseController.value * 10),
                height: 200 + (_pulseController.value * 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentColor.withOpacity(
                    0.04 * (1 - _pulseController.value),
                  ),
                ),
              ),
            ),
          // Inner content
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              boxShadow: [AppTheme.cardShadowLight],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isBreak) const Text('☕', style: TextStyle(fontSize: 28)),
                Text(
                      _emojis[_sessionType]!,
                      style: const TextStyle(fontSize: 24),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      duration: 3.seconds,
                      color: AppTheme.primary.withOpacity(0.3),
                    ),
                const SizedBox(height: 8),
                Text(
                  _formattedTime,
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    color: _accentColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isBreak ? 'Break time' : _labels[_sessionType]!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Reset
        _ControlButton(
          icon: Icons.replay_rounded,
          size: 52,
          color: AppTheme.textSecondary,
          bgColor: Colors.grey.shade100,
          onTap: _resetTimer,
        ),
        const SizedBox(width: 20),
        // Play / Pause
        _ControlButton(
          icon: _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 72,
          color: Colors.white,
          bgColor: _accentColor,
          onTap: _isRunning ? _pauseTimer : _startTimer,
          hasShadow: true,
          shadowColor: _accentColor,
        ),
        const SizedBox(width: 20),
        // Skip
        _ControlButton(
          icon: Icons.skip_next_rounded,
          size: 52,
          color: AppTheme.textSecondary,
          bgColor: Colors.grey.shade100,
          onTap: _onTimerComplete,
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _FocusStatCard(
            emoji: '🍅',
            value: '$_pomodorosToday',
            label: 'Sessions today',
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FocusStatCard(
            emoji: '⏳',
            value: '${(_pomodorosToday * 25)}m',
            label: 'Focused today',
            color: AppTheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FocusStatCard(
            emoji: '🔥',
            value: '$_focusStreak',
            label: 'Day streak',
            color: const Color(0xFFFF8A65),
          ),
        ),
      ],
    );
  }

  Widget _buildTipCard() {
    final tips = [
      '💡 Put your phone face-down during sessions',
      '🎧 Try lo-fi music to help concentration',
      '💧 Keep water nearby to stay hydrated',
      '🌿 A plant on your desk reduces stress',
      '📵 Enable Do Not Disturb before starting',
    ];
    final tip = tips[_pomodorosToday % tips.length];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.secondary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  final bool hasShadow;
  final Color? shadowColor;

  const _ControlButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.bgColor,
    required this.onTap,
    this.hasShadow = false,
    this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: hasShadow
              ? [
                  BoxShadow(
                    color: (shadowColor ?? bgColor).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }
}

class _FocusStatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;

  const _FocusStatCard({
    required this.emoji,
    required this.value,
    required this.label,
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
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
