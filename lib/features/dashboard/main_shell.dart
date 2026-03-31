import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../screen_time/screen_time_screen.dart';
import '../app_categorizer/categorizer_screen.dart';
import '../focus_mode/focus_screen.dart';
import '../fatigue_tracker/fatigue_screen.dart';
import '../habits/habits_screen.dart';
import '../insights/insights_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = const [
    DashboardScreen(),
    ScreenTimeScreen(),
    CategorizerScreen(),
    FocusScreen(),
    FatigueScreen(),
    HabitsScreen(),
    InsightsScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.phone_android_outlined,
      activeIcon: Icons.phone_android_rounded,
      label: 'Screen',
    ),
    _NavItem(
      icon: Icons.category_outlined,
      activeIcon: Icons.category_rounded,
      label: 'Apps',
    ),
    _NavItem(
      icon: Icons.timer_outlined,
      activeIcon: Icons.timer_rounded,
      label: 'Focus',
    ),
    _NavItem(
      icon: Icons.battery_alert_outlined,
      activeIcon: Icons.battery_alert_rounded,
      label: 'Fatigue',
    ),
    _NavItem(
      icon: Icons.check_circle_outline,
      activeIcon: Icons.check_circle_rounded,
      label: 'Habits',
    ),
    _NavItem(
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
      label: 'Insights',
    ),
  ];

  final List<String> _screenTitles = const [
    'Home',
    'Screen Time',
    'App Categories',
    'Focus Mode',
    'Fatigue',
    'Habits',
    'Insights',
  ];

  // ── FIXED _logout — clean, no duplicates ──────────────────
  Future<void> _logout() async {
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
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.error, size: 22),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(fontSize: 15),
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
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
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.w700),
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
            content: Text('Logout failed: ${e.toString()}'),
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
          tooltip: 'Menu',
        ),
        title: Text(
          _screenTitles[_currentIndex],
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
                  children: _navItems
                      .asMap()
                      .entries
                      .map(
                        (e) => _DrawerNavTile(
                          icon: e.value.icon,
                          activeIcon: e.value.activeIcon,
                          label: e.value.label,
                          isSelected: _currentIndex == e.key,
                          onTap: () {
                            setState(() => _currentIndex = e.key);
                            Navigator.pop(context);
                          },
                        ),
                      )
                      .toList(),
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
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(
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
      body: IndexedStack(index: _currentIndex, children: _screens),

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
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          backgroundColor: AppTheme.surface,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: _navItems
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
