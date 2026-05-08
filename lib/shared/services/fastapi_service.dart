import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import 'firestore_service.dart';

class DailyBehaviorMetrics {
  final int focusSessionsCompleted;
  final int habitsCompleted;
  final bool hasFocusSessionToday;

  const DailyBehaviorMetrics({
    required this.focusSessionsCompleted,
    required this.habitsCompleted,
    required this.hasFocusSessionToday,
  });

  factory DailyBehaviorMetrics.fromJson(Map<String, dynamic> json) {
    return DailyBehaviorMetrics(
      focusSessionsCompleted: (json['focus_sessions_completed'] as num?)?.toInt() ?? 0,
      habitsCompleted: (json['habits_completed'] as num?)?.toInt() ?? 0,
      hasFocusSessionToday: (json['has_focus_session_today'] as bool?) ?? false,
    );
  }
}

class UserProfilePreferences {
  final int dailyScreenLimitMinutes;
  final bool notificationsEnabled;
  final int focusGoalMinutes;
  final bool onboardingCompleted;
  final String theme;

  const UserProfilePreferences({
    required this.dailyScreenLimitMinutes,
    required this.notificationsEnabled,
    required this.focusGoalMinutes,
    required this.onboardingCompleted,
    required this.theme,
  });

  factory UserProfilePreferences.fromJson(Map<String, dynamic> json) {
    return UserProfilePreferences(
      dailyScreenLimitMinutes:
          (json['daily_screen_limit_minutes'] as num?)?.toInt() ?? 180,
      notificationsEnabled: (json['notifications_enabled'] as bool?) ?? true,
      focusGoalMinutes: (json['focus_goal_minutes'] as num?)?.toInt() ?? 60,
      onboardingCompleted: (json['onboarding_completed'] as bool?) ?? false,
      theme: (json['theme'] as String?) ?? 'light',
    );
  }
}

class UserProfileDto {
  final String uid;
  final String name;
  final String email;
  final String mobileNumber;
  final String avatarEmoji;
  final String timezone;
  final String gender;
  final int age;
  final UserProfilePreferences preferences;

  const UserProfileDto({
    required this.uid,
    required this.name,
    required this.email,
    required this.mobileNumber,
    required this.avatarEmoji,
    required this.timezone,
    required this.gender,
    required this.age,
    required this.preferences,
  });

  factory UserProfileDto.fromJson(Map<String, dynamic> json) {
    final prefs = (json['preferences'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return UserProfileDto(
      uid: (json['uid'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      mobileNumber: (json['mobile_number'] as String?) ?? '',
      avatarEmoji: (json['avatar_emoji'] as String?) ?? '🙂',
      timezone: (json['timezone'] as String?) ?? 'UTC',
      gender: (json['gender'] as String?) ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      preferences: UserProfilePreferences.fromJson(prefs),
    );
  }
}

class FastApiService {
  FastApiService._();

  static final FastApiService instance = FastApiService._();
  final FirestoreService _firestore = FirestoreService.instance;

  static const Duration _timeout = Duration(seconds: 8);
  static final RegExp _uidPattern = RegExp(r'^[a-zA-Z0-9:_-]{6,128}$');

  String get _baseUrl => AppConstants.fastApiBaseUrl;

  Future<DailyBehaviorMetrics> getDailyBehaviorMetrics({
    required String uid,
    DateTime? date,
  }) async {
    if (!_uidPattern.hasMatch(uid)) {
      throw Exception('Invalid user id format');
    }

    final day = _dateKey(date ?? DateTime.now());
    final uri = Uri.parse('$_baseUrl/users/$uid/daily-metrics?date=$day');
    final headers = await _authHeaders();

    try {
      final res = await http.get(uri, headers: headers).timeout(_timeout);
      if (res.statusCode != 200) {
        throw Exception('FastAPI daily metrics failed: ${res.statusCode}');
      }

      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) {
        throw Exception('FastAPI daily metrics malformed response');
      }

      return DailyBehaviorMetrics.fromJson(body);
    } catch (_) {
      final focusCount = await _firestore.getCompletedFocusSessionsToday(uid);
      final habitCount = await _firestore.getCompletedHabitsToday(uid);
      return DailyBehaviorMetrics(
        focusSessionsCompleted: focusCount,
        habitsCompleted: habitCount,
        hasFocusSessionToday: focusCount > 0,
      );
    }
  }

  Future<UserProfileDto> getUserProfile({required String uid}) async {
    if (!_uidPattern.hasMatch(uid)) {
      throw Exception('Invalid user id format');
    }

    final uri = Uri.parse('$_baseUrl/users/$uid/profile');
    final headers = await _authHeaders();

    try {
      final res = await http.get(uri, headers: headers).timeout(_timeout);
      if (res.statusCode != 200) {
        throw Exception('FastAPI get profile failed: ${res.statusCode}');
      }

      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) {
        throw Exception('FastAPI profile malformed response');
      }

      return UserProfileDto.fromJson(body);
    } catch (_) {
      final data = await _firestore.getUserProfile(uid) ?? const <String, dynamic>{};
      final prefs = (data['preferences'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

      return UserProfileDto(
        uid: uid,
        name: (data['name'] as String?) ?? '',
        email: (data['email'] as String?) ?? '',
        mobileNumber: (data['mobileNumber'] as String?) ?? '',
        avatarEmoji: (data['avatarEmoji'] as String?) ?? '🙂',
        timezone: (data['timezone'] as String?) ?? 'UTC',
        gender: (data['gender'] as String?) ?? '',
        age: (data['age'] as num?)?.toInt() ?? 0,
        preferences: UserProfilePreferences(
          dailyScreenLimitMinutes:
              (prefs['dailyScreenLimitMinutes'] as num?)?.toInt() ?? 180,
          notificationsEnabled: (prefs['notificationsEnabled'] as bool?) ?? true,
          focusGoalMinutes: (prefs['focusGoalMinutes'] as num?)?.toInt() ?? 60,
          onboardingCompleted: (prefs['onboardingCompleted'] as bool?) ?? false,
          theme: (prefs['theme'] as String?) ?? 'light',
        ),
      );
    }
  }

  Future<void> upsertUserProfile({
    required String uid,
    String? name,
    String? mobileNumber,
    String? avatarEmoji,
    String? timezone,
    String? gender,
    int? age,
    int? dailyScreenLimitMinutes,
    bool? notificationsEnabled,
    int? focusGoalMinutes,
    bool? onboardingCompleted,
    String? theme,
  }) async {
    if (!_uidPattern.hasMatch(uid)) {
      throw Exception('Invalid user id format');
    }

    final prefs = <String, dynamic>{};
    if (dailyScreenLimitMinutes != null) {
      prefs['daily_screen_limit_minutes'] = dailyScreenLimitMinutes;
    }
    if (notificationsEnabled != null) {
      prefs['notifications_enabled'] = notificationsEnabled;
    }
    if (focusGoalMinutes != null) {
      prefs['focus_goal_minutes'] = focusGoalMinutes;
    }
    if (onboardingCompleted != null) {
      prefs['onboarding_completed'] = onboardingCompleted;
    }
    if (theme != null) {
      prefs['theme'] = theme;
    }

    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (mobileNumber != null) payload['mobile_number'] = mobileNumber;
    if (avatarEmoji != null) payload['avatar_emoji'] = avatarEmoji;
    if (timezone != null) payload['timezone'] = timezone;
    if (gender != null) payload['gender'] = gender;
    if (age != null) payload['age'] = age;
    if (prefs.isNotEmpty) payload['preferences'] = prefs;

    if (payload.isEmpty) return;

    final uri = Uri.parse('$_baseUrl/users/$uid/profile');
    final headers = await _authHeaders();
    try {
      final res = await http
          .put(
            uri,
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      if (res.statusCode != 200) {
        throw Exception('FastAPI upsert profile failed: ${res.statusCode}');
      }
    } catch (_) {
      await _firestore.updateUserProfile(
        uid: uid,
        name: name,
        avatarEmoji: avatarEmoji,
        timezone: timezone,
        mobileNumber: mobileNumber,
        gender: gender,
        age: age,
      );
      await _firestore.updateUserPreferences(
        uid: uid,
        dailyScreenLimitMinutes: dailyScreenLimitMinutes,
        notificationsEnabled: notificationsEnabled,
        focusGoalMinutes: focusGoalMinutes,
        onboardingCompleted: onboardingCompleted,
        theme: theme,
      );
    }
  }

  Future<List<String>> getAiInsights({
    required String uid,
    DateTime? date,
  }) async {
    if (!_uidPattern.hasMatch(uid)) {
      throw Exception('Invalid user id format');
    }

    final day = _dateKey(date ?? DateTime.now());
    final uri = Uri.parse('$_baseUrl/users/$uid/ai-insights?date=$day');
    final headers = await _authHeaders();

    final res = await http.get(uri, headers: headers).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('FastAPI ai-insights failed: ${res.statusCode}');
    }

    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('FastAPI ai-insights malformed response');
    }

    final insights = (body['insights'] as List?) ?? const <dynamic>[];
    return insights.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be signed in to call backend APIs');
    }

    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  Future<bool> hasCompletedFocusSessionToday({required String uid}) async {
    final metrics = await getDailyBehaviorMetrics(uid: uid);
    return metrics.hasFocusSessionToday;
  }

  static String _dateKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
