import 'package:flutter/material.dart';

enum AppCategory {
  productive, entertainment, social,
  education, health, gaming,
  news, shopping, finance, utility, other;

  String get label => switch (this) {
    AppCategory.productive    => 'Productive',
    AppCategory.entertainment => 'Entertainment',
    AppCategory.social        => 'Social',
    AppCategory.education     => 'Education',
    AppCategory.health        => 'Health & Fitness',
    AppCategory.gaming        => 'Gaming',
    AppCategory.news          => 'News',
    AppCategory.shopping      => 'Shopping',
    AppCategory.finance       => 'Finance',
    AppCategory.utility       => 'Utility',
    AppCategory.other         => 'Other',
  };

  Color get color => switch (this) {
    AppCategory.productive    => const Color(0xFF3DBE7A),
    AppCategory.entertainment => const Color(0xFFFF6B6B),
    AppCategory.social        => const Color(0xFF6C63FF),
    AppCategory.education     => const Color(0xFF29B6F6),
    AppCategory.health        => const Color(0xFFEC407A),
    AppCategory.gaming        => const Color(0xFFFFCA28),
    AppCategory.news          => const Color(0xFF78909C),
    AppCategory.shopping      => const Color(0xFFFF8A65),
    AppCategory.finance       => const Color(0xFF26A69A),
    AppCategory.utility       => const Color(0xFFAB47BC),
    AppCategory.other         => const Color(0xFFBDBDBD),
  };

  IconData get icon => switch (this) {
    AppCategory.productive    => Icons.work_outline_rounded,
    AppCategory.entertainment => Icons.play_circle_outline_rounded,
    AppCategory.social        => Icons.people_outline_rounded,
    AppCategory.education     => Icons.school_outlined,
    AppCategory.health        => Icons.favorite_outline_rounded,
    AppCategory.gaming        => Icons.sports_esports_outlined,
    AppCategory.news          => Icons.newspaper_outlined,
    AppCategory.shopping      => Icons.shopping_bag_outlined,
    AppCategory.finance       => Icons.account_balance_outlined,
    AppCategory.utility       => Icons.build_outlined,
    AppCategory.other         => Icons.apps_rounded,
  };

  bool get isHealthy =>
    this == AppCategory.productive ||
    this == AppCategory.education  ||
    this == AppCategory.health;
}

class CategoryRulesEngine {
  static const Map<String, AppCategory> _packageRules = {
    'com.instagram.android':            AppCategory.social,
    'com.facebook.katana':              AppCategory.social,
    'com.twitter.android':              AppCategory.social,
    'com.snapchat.android':             AppCategory.social,
    'com.whatsapp':                     AppCategory.social,
    'com.linkedin.android':             AppCategory.social,
    'com.pinterest':                    AppCategory.social,
    'com.reddit.frontpage':             AppCategory.social,
    'com.google.android.youtube':       AppCategory.entertainment,
    'com.netflix.mediaclient':          AppCategory.entertainment,
    'com.spotify.music':                AppCategory.entertainment,
    'com.amazon.avod.thirdpartyclient': AppCategory.entertainment,
    'com.hotstar':                      AppCategory.entertainment,
    'com.prime.video.android':          AppCategory.entertainment,
    'com.google.android.gm':            AppCategory.productive,
    'com.microsoft.teams':              AppCategory.productive,
    'com.notion.id':                    AppCategory.productive,
    'com.slack':                        AppCategory.productive,
    'com.microsoft.office.word':        AppCategory.productive,
    'com.microsoft.office.excel':       AppCategory.productive,
    'com.google.android.apps.docs':     AppCategory.productive,
    'com.google.android.apps.sheets':   AppCategory.productive,
    'org.khanacademy.android':          AppCategory.education,
    'com.duolingo':                     AppCategory.education,
    'com.udemy.android':                AppCategory.education,
    'com.coursera.app':                 AppCategory.education,
    'com.byju.learning':                AppCategory.education,
    'com.google.android.apps.fitness':  AppCategory.health,
    'com.strava.android':               AppCategory.health,
    'com.headspace.android':            AppCategory.health,
    'com.calm.android':                 AppCategory.health,
    'com.supercell.clashofclans':       AppCategory.gaming,
    'com.pubg.imobile':                 AppCategory.gaming,
    'com.google.android.apps.maps':     AppCategory.utility,
    'com.google.android.calculator':    AppCategory.utility,
    'com.android.camera2':              AppCategory.utility,
    'com.amazon.mShop.android.shopping':AppCategory.shopping,
    'com.flipkart.android':             AppCategory.shopping,
    'net.one97.paytm':                  AppCategory.finance,
    'com.google.android.apps.nbu.paisa.user': AppCategory.finance,
    'com.indiapay.merchant':            AppCategory.finance,
  };

  static const Map<String, AppCategory> _keywordRules = {
    'youtube':    AppCategory.entertainment,
    'netflix':    AppCategory.entertainment,
    'music':      AppCategory.entertainment,
    'video':      AppCategory.entertainment,
    'game':       AppCategory.gaming,
    'games':      AppCategory.gaming,
    'play':       AppCategory.gaming,
    'news':       AppCategory.news,
    'times':      AppCategory.news,
    'mail':       AppCategory.productive,
    'email':      AppCategory.productive,
    'docs':       AppCategory.productive,
    'sheets':     AppCategory.productive,
    'office':     AppCategory.productive,
    'work':       AppCategory.productive,
    'learn':      AppCategory.education,
    'study':      AppCategory.education,
    'course':     AppCategory.education,
    'school':     AppCategory.education,
    'fitness':    AppCategory.health,
    'workout':    AppCategory.health,
    'health':     AppCategory.health,
    'meditat':    AppCategory.health,
    'shop':       AppCategory.shopping,
    'store':      AppCategory.shopping,
    'bank':       AppCategory.finance,
    'pay':        AppCategory.finance,
    'wallet':     AppCategory.finance,
  };

  static AppCategory categorize(String packageName, String appName) {
    final pkg = packageName.toLowerCase();
    if (_packageRules.containsKey(pkg)) return _packageRules[pkg]!;
    final lower = appName.toLowerCase();
    for (final entry in _keywordRules.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return AppCategory.other;
  }
}