import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../screen_time/screen_time_screen.dart';
import '../insights/insights_screen.dart';
import '../profile/profile_screen.dart';
import '../focus_mode/focus_screen.dart';
import '../fatigue_tracker/fatigue_screen.dart';
import '../fatigue_tracker/fatigue_detector.dart';
import '../habits/habits_screen.dart';
import '../app_categorizer/categorizer_screen.dart';
import '../settings/settings_screen.dart';
import '../../shared/services/app_preferences_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/notification_service.dart';
import '../../shared/services/screen_time_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Widget? _activeDrawerScreen;
  String? _activeDrawerSectionKey;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _firestore = FirestoreService.instance;

  List<Widget> get _screens => [
    DashboardScreen(onStartFocus: () => setState(() => _currentIndex = 1)),
    const ScreenTimeScreen(),
    const ProfileScreen(),
    const InsightsScreen(),
  ];

  List<_NavItem> _buildNavItems(AppLocalizations t) {
    return [
      _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: t.tr('home'),
      ),
      _NavItem(
        icon: Icons.phone_android_outlined,
        activeIcon: Icons.phone_android_rounded,
        label: t.tr('usage'),
      ),
      _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: t.tr('profile'),
      ),
      _NavItem(
        icon: Icons.insights_outlined,
        activeIcon: Icons.insights_rounded,
        label: t.tr('insights'),
      ),
    ];
  }

  List<String> _buildScreenTitles(AppLocalizations t) {
    return [
      t.tr('home'),
      t.tr('usage'),
      t.tr('profile'),
      t.tr('insights'),
    ];
  }

  String _drawerSectionTitle(AppLocalizations t) {
    switch (_activeDrawerSectionKey) {
      case 'focusMode':
        return t.tr('focusMode');
      case 'fatigueTracker':
        return t.tr('fatigueTracker');
      case 'habits':
        return t.tr('habits');
      case 'appCategorizer':
        return t.tr('appCategorizer');
      case 'settings':
        return t.tr('settings');
      default:
        return '';
    }
  }

  void _openDrawerSection({required Widget screen, required String sectionKey}) {
    setState(() {
      _activeDrawerScreen = screen;
      _activeDrawerSectionKey = sectionKey;
    });
    Navigator.pop(context);
  }

  void _openBottomTab(int index) {
    setState(() {
      _currentIndex = index;
      _activeDrawerScreen = null;
      _activeDrawerSectionKey = null;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenTimeService.instance.requestPermissionOnFirstLaunch();
      _runDailyNotificationChecks();
      _syncAnalyticsSnapshots();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runDailyNotificationChecks();
      _syncAnalyticsSnapshots();
    }
  }

  void _runDailyNotificationChecks() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    unawaited(NotificationService.instance.maybeNotifyFocusNudge(uid: uid));
  }

  Future<void> _syncAnalyticsSnapshots() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      int screenMinutes = 0;
      FatigueUsageInputs? usageInputs;
      final hasPermission = await ScreenTimeService.instance.hasUsagePermission();
      if (hasPermission) {
        try {
          usageInputs = await ScreenTimeService.instance
              .getFatigueUsageInputsForToday()
              .timeout(const Duration(seconds: 8));
          screenMinutes = usageInputs.totalScreenMinutes;
        } catch (_) {}
      }

      final limitHours = await AppPreferencesService.instance.getDailyLimitHours(uid);
      final screenLimitMinutes = (limitHours * 60).round();

      final totalHabits = await _firestore.getTotalHabits(uid);
      final habitsDone = await _firestore.getCompletedHabitsToday(uid);
      final focusSessionsCompleted = await _firestore.getCompletedFocusSessionsToday(uid);

      final focusMinutes = await _firestore.getCompletedFocusMinutesInRange(
        uid: uid,
        start: dayStart,
        end: dayEnd,
      );

      var focusGoalMinutes = 60;
      try {
        final profile = await _firestore.getUserProfile(uid);
        final prefs = (profile?['preferences'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        focusGoalMinutes = (prefs['focusGoalMinutes'] as num?)?.toInt() ?? 60;
      } catch (_) {}

      var fatigueScore = await _firestore.getFatigueScoreForDate(uid, now);
      if (usageInputs != null) {
        final fatigue = FatigueDetector.analyze(
          totalScreenMinutes: usageInputs.totalScreenMinutes,
          socialMinutes: usageInputs.socialMinutes,
          entertainmentMinutes: usageInputs.entertainmentMinutes,
          gamingMinutes: usageInputs.gamingMinutes,
          lateNightMinutes: usageInputs.lateNightMinutes,
          longestSessionMinutes: usageInputs.longestSessionMinutes,
          focusSessionsCompleted: focusSessionsCompleted,
          habitsCompleted: habitsDone,
        );

        if (kDebugMode) {
          debugPrint(
            'FATIGUE_SYNC total=${usageInputs.totalScreenMinutes} '
            'social=${usageInputs.socialMinutes} entertainment=${usageInputs.entertainmentMinutes} '
            'gaming=${usageInputs.gamingMinutes} lateNight=${usageInputs.lateNightMinutes} '
            'longest=${usageInputs.longestSessionMinutes} focus=$focusSessionsCompleted '
            'habits=$habitsDone score=${fatigue.score}',
          );
        }

        fatigueScore = fatigue.score;
        await _firestore.saveFatigueScore(
          uid: uid,
          date: now,
          score: fatigue.score,
          level: fatigue.level.name,
          breakdown: {
            'screenTimeScore': fatigue.breakdown.screenTimeScore,
            'drainingAppsScore': fatigue.breakdown.drainingAppsScore,
            'lateNightScore': fatigue.breakdown.lateNightScore,
            'longSessionScore': fatigue.breakdown.longSessionScore,
            'healthyDeduction': fatigue.breakdown.healthyDeduction,
          },
          triggers: fatigue.triggers
              .map(
                (t) => {
                  'icon': t.icon,
                  'text': t.text,
                  'severity': t.severity.name,
                },
              )
              .toList(growable: false),
          recommendation: fatigue.recommendation,
        );
      }

      final wellbeingScore = (100 - fatigueScore).clamp(0, 100);
      final focusScore = focusGoalMinutes <= 0
          ? 0
          : ((focusMinutes / focusGoalMinutes) * 100).clamp(0, 100).round();

      final weekStart = dayStart.subtract(const Duration(days: 6));
      final monthStart = dayStart.subtract(const Duration(days: 29));

      final habitsDoneWeek = await _firestore.getCompletedHabitsInRange(
        uid: uid,
        start: weekStart,
        end: dayEnd,
      );
      final habitsDoneMonth = await _firestore.getCompletedHabitsInRange(
        uid: uid,
        start: monthStart,
        end: dayEnd,
      );

      final totalHabitDaysDaily = (totalHabits * 1).toDouble();
      final totalHabitDaysWeek = (totalHabits * 7).toDouble();
      final totalHabitDaysMonth = (totalHabits * 30).toDouble();

      final dailyConsistency = totalHabitDaysDaily == 0
          ? 0.0
          : (habitsDone / totalHabitDaysDaily) * 100;
      final weeklyConsistency = totalHabitDaysWeek == 0
          ? 0.0
          : (habitsDoneWeek / totalHabitDaysWeek) * 100;
      final monthlyConsistency = totalHabitDaysMonth == 0
          ? 0.0
          : (habitsDoneMonth / totalHabitDaysMonth) * 100;

      await _firestore.saveAnalyticsSnapshots(
        uid: uid,
        input: AnalyticsSnapshotInput(
          date: now,
          wellbeingScore: wellbeingScore,
          focusScore: focusScore,
          fatigueScore: fatigueScore,
          totalScreenTimeMinutes: screenMinutes,
          screenTimeLimitMinutes: screenLimitMinutes,
          habitsDone: habitsDone,
          totalHabits: totalHabits,
          focusMinutes: focusMinutes,
          focusGoalMinutes: focusGoalMinutes,
          habitConsistencyDaily: dailyConsistency,
          habitConsistencyWeekly: weeklyConsistency,
          habitConsistencyMonthly: monthlyConsistency,
        ),
      );
    } catch (_) {
      // Keep shell responsive when analytics sync fails transiently.
    }
  }

  // ── FIXED _logout — clean, no duplicates ──────────────────
  Future<void> _logout() async {
    final t = context.l10n;

    // Close drawer first
    Navigator.pop(context);

    // Small delay so drawer finishes closing before dialog opens
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppTheme.error, size: 22),
            const SizedBox(width: 10),
            Text(
              t.tr('signOutConfirmTitle'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          t.tr('signOutConfirmMessage'),
          style: const TextStyle(fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        // FIX: buttons in a Row — side by side, not stacked
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    t.tr('cancel'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    t.tr('signOut'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.tr('logoutFailed')}: ${e.toString()}'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final navItems = _buildNavItems(t);
    final screenTitles = _buildScreenTitles(t);
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? user?.email ?? 'User';
    final email = user?.email ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      key: _scaffoldKey,

      // ── AppBar ─────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.menu_rounded,
            color: AppTheme.textPrimary,
            size: 26,
          ),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: t.tr('menu'),
        ),
        title: Text(
          _activeDrawerScreen != null
              ? _drawerSectionTitle(t)
              : screenTitles[_currentIndex],
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3DBE7A), Color(0xFF2A8F58)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // ── Drawer ─────────────────────────────────────────────
      drawer: Drawer(
        backgroundColor: AppTheme.surface,
        child: SafeArea(
          child: Column(
            children: [
              // Profile header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3DBE7A), Color(0xFF2A8F58)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Nav items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  children: [
                    _DrawerNavTile(
                      icon: navItems[0].icon,
                      activeIcon: navItems[0].activeIcon,
                      label: navItems[0].label,
                      isSelected: _activeDrawerScreen == null && _currentIndex == 0,
                      onTap: () {
                        _openBottomTab(0);
                        Navigator.pop(context);
                      },
                    ),
                    _DrawerNavTile(
                      icon: navItems[1].icon,
                      activeIcon: navItems[1].activeIcon,
                      label: navItems[1].label,
                      isSelected: _activeDrawerScreen == null && _currentIndex == 1,
                      onTap: () {
                        _openBottomTab(1);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 8),
                    _DrawerNavTile(
                      icon: Icons.center_focus_strong_outlined,
                      activeIcon: Icons.center_focus_strong,
                      label: t.tr('focusMode'),
                      isSelected: _activeDrawerSectionKey == 'focusMode',
                      onTap: () => _openDrawerSection(
                        screen: const FocusScreen(),
                        sectionKey: 'focusMode',
                      ),
                    ),
                    _DrawerNavTile(
                      icon: Icons.battery_alert_outlined,
                      activeIcon: Icons.battery_alert_rounded,
                      label: t.tr('fatigueTracker'),
                      isSelected: _activeDrawerSectionKey == 'fatigueTracker',
                      onTap: () => _openDrawerSection(
                        screen: const FatigueScreen(),
                        sectionKey: 'fatigueTracker',
                      ),
                    ),
                    _DrawerNavTile(
                      icon: Icons.check_circle_outline_rounded,
                      activeIcon: Icons.check_circle_rounded,
                      label: t.tr('habits'),
                      isSelected: _activeDrawerSectionKey == 'habits',
                      onTap: () => _openDrawerSection(
                        screen: const HabitsScreen(),
                        sectionKey: 'habits',
                      ),
                    ),
                    _DrawerNavTile(
                      icon: navItems[2].icon,
                      activeIcon: navItems[2].activeIcon,
                      label: navItems[2].label,
                      isSelected: _activeDrawerScreen == null && _currentIndex == 2,
                      onTap: () {
                        _openBottomTab(2);
                        Navigator.pop(context);
                      },
                    ),
                    _DrawerNavTile(
                      icon: navItems[3].icon,
                      activeIcon: navItems[3].activeIcon,
                      label: navItems[3].label,
                      isSelected: _activeDrawerScreen == null && _currentIndex == 3,
                      onTap: () {
                        _openBottomTab(3);
                        Navigator.pop(context);
                      },
                    ),
                    _DrawerNavTile(
                      icon: Icons.apps_outlined,
                      activeIcon: Icons.apps_rounded,
                      label: t.tr('appCategorizer'),
                      isSelected: _activeDrawerSectionKey == 'appCategorizer',
                      onTap: () => _openDrawerSection(
                        screen: const CategorizerScreen(),
                        sectionKey: 'appCategorizer',
                      ),
                    ),
                    _DrawerNavTile(
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings_rounded,
                      label: t.tr('settings'),
                      isSelected: _activeDrawerSectionKey == 'settings',
                      onTap: () => _openDrawerSection(
                        screen: const SettingsScreen(),
                        sectionKey: 'settings',
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),
              const SizedBox(height: 4),

              // Sign Out tile
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: AppTheme.error,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    t.tr('signOut'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.error,
                      fontSize: 15,
                    ),
                  ),
                  onTap: _logout,
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Body ───────────────────────────────────────────────
      body: _activeDrawerScreen ?? IndexedStack(index: _currentIndex, children: _screens),

      // ── Bottom Nav ─────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _openBottomTab,
          backgroundColor: AppTheme.surface,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: navItems
              .map(
                (item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon),
                  label: item.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ── Supporting types ──────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _DrawerNavTile extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerNavTile({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: isSelected
            ? AppTheme.primary.withOpacity(0.08)
            : Colors.transparent,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withOpacity(0.12)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            size: 20,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
            fontSize: 15,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
