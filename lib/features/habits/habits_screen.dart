import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';

class Habit {
  final String id;
  final String name;
  final String emoji;
  final String frequency;
  int streak;
  bool completedToday;

  Habit({
    required this.id,
    required this.name,
    required this.emoji,
    required this.frequency,
    this.streak = 0,
    this.completedToday = false,
  });
}

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final List<Habit> _habits = [
    Habit(
      id: '1',
      name: 'Drink 8 glasses of water',
      emoji: '💧',
      frequency: 'Daily',
      streak: 12,
      completedToday: true,
    ),
    Habit(
      id: '2',
      name: 'Exercise 30 minutes',
      emoji: '🏃',
      frequency: 'Daily',
      streak: 7,
      completedToday: true,
    ),
    Habit(
      id: '3',
      name: 'Read for 20 minutes',
      emoji: '📚',
      frequency: 'Daily',
      streak: 5,
      completedToday: false,
    ),
    Habit(
      id: '4',
      name: 'Meditate',
      emoji: '🧘',
      frequency: 'Daily',
      streak: 21,
      completedToday: true,
    ),
    Habit(
      id: '5',
      name: 'No phone after 10pm',
      emoji: '📵',
      frequency: 'Daily',
      streak: 3,
      completedToday: false,
    ),
    Habit(
      id: '6',
      name: 'Journaling',
      emoji: '✍️',
      frequency: 'Daily',
      streak: 9,
      completedToday: false,
    ),
  ];

  bool _showAddDialog = false;
  final _nameController = TextEditingController();
  String _selectedEmoji = '⭐';

  int get _completedCount => _habits.where((h) => h.completedToday).length;

  int get _totalStreak => _habits.fold(0, (sum, h) => sum + h.streak);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggleHabit(Habit habit) {
    setState(() {
      habit.completedToday = !habit.completedToday;
      if (habit.completedToday) {
        habit.streak++;
      } else {
        if (habit.streak > 0) habit.streak--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddHabitSheet(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Habit',
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
                      'Habits',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Build your daily routines',
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
                  // Progress card
                  _buildProgressCard()
                      .animate()
                      .fadeIn(delay: 100.ms)
                      .slideY(begin: 0.1),
                  const SizedBox(height: 20),

                  // Today's habits header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Habits",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '$_completedCount / ${_habits.length}',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Habit list
                  ..._habits.asMap().entries.map(
                    (e) =>
                        _HabitCard(
                              habit: e.value,
                              onToggle: () => _toggleHabit(e.value),
                            )
                            .animate()
                            .fadeIn(
                              delay: Duration(milliseconds: 200 + e.key * 70),
                            )
                            .slideX(begin: 0.1),
                  ),

                  const SizedBox(height: 80), // FAB padding
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final pct = _habits.isEmpty ? 0.0 : _completedCount / _habits.length;

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
                const Text(
                  'Today\'s Progress',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_completedCount / ${_habits.length}',
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
                  '${(pct * 100).round()}% complete',
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
                '$_totalStreak',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'total\nstreak days',
                style: TextStyle(color: Colors.white70, fontSize: 11),
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
                'New Habit',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),

              // Emoji picker
              const Text(
                'Choose an emoji',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
              const Text(
                'Habit name',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Drink water, Exercise...',
                ),
              ),
              const SizedBox(height: 24),

              // Add button
              GestureDetector(
                onTap: () {
                  if (_nameController.text.isNotEmpty) {
                    setState(() {
                      _habits.add(
                        Habit(
                          id: DateTime.now().toString(),
                          name: _nameController.text,
                          emoji: _selectedEmoji,
                          frequency: 'Daily',
                          streak: 0,
                          completedToday: false,
                        ),
                      );
                      _nameController.clear();
                      _selectedEmoji = '⭐';
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
                  child: const Center(
                    child: Text(
                      'Add Habit',
                      style: TextStyle(
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
    );
  }
}

class _HabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback onToggle;

  const _HabitCard({required this.habit, required this.onToggle});

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
      child: Row(
        children: [
          // Emoji
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

          // Name + streak
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
                    decoration: habit.completedToday
                        ? TextDecoration.none
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      '${habit.streak} day streak',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 10),
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

          // Toggle button
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
    );
  }
}
