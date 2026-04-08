import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/workout_formatters.dart';
import '../../../shared/widgets/section_header.dart';
import '../../personal_records/providers/pr_providers.dart';
import '../../weekly_plan/ui/widgets/week_bucket_section.dart';
import '../../routines/ui/widgets/routine_action_sheet.dart';
import '../../routines/providers/notifiers/routine_list_notifier.dart';
import '../../routines/ui/start_routine_action.dart';
import '../../routines/ui/widgets/routine_card.dart';
import '../providers/workout_history_providers.dart';
import '../providers/workout_providers.dart';
import 'widgets/resume_workout_dialog.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final routinesAsync = ref.watch(routineListProvider);

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
            const SizedBox(height: 16),

            // Stat cards
            const _StatCardsRow(),
            const SizedBox(height: 20),

            // Weekly plan section
            const WeekBucketSection(),

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
                      const SectionHeader(title: 'MY ROUTINES'),
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
                        const SectionHeader(title: 'STARTER ROUTINES'),
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
                        const SectionHeader(title: 'STARTER ROUTINES'),
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
                        return; // discard succeeded — don't start a new workout
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

class _StatCardsRow extends ConsumerWidget {
  const _StatCardsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutCount = ref.watch(workoutCountProvider);
    final prCount = ref.watch(prCountProvider);
    final historyAsync = ref.watch(workoutHistoryProvider);
    final recentPRs = ref.watch(recentPRsProvider);

    // Derive workout subtitle from most recent workout date.
    final workoutSubtitle = historyAsync.whenOrNull(
      data: (workouts) {
        if (workouts.isEmpty) return null;
        final lastDate = workouts.first.finishedAt ?? workouts.first.startedAt;
        return WorkoutFormatters.formatRelativeDate(lastDate);
      },
    );

    // Derive records subtitle from most recent PR exercise name.
    final recordsSubtitle = recentPRs.whenOrNull(
      data: (prs) {
        if (prs.isEmpty) return null;
        return prs.first.exerciseName;
      },
    );

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            count: workoutCount,
            label: 'Workouts',
            subtitle: workoutSubtitle,
            onTap: () => context.push('/home/history'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            count: prCount,
            label: 'Records',
            subtitle: recordsSubtitle,
            onTap: () => context.push('/records'),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.count,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final AsyncValue<int> count;
  final String label;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countText = count.when(
      data: (v) => '$v',
      loading: () => '--',
      error: (_, _) => '--',
    );

    final semanticLabel = count.when(
      data: (v) => '$v $label, tap to view ${label.toLowerCase()}',
      loading: () => '$label loading',
      error: (_, _) => '$label unavailable',
    );

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 32,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        countText,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
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
