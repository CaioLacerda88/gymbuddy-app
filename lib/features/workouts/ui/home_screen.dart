import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/workout_formatters.dart';
import '../../routines/ui/widgets/routine_action_sheet.dart';
import '../../routines/providers/notifiers/routine_list_notifier.dart';
import '../../routines/ui/start_routine_action.dart';
import '../../routines/ui/widgets/routine_card.dart';
import '../../personal_records/ui/widgets/recent_prs_section.dart';
import '../models/workout.dart';
import '../providers/workout_history_providers.dart';
import '../providers/workout_providers.dart';
import 'widgets/resume_workout_dialog.dart';

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
                // Exclude default routines from user list to avoid
                // duplicates (PO-009).
                final userRoutines = routines
                    .where((r) => r.userId != null && !r.isDefault)
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
                                showRoutineActionSheet(context, ref, r),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (defaultRoutines.isNotEmpty) ...[
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
                      ] else ...[
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
                  ],
                );
              },
            ),

            // Recent workouts
            historyAsync.when(
              loading: () => const _RecentWorkoutsSkeleton(),
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
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final existingWorkout = ref
                        .read(activeWorkoutProvider)
                        .valueOrNull;
                    if (existingWorkout != null) {
                      if (!context.mounted) return;
                      final result = await ResumeWorkoutDialog.show(
                        context,
                        workoutName: existingWorkout.workout.name,
                      );
                      if (!context.mounted) return;
                      if (result == ResumeWorkoutResult.resume) {
                        context.go('/workout/active');
                        return;
                      }
                      if (result == ResumeWorkoutResult.discard) {
                        try {
                          await ref
                              .read(activeWorkoutProvider.notifier)
                              .discardWorkout();
                        } catch (_) {
                          return; // discard failed — don't start a new workout
                        }
                      } else {
                        return; // dismissed
                      }
                    }
                    await ref
                        .read(activeWorkoutProvider.notifier)
                        .startWorkout();
                    if (!context.mounted) return;
                    context.go('/workout/active');
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Empty Workout'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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

/// Shimmer-style skeleton displayed while workout history is loading (PO-008).
class _RecentWorkoutsSkeleton extends StatelessWidget {
  const _RecentWorkoutsSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shimmerColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'RECENT'),
        const SizedBox(height: 12),
        for (int i = 0; i < 3; i++) ...[
          Container(
            height: 60,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
