class AppConstants {
  // Screen time thresholds (minutes)
  static const int screenTimeWarning = 240; // 4 hours
  static const int screenTimeDanger = 360; // 6 hours

  // Focus session durations (minutes)
  static const int pomodoroDuration = 25;
  static const int deepWorkDuration = 50;
  static const int flowStateDuration = 90;
  static const int shortBreak = 5;
  static const int longBreak = 15;

  // Fatigue thresholds
  static const int fatigueMildThreshold = 25;
  static const int fatigueModerateThreshold = 50;
  static const int fatigueHighThreshold = 75;

  // App category names
  static const List<String> appCategories = [
    'Productive',
    'Entertainment',
    'Social',
    'Education',
    'Health',
    'Gaming',
    'News',
    'Shopping',
    'Finance',
    'Other',
  ];

  // Route names
  static const String routeLogin = '/login';
  static const String routeSignup = '/signup';
  static const String routeOtp = '/otp';
  static const String routeHome = '/home';
  static const String routeDashboard = '/dashboard';
  static const String routeScreenTime = '/screen-time';
  static const String routeCategories = '/categories';
  static const String routeFocus = '/focus';
  static const String routeFatigue = '/fatigue';
  static const String routeHabits = '/habits';
  static const String routeInsights = '/insights';

  // SharedPreferences keys
  static const String prefUserName = 'user_name';
  static const String prefOnboarded = 'onboarded';
  static const String prefDailyLimit = 'daily_screen_limit';
  static const String prefFocusGoal = 'daily_focus_goal';
}
