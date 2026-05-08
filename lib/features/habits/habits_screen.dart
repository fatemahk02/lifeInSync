import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/input_sanitizer.dart';
import '../../shared/services/notification_service.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _nameController = TextEditingController();
  String _selectedEmoji = '⭐';
  TimeOfDay _selectedReminderTime = const TimeOfDay(hour: 20, minute: 0);
  int? _selectedReminderIntervalMinutes;
  final _firestore = FirestoreService.instance;
  final _notifications = NotificationService.instance;
  String _lastReminderSignature = '';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    unawaited(_ensureHabitsResetForToday());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _toggleHabit(HabitItem habit) async {
    final uid = _uid;
    if (uid == null) return;

    final completed = !habit.completedToday;
    final streak = completed
        ? habit.streak + 1
        : (habit.streak > 0 ? habit.streak - 1 : 0);

    await _firestore.updateHabit(
      uid: uid,
      habitId: habit.id,
      completedToday: completed,
      streak: streak,
    );
    await _firestore.logHabitCompletion(
      uid: uid,
      habitId: habit.id,
      habitName: habit.name,
      completed: completed,
    );

    await _notifications.maybeNotifyStreakMilestone(
      habitName: habit.name,
      streak: streak,
      completed: completed,
    );
  }

  Future<void> _removeHabit(HabitItem habit) async {
    final uid = _uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.tr('removeHabit')),
        content: Text(
          context.l10n.tr('confirmRemoveHabit').replaceFirst('{name}', habit.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              context.l10n.tr('removeHabit'),
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _notifications.cancelHabitReminders(uid: uid, habitId: habit.id);
    await _firestore.deleteHabit(uid: uid, habitId: habit.id);
  }

  Future<void> _ensureHabitsResetForToday() async {
    final uid = _uid;
    if (uid == null) return;
    await _firestore.resetHabitsForNewDay(uid);
  }

  Future<int?> _pickIntervalValue({int? initialValue}) async {
    final options = <int?>[null, 5, 10, 20];
    return showModalBottomSheet<int?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.tr('setRepeatInterval'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              ...options.map(
                (value) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    value == null
                        ? context.l10n.tr('noRepeatInterval')
                        : context.l10n
                              .tr('repeatEveryMinutes')
                              .replaceFirst('{minutes}', value.toString()),
                  ),
                  trailing: initialValue == value
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppTheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditHabitSheet(HabitItem habit) {
    final uid = _uid;
    if (uid == null) return;

    final editNameController = TextEditingController(text: habit.name);
    var selectedEmoji = habit.emoji;
    var selectedReminder = TimeOfDay(
      hour: habit.reminderHour,
      minute: habit.reminderMinute,
    );
    int? selectedInterval = habit.reminderIntervalMinutes;

    final emojiOptions = [
      '⭐',
      '💧',
      '🏃',
      '📚',
      '🧘',
      '✍️',
      '🍎',
      '😴',
      '💪',
      '🎯',
      '🧹',
      '📵',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.tr('editHabit'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.tr('chooseEmoji'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: emojiOptions
                    .map(
                      (e) => GestureDetector(
                        onTap: () => setSheet(() => selectedEmoji = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: selectedEmoji == e
                                ? AppTheme.primary.withOpacity(0.15)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedEmoji == e
                                  ? AppTheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(e, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.tr('habitName'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: editNameController,
                decoration: InputDecoration(
                  hintText: context.l10n.tr('habitNameHint'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.tr('reminderTime'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showTimePicker(
                        context: context,
                        initialTime: selectedReminder,
                      );
                      if (selected == null) return;
                      setSheet(() => selectedReminder = selected);
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(selectedReminder.format(context)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _pickIntervalValue(
                        initialValue: selectedInterval,
                      );
                      if (!mounted) return;
                      setSheet(() => selectedInterval = picked);
                    },
                    icon: const Icon(Icons.repeat_rounded),
                    label: Text(
                      selectedInterval == null
                          ? context.l10n.tr('noRepeatInterval')
                          : context.l10n
                                .tr('repeatEveryMinutes')
                                .replaceFirst(
                                  '{minutes}',
                                  selectedInterval.toString(),
                                ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  final cleanName = InputSanitizer.sanitizeHabitName(
                    editNameController.text,
                  );
                  if (cleanName.isEmpty) return;

                  await _firestore.updateHabitDetails(
                    uid: uid,
                    habitId: habit.id,
                    name: cleanName,
                    emoji: selectedEmoji,
                    reminderHour: selectedReminder.hour,
                    reminderMinute: selectedReminder.minute,
                    reminderIntervalMinutes: selectedInterval,
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3DBE7A), Color(0xFF2A8F58)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [AppTheme.primaryShadow],
                  ),
                  child: Center(
                    child: Text(
                      context.l10n.tr('saveProfile'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _syncHabitReminders(List<HabitItem> habits) async {
    final uid = _uid;
    if (uid == null) return;

    final signature = habits
        .map(
          (h) =>
              '${h.id}:${h.completedToday ? 1 : 0}:${h.reminderHour}:${h.reminderMinute}:${h.reminderIntervalMinutes ?? 0}',
        )
        .join('|');
    if (signature == _lastReminderSignature) return;

    _lastReminderSignature = signature;
    await _notifications.syncHabitReminders(uid: uid, habits: habits);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddHabitSheet(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          t.tr('addHabit'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        elevation: 4,
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.tr('habits'),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.tr('habitsSubtitle'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  StreamBuilder<List<HabitItem>>(
                    stream: _uid == null ? null : _firestore.streamHabits(_uid!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return Column(
                          children: [
                            _buildProgressSkeleton(),
                            const SizedBox(height: 20),
                            ...List.generate(
                              3,
                              (_) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildHabitSkeleton(),
                              ),
                            ),
                          ],
                        );
                      }

                      final habits = snapshot.data ?? const <HabitItem>[];
                      final completedCount =
                          habits.where((h) => h.completedToday).length;

                      unawaited(_syncHabitReminders(habits));

                      return Column(
                        children: [
                          _buildProgressCard(habits, completedCount)
                              .animate()
                              .fadeIn(delay: 100.ms)
                              .slideY(begin: 0.1),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                t.tr('todaysHabits'),
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              Text(
                                '$completedCount / ${habits.length}',
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (habits.isEmpty)
                            _buildEmptyState(context)
                          else
                          ...habits.asMap().entries.map(
                            (e) => _HabitCard(
                                  habit: e.value,
                                  onToggle: () => _toggleHabit(e.value),
                                  onEdit: () => _showEditHabitSheet(e.value),
                                  onRemove: () => _removeHabit(e.value),
                                )
                                .animate()
                                .fadeIn(
                                  delay: Duration(
                                    milliseconds: 200 + e.key * 70,
                                  ),
                                )
                                .slideX(begin: 0.1),
                          ),
                          const SizedBox(height: 80),
                        ],
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Column(
        children: [
          const Text('✨', style: TextStyle(fontSize: 30)),
          const SizedBox(height: 8),
          Text(context.l10n.tr('noHabitsYet'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            context.l10n.tr('tapAddHabitFirst'),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSkeleton() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }

  Widget _buildHabitSkeleton() {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadowLight],
      ),
    );
  }

  Widget _buildProgressCard(List<HabitItem> habits, int completedCount) {
    final totalStreak = habits.fold<int>(0, (sum, h) => sum + h.streak);
    final pct = habits.isEmpty ? 0.0 : completedCount / habits.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3DBE7A), Color(0xFF2A8F58)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [AppTheme.primaryShadow],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.tr('todayProgress'),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  '$completedCount / ${habits.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(pct * 100).round()}% ${context.l10n.tr('complete')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Column(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 30)),
              const SizedBox(height: 4),
              Text(
                '$totalStreak',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                context.l10n.tr('totalStreakDays').replaceFirst(' ', '\n'),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddHabitSheet(BuildContext context) {
    final emojiOptions = [
      '⭐',
      '💧',
      '🏃',
      '📚',
      '🧘',
      '✍️',
      '🍎',
      '😴',
      '💪',
      '🎯',
      '🧹',
      '📵',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.tr('newHabit'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),

              // Emoji picker
              Text(
                context.l10n.tr('chooseEmoji'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: emojiOptions
                    .map(
                      (e) => GestureDetector(
                        onTap: () => setSheet(() => _selectedEmoji = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _selectedEmoji == e
                                ? AppTheme.primary.withOpacity(0.15)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedEmoji == e
                                  ? AppTheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),

              // Name field
              Text(
                context.l10n.tr('habitName'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: context.l10n.tr('habitNameHint'),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                context.l10n.tr('reminderTime'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showTimePicker(
                        context: context,
                        initialTime: _selectedReminderTime,
                      );
                      if (selected == null) return;
                      setSheet(() => _selectedReminderTime = selected);
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(_selectedReminderTime.format(context)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _pickIntervalValue(
                        initialValue: _selectedReminderIntervalMinutes,
                      );
                      if (!mounted) return;
                      setSheet(() => _selectedReminderIntervalMinutes = picked);
                    },
                    icon: const Icon(Icons.repeat_rounded),
                    label: Text(
                      _selectedReminderIntervalMinutes == null
                          ? context.l10n.tr('noRepeatInterval')
                          : context.l10n
                                .tr('repeatEveryMinutes')
                                .replaceFirst(
                                  '{minutes}',
                                  _selectedReminderIntervalMinutes.toString(),
                                ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Add button
              GestureDetector(
                onTap: () async {
                  final uid = _uid;
                  final name = InputSanitizer.sanitizeHabitName(
                    _nameController.text,
                  );
                  _nameController.text = name;
                  if (uid != null && name.isNotEmpty) {
                    await _firestore.addHabit(
                      uid: uid,
                      name: name,
                      emoji: _selectedEmoji,
                      reminderHour: _selectedReminderTime.hour,
                      reminderMinute: _selectedReminderTime.minute,
                      reminderIntervalMinutes: _selectedReminderIntervalMinutes,
                    );
                    if (!mounted) return;
                    setState(() {
                      _nameController.clear();
                      _selectedEmoji = '⭐';
                      _selectedReminderTime = const TimeOfDay(
                        hour: 20,
                        minute: 0,
                      );
                      _selectedReminderIntervalMinutes = null;
                    });
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3DBE7A), Color(0xFF2A8F58)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [AppTheme.primaryShadow],
                  ),
                  child: Center(
                    child: Text(
                      context.l10n.tr('addHabit'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final HabitItem habit;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _HabitCard({
    required this.habit,
    required this.onToggle,
    required this.onEdit,
    required this.onRemove,
  });

  String _formatReminderTime() {
    final h = habit.reminderHour.toString().padLeft(2, '0');
    final m = habit.reminderMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: habit.completedToday
            ? AppTheme.primary.withOpacity(0.06)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: habit.completedToday
              ? AppTheme.primary.withOpacity(0.25)
              : Colors.grey.shade200,
        ),
        boxShadow: [AppTheme.cardShadowLight],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: habit.completedToday
                      ? AppTheme.primary.withOpacity(0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(habit.emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: habit.completedToday
                            ? AppTheme.primary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              '${habit.streak} ${context.l10n.tr('dayStreak')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            habit.frequency,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: habit.completedToday
                        ? AppTheme.primary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: habit.completedToday
                          ? AppTheme.primary
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: habit.completedToday
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 390;

              final reminderWidget = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatReminderTime()}   ${habit.reminderIntervalMinutes == null ? context.l10n.tr('noRepeatInterval') : context.l10n.tr('repeatEveryMinutes').replaceFirst('{minutes}', habit.reminderIntervalMinutes.toString())}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );

              final actionsWidget = Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(
                      context.l10n.tr('editHabit'),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: onRemove,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(
                      context.l10n.tr('removeHabit'),
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    reminderWidget,
                    const SizedBox(height: 8),
                    actionsWidget,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: reminderWidget),
                  const SizedBox(width: 8),
                  actionsWidget,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
