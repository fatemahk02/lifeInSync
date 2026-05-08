import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/app_preferences_service.dart';
import '../../shared/services/firestore_service.dart';

enum SessionType { pomodoro, deepWork, flowState }

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with TickerProviderStateMixin {
  // ── Session config ─────────────────────────────────────────
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
  static const int _shortBreak = AppConstants.shortBreak * 60;
  static const int _longBreak = AppConstants.longBreak * 60;

  // ── State ──────────────────────────────────────────────────
  SessionType _sessionType = SessionType.pomodoro;
  int _secondsLeft = 25 * 60;
  bool _isRunning = false;
  bool _isBreak = false;
  bool _loadingDurations = true;
  int _pomodorosToday = 0;
  int _focusStreak = 4; // days streak
  Timer? _timer;
  final _firestore = FirestoreService.instance;
  final _prefs = AppPreferencesService.instance;
  late Map<SessionType, int> _durations;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

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

    _durations = {
      SessionType.pomodoro: AppConstants.pomodoroDuration * 60,
      SessionType.deepWork: AppConstants.deepWorkDuration * 60,
      SessionType.flowState: AppConstants.flowStateDuration * 60,
    };
    _secondsLeft = _durations[_sessionType]!;
    unawaited(_loadSavedDurations());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedDurations() async {
    final uid = _uid;
    if (uid != null) {
      final pomodoro = await _prefs.getPomodoroMinutes(
        uid,
        fallback: AppConstants.pomodoroDuration,
      );
      final deepWork = await _prefs.getDeepWorkMinutes(
        uid,
        fallback: AppConstants.deepWorkDuration,
      );
      final flowState = await _prefs.getFlowStateMinutes(
        uid,
        fallback: AppConstants.flowStateDuration,
      );

      if (!mounted) return;
      setState(() {
        _durations[SessionType.pomodoro] = pomodoro * 60;
        _durations[SessionType.deepWork] = deepWork * 60;
        _durations[SessionType.flowState] = flowState * 60;
        _secondsLeft = _durations[_sessionType]!;
        _loadingDurations = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _loadingDurations = false);
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
    final completedFocusSession = !_isBreak;
    if (completedFocusSession) {
      unawaited(_saveCompletedFocusSession());
    }
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

  Future<void> _saveCompletedFocusSession() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _firestore.saveFocusSession(
        uid: uid,
        sessionType: _labels[_sessionType]!,
        plannedSeconds: _durations[_sessionType]!,
        completed: true,
        completedAt: DateTime.now(),
      );
    } catch (_) {
      // Keep timer flow smooth even if persistence fails.
    }
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

  Future<void> _updateSessionDuration(SessionType type, int minutes) async {
    final seconds = minutes * 60;
    final uid = _uid;

    setState(() {
      _durations[type] = seconds;
      if (!_isRunning && !_isBreak && _sessionType == type) {
        _secondsLeft = seconds;
      }
    });

    if (uid == null) return;
    if (type == SessionType.pomodoro) {
      await _prefs.setPomodoroMinutes(uid, minutes);
    } else if (type == SessionType.deepWork) {
      await _prefs.setDeepWorkMinutes(uid, minutes);
    } else {
      await _prefs.setFlowStateMinutes(uid, minutes);
    }
  }

  Future<void> _resetDurationsToDefaults() async {
    final defaults = <SessionType, int>{
      SessionType.pomodoro: AppConstants.pomodoroDuration * 60,
      SessionType.deepWork: AppConstants.deepWorkDuration * 60,
      SessionType.flowState: AppConstants.flowStateDuration * 60,
    };

    final uid = _uid;
    setState(() {
      _durations = defaults;
      if (!_isRunning && !_isBreak) {
        _secondsLeft = _durations[_sessionType]!;
      }
    });

    if (uid != null) {
      await _prefs.setPomodoroMinutes(uid, AppConstants.pomodoroDuration);
      await _prefs.setDeepWorkMinutes(uid, AppConstants.deepWorkDuration);
      await _prefs.setFlowStateMinutes(uid, AppConstants.flowStateDuration);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.tr('durationsReset')),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showCompletionSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBreak
              ? '🎉 ${context.l10n.tr('sessionCompleteTakeBreak')}'
              : '⚡ ${context.l10n.tr('breakOverReadyFocus')}',
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

  String _sessionLabel(SessionType type) {
    final t = context.l10n;
    switch (type) {
      case SessionType.pomodoro:
        return t.tr('pomodoro');
      case SessionType.deepWork:
        return t.tr('deepWork');
      case SessionType.flowState:
        return t.tr('flowState');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
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
                        t.tr('focusMode'),
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      Text(
                        _isBreak
                            ? '${t.tr('focusModeSubtitleBreak')} 😌'
                            : '${t.tr('focusModeSubtitleFocus')} 🎯',
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
                          '$_focusStreak ${t.tr('dayStreak')}',
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
              const SizedBox(height: 16),
              _buildDurationCustomizer().animate().fadeIn(delay: 140.ms),
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
                      _sessionLabel(type),
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

  Widget _buildDurationCustomizer() {
    if (_loadingDurations) {
      return const SizedBox(
        height: 52,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

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
            context.l10n.tr('sessionDurations'),
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.tr('adjustTimesRoutine'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _durationSlider(SessionType.pomodoro, 10, 60),
          _durationSlider(SessionType.deepWork, 20, 120),
          _durationSlider(SessionType.flowState, 30, 180),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _resetDurationsToDefaults,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.l10n.tr('resetDefaults')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _durationSlider(SessionType type, int min, int max) {
    final currentMinutes = (_durations[type]! / 60).round();
    return Column(
      children: [
        Row(
          children: [
            Text('${_emojis[type]} ${_sessionLabel(type)}'),
            const Spacer(),
            Text(
              '$currentMinutes ${context.l10n.tr('minutesShort')}',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          value: currentMinutes.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: (v) => _updateSessionDuration(type, v.round()),
        ),
      ],
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
                  _isBreak ? context.l10n.tr('breakTime') : _sessionLabel(_sessionType),
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
            label: context.l10n.tr('sessionsToday'),
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FocusStatCard(
            emoji: '⏳',
            value: '${(_pomodorosToday * 25)}m',
            label: context.l10n.tr('focusedToday'),
            color: AppTheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FocusStatCard(
            emoji: '🔥',
            value: '$_focusStreak',
            label: context.l10n.tr('dayStreak'),
            color: const Color(0xFFFF8A65),
          ),
        ),
      ],
    );
  }

  Widget _buildTipCard() {
    final tips = [
      '💡 ${context.l10n.tr('focusTip1')}',
      '🎧 ${context.l10n.tr('focusTip2')}',
      '💧 ${context.l10n.tr('focusTip3')}',
      '🌿 ${context.l10n.tr('focusTip4')}',
      '📵 ${context.l10n.tr('focusTip5')}',
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
