import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/fastapi_service.dart';
import '../../shared/services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _avatar = '🙂';
  String _timezone = 'UTC';
  String _gender = '';
  bool _saving = false;

  static const _avatars = ['🙂', '😎', '🌿', '⭐', '🔥', '💪', '🧠', '🚀'];
  static const _genders = ['male', 'female', 'other', 'preferNotToSay'];

  String _genderLabel(AppLocalizations t, String key) => t.tr(key);

  String _normalizeGender(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '';

    final compact = value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    switch (compact) {
      case 'male':
        return 'male';
      case 'female':
        return 'female';
      case 'other':
        return 'other';
      case 'prefernottosay':
        return 'preferNotToSay';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;

    final profile = await FirestoreService.instance.getUserProfile(uid);
    String tz = 'UTC';
    try {
      tz = await FlutterTimezone.getLocalTimezone();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _nameController.text = (profile?['name'] as String?) ??
          FirebaseAuth.instance.currentUser?.displayName ??
          '';
      _avatar = (profile?['avatarEmoji'] as String?) ?? '🙂';
      _timezone = (profile?['timezone'] as String?) ?? tz;
      _gender = _normalizeGender(profile?['gender'] as String?);
      final profileAge = (profile?['age'] as num?)?.toInt() ?? 0;
      _ageController.text = profileAge > 0 ? '$profileAge' : '';
    });
  }

  Future<void> _save() async {
    final uid = _uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      final parsedAge = int.tryParse(_ageController.text.trim());
      final age = (parsedAge != null && parsedAge >= 1 && parsedAge <= 120)
          ? parsedAge
          : null;
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      try {
        await FastApiService.instance.upsertUserProfile(
          uid: uid,
          name: name,
          avatarEmoji: _avatar,
          timezone: _timezone,
          gender: _gender.isEmpty ? null : _gender,
          age: age,
        );
      } catch (_) {
        await FirestoreService.instance.updateUserProfile(
          uid: uid,
          name: name,
          avatarEmoji: _avatar,
          timezone: _timezone,
          gender: _gender.isEmpty ? null : _gender,
          age: age,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.tr('profileUpdated'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final selectedGender = _genders.contains(_normalizeGender(_gender))
        ? _normalizeGender(_gender)
        : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(t.tr('profile'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.tr('name')),
                const SizedBox(height: 8),
                TextField(controller: _nameController),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.tr('avatar')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _avatars.map((emoji) {
                    final selected = emoji == _avatar;
                    return GestureDetector(
                      onTap: () => setState(() => _avatar = emoji),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primary.withOpacity(0.18)
                              : Colors.transparent,
                          border: Border.all(
                            color: selected ? AppTheme.primary : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.tr('timezone')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _timezone,
                  items: [_timezone, 'UTC', 'Asia/Kolkata', 'Europe/London', 'America/New_York']
                      .toSet()
                      .map(
                        (tz) => DropdownMenuItem<String>(
                          value: tz,
                          child: Text(tz),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) {
                    if (v != null) setState(() => _timezone = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.tr('gender')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey('gender_${selectedGender ?? 'none'}'),
                  value: selectedGender,
                  hint: Text(t.tr('selectGender')),
                  items: _genders
                      .map(
                        (g) => DropdownMenuItem<String>(
                          value: g,
                          child: Text(_genderLabel(t, g)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) => setState(
                    () => _gender = _normalizeGender(v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.tr('age')),
                const SizedBox(height: 8),
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: t.tr('enterAgeHint')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.tr('saveProfile')),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: child,
    );
  }
}
