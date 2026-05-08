import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/app_preferences_service.dart';
import '../../shared/services/fastapi_service.dart';
import '../../shared/services/firestore_service.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();

  int _page = 0;
  bool _saving = false;
  int _dailyLimit = 6;
  int _focusGoal = 60;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      return;
    }

    setState(() => _saving = true);
    String timezone = 'UTC';

    try {
      try {
        timezone = await FlutterTimezone.getLocalTimezone();
      } catch (_) {}

      // Always complete onboarding locally first so UX does not hang.
      await AppPreferencesService.instance.setDailyLimitHours(
        uid,
        _dailyLimit.toDouble(),
      );
      await AppPreferencesService.instance.setOnboardingComplete(uid, true);

      try {
        await FastApiService.instance
            .upsertUserProfile(
              uid: uid,
              timezone: timezone,
              dailyScreenLimitMinutes: _dailyLimit * 60,
              focusGoalMinutes: _focusGoal,
              onboardingCompleted: true,
            )
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        await FirestoreService.instance
            .updateUserProfile(
              uid: uid,
              timezone: timezone,
            )
            .timeout(const Duration(seconds: 5));

        await FirestoreService.instance
            .updateUserPreferences(
              uid: uid,
              dailyScreenLimitMinutes: _dailyLimit * 60,
              focusGoalMinutes: _focusGoal,
              onboardingCompleted: true,
            )
            .timeout(const Duration(seconds: 5));
      }

      await FirebaseAuth.instance.signOut();
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  void _next() {
    if (_page < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (value) => setState(() => _page = value),
                  children: [
                    _LimitPage(
                      dailyLimit: _dailyLimit,
                      onLimitChanged: (v) => setState(() => _dailyLimit = v),
                    ),
                    _GoalsPage(
                      focusGoal: _focusGoal,
                      onGoalChanged: (v) => setState(() => _focusGoal = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  2,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _page == i ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _page == i ? AppTheme.primary : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _next,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _page == 1
                              ? context.l10n.tr('confirm')
                              : context.l10n.tr('continue'),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalsPage extends StatelessWidget {
  final int focusGoal;
  final ValueChanged<int> onGoalChanged;

  const _GoalsPage({required this.focusGoal, required this.onGoalChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(t.tr('setDailyFocusGoal'), style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(t.tr('chooseFocusMinutes'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
        Text('$focusGoal ${t.tr('minutes')}', style: Theme.of(context).textTheme.headlineMedium),
        Slider(
          value: focusGoal.toDouble(),
          min: 15,
          max: 180,
          divisions: 11,
          onChanged: (v) => onGoalChanged(v.round()),
        ),
      ],
    );
  }
}

class _LimitPage extends StatelessWidget {
  final int dailyLimit;
  final ValueChanged<int> onLimitChanged;

  const _LimitPage({required this.dailyLimit, required this.onLimitChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(t.tr('setDailyScreenLimit'), style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(t.tr('warnCloseLimit'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
        Text('$dailyLimit ${t.tr('hours')}', style: Theme.of(context).textTheme.headlineMedium),
        Slider(
          value: dailyLimit.toDouble(),
          min: 1,
          max: 12,
          divisions: 11,
          onChanged: (v) => onLimitChanged(v.round()),
        ),
      ],
    );
  }
}
