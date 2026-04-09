import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/workout_formatters.dart';
import '../../profile/providers/profile_providers.dart';
import '../../weekly_plan/providers/weekly_plan_provider.dart';
import '../../weekly_plan/ui/widgets/week_bucket_section.dart';
import '../../routines/providers/notifiers/routine_list_notifier.dart';
import '../../routines/ui/start_routine_action.dart';
import '../../routines/ui/widgets/routine_action_sheet.dart';
import '../../routines/ui/widgets/routine_card.dart';
import '../providers/workout_history_providers.dart';
import '../providers/workout_providers.dart';
import 'widgets/contextual_stat_cell.dart';
import 'widgets/resume_workout_dialog.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final planAsync = ref.watch(weeklyPlanProvider);
    final routinesAsync = ref.watch(routineListProvider);

    // Determine if user has an active weekly plan.
    final hasActivePlan =
        planAsync.valueOrNull != null &&
        (planAsync.valueOrNull?.routines.isNotEmpty ?? false);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header — Date + user display name
            const SizedBox(height: 8),
            Text(
              DateFormat('EEE, MMM d').format(DateTime.now()).toUpperCase(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (profile?.displayName != null &&
                profile!.displayName!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(profile.displayName!, style: theme.textTheme.headlineMedium),
            ],
            const SizedBox(height: 20),

            // 2. THIS WEEK section (hero) — always above the fold
            const WeekBucketSection(),

            // 3. Contextual stat cells
            const _ContextualStatCells(),
            const SizedBox(height: 20),

            // 4. Start Empty Workout — FilledButton, full-width
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _startEmptyWorkout(context, ref),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Empty Workout'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 5. Routines list — hidden when user has active plan
            if (!hasActivePlan)
              routinesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text(
                  'Failed to load routines',
                  style: theme.textTheme.bodyMedium,
                ),
                data: (routines) {
                  final userRoutines = routines
                      .where((r) => r.userId != null && !r.isDefault)
                      .toList();
                  final defaultRoutines = routines
                      .where((r) => r.isDefault)
                      .toList();

                  // Only show onboarding CTA when no routines at all.
                  if (userRoutines.isEmpty && defaultRoutines.isEmpty) {
                    return const _CreateRoutineCta();
                  }

                  return _RoutinesList(
                    userRoutines: userRoutines,
                    defaultRoutines: defaultRoutines,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _startEmptyWorkout(BuildContext context, WidgetRef ref) async {
    final existingWorkout = ref.read(activeWorkoutProvider).valueOrNull;
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
          await ref.read(activeWorkoutProvider.notifier).discardWorkout();
        } catch (_) {
          return; // discard failed — don't start a new workout
        }
        return; // discard succeeded — don't start a new workout
      } else {
        return; // dismissed
      }
    }
    await ref.read(activeWorkoutProvider.notifier).startWorkout();
    if (!context.mounted) return;
    context.go('/workout/active');
  }
}

/// Two horizontal stat cells: last session + this week's volume.
class _ContextualStatCells extends ConsumerWidget {
  const _ContextualStatCells();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastSession = ref.watch(lastSessionProvider);
    final weekVolume = ref.watch(weekVolumeProvider);
    final weightUnit =
        ref.watch(profileProvider).valueOrNull?.weightUnit ?? 'kg';

    final lastValue = lastSession != null
        ? '${lastSession.relativeDate} \u2014 ${lastSession.name}'
        : 'No workouts yet';

    final volumeValue = weekVolume.when(
      data: (v) => v > 0
          ? '${WorkoutFormatters.formatVolume(v).replaceAll('kg', weightUnit)} this week'
          : 'No volume yet',
      loading: () => '--',
      error: (_, _) => '--',
    );

    return Row(
      children: [
        Expanded(
          child: ContextualStatCell(
            label: 'Last session',
            value: lastValue,
            onTap: () => context.push('/home/history'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ContextualStatCell(
            label: "Week's volume",
            value: volumeValue,
            onTap: () => context.push('/home/history'),
          ),
        ),
      ],
    );
  }
}

/// Routines list shown when user has no active weekly plan.
class _RoutinesList extends ConsumerWidget {
  const _RoutinesList({
    required this.userRoutines,
    required this.defaultRoutines,
  });

  final List<dynamic> userRoutines;
  final List<dynamic> defaultRoutines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (userRoutines.isNotEmpty) ...[
          Text(
            'MY ROUTINES',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          ...userRoutines.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RoutineCard(
                routine: r,
                onTap: () => startRoutineWorkout(context, ref, r),
                onLongPress: () => showRoutineActionSheet(context, ref, r),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (defaultRoutines.isNotEmpty) ...[
          Text(
            'STARTER ROUTINES',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
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
