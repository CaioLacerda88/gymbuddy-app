import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/workout_formatters.dart';
import '../../routines/models/routine.dart';
import '../../routines/providers/notifiers/routine_list_notifier.dart';
import '../../routines/ui/start_routine_action.dart';
import '../../routines/ui/widgets/routine_card.dart';
import '../../personal_records/ui/widgets/recent_prs_section.dart';
import '../models/workout.dart';
import '../providers/workout_history_providers.dart';
import '../providers/workout_providers.dart';
import 'widgets/resume_workout_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final routinesAsync = ref.watch(routineListProvider);
    final historyAsync = ref.watch(workoutHistoryProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resume active workout banner (hidden when no active workout)
            const ResumeWorkoutBanner(),

            // Header
            const SizedBox(height: 8),
            Text('GymBuddy', style: theme.textTheme.displayMedium),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEE, MMM d').format(DateTime.now()),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),

            // Routines sections
            routinesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text(
                'Failed to load routines',
                style: theme.textTheme.bodyMedium,
              ),
              data: (routines) {
                final userRoutines = routines
                    .where((r) => r.userId != null)
                    .toList();
                final defaultRoutines = routines
                    .where((r) => r.isDefault)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (userRoutines.isNotEmpty) ...[
                      const _SectionHeader(title: 'MY ROUTINES'),
                      const SizedBox(height: 8),
                      ...userRoutines.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: RoutineCard(
                            routine: r,
                            onTap: () => startRoutineWorkout(context, ref, r),
                            onLongPress: () =>
                                _showRoutineActions(context, ref, r),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (userRoutines.isEmpty) ...[
                      const _SectionHeader(title: 'STARTER ROUTINES'),
                      const SizedBox(height: 8),
                      ...defaultRoutines.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: RoutineCard(
                            routine: r,
                            onTap: () => startRoutineWorkout(context, ref, r),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _CreateRoutineCta(),
                      const SizedBox(height: 16),
                    ],
                    if (userRoutines.isNotEmpty &&
                        defaultRoutines.isNotEmpty) ...[
                      const _SectionHeader(title: 'STARTER ROUTINES'),
                      const SizedBox(height: 8),
                      ...defaultRoutines.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: RoutineCard(
                            routine: r,
                            onTap: () => startRoutineWorkout(context, ref, r),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),

            // Recent workouts
            historyAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (workouts) {
                if (workouts.isEmpty) return const SizedBox.shrink();
                final recent = workouts.take(3).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionHeader(title: 'RECENT'),
                        TextButton(
                          onPressed: () => context.go('/home/history'),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...recent.map((w) => _RecentWorkoutRow(workout: w)),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // Recent personal records
            const RecentPRsSection(),

            // Start empty workout
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  await ref.read(activeWorkoutProvider.notifier).startWorkout();
                  if (!context.mounted) return;
                  context.go('/workout/active');
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Empty Workout'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

Future<void> _showRoutineActions(
  BuildContext context,
  WidgetRef ref,
  Routine routine,
) async {
  final action = await showModalBottomSheet<_RoutineAction>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () => Navigator.pop(context, _RoutineAction.edit),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => Navigator.pop(context, _RoutineAction.delete),
          ),
        ],
      ),
    ),
  );

  if (!context.mounted) return;

  if (action == _RoutineAction.edit) {
    context.go('/routines/create', extra: routine);
  } else if (action == _RoutineAction.delete) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine'),
        content: Text('Delete "${routine.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(routineListProvider.notifier).deleteRoutine(routine.id);
    }
  }
}

enum _RoutineAction { edit, delete }

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

class _CreateRoutineCta extends StatelessWidget {
  const _CreateRoutineCta();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go('/routines/create'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Create Your First Routine',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentWorkoutRow extends StatelessWidget {
  const _RecentWorkoutRow({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateText = WorkoutFormatters.formatWorkoutDate(
      workout.finishedAt ?? workout.startedAt,
    );
    final durationText = WorkoutFormatters.formatDuration(
      workout.durationSeconds,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go('/home/history/${workout.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.name,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dateText  \u00b7  $durationText',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
