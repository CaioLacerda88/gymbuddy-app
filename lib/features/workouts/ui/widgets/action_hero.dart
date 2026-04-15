import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/radii.dart';
import '../../../routines/models/routine.dart';
import '../../../routines/providers/notifiers/routine_list_notifier.dart';
import '../../../routines/ui/start_routine_action.dart';
import '../../../weekly_plan/providers/suggested_next_provider.dart';
import '../../../weekly_plan/providers/weekly_plan_provider.dart';
import '../../../weekly_plan/utils/routine_duration_estimator.dart';
import '../../providers/workout_history_providers.dart';
import '../../providers/workout_providers.dart';
import 'resume_workout_dialog.dart';

/// The banner CTA on the Home screen. Resolves to one of four state modes
/// per PLAN W8:
///
/// 1. **Active plan, incomplete** — primary `"Start {suggestedNext}"`. Tapping
///    starts the next uncompleted routine in the bucket.
/// 2. **Brand new (no plan, no history)** — beginner CTA surfacing the
///    default Full Body (or alphabetical-first default) routine.
/// 3. **Lapsed (no plan, has history)** — primary `"Plan your week"` that
///    navigates to `/plan/week`, plus a secondary `"Quick workout"` text
///    button below.
/// 4. **Week complete** — primary `"Start new week"` that navigates to
///    `/plan/week`.
///
/// Watches only the providers required to decide the current mode. Rebuilds
/// isolate here rather than invalidating the whole Home tree.
class ActionHero extends ConsumerWidget {
  const ActionHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(weeklyPlanProvider);
    final plan = planAsync.value;
    final hasActivePlan = plan != null && plan.routines.isNotEmpty;

    if (hasActivePlan) {
      final isComplete = ref.watch(isWeekCompleteProvider);
      if (isComplete) {
        return _WeekCompleteHero(onPressed: () => context.push('/plan/week'));
      }
      return const _ActivePlanHero();
    }

    // No active plan. Differentiate brand-new vs lapsed on workoutCount.
    final workoutCountAsync = ref.watch(workoutCountProvider);
    // Wait for a committed value before deciding between the beginner CTA
    // and the lapsed CTA. Without this guard the wrong branch flashes in
    // the 200-600ms cold-start window.
    if (!workoutCountAsync.hasValue) return const SizedBox.shrink();
    final workoutCount = workoutCountAsync.value!;

    if (workoutCount == 0) {
      final routines = ref.watch(routineListProvider).value ?? [];
      final beginner = _pickBeginnerRoutine(routines);
      if (beginner == null) return const SizedBox.shrink();
      return _BeginnerCta(
        routine: beginner,
        onTap: () => startRoutineWorkout(context, ref, beginner),
      );
    }

    // Lapsed: user has history but no plan this week.
    return _LapsedHero(
      onPlanWeek: () => context.push('/plan/week'),
      onQuickWorkout: () => _startQuickWorkout(context, ref),
    );
  }

  /// Selects the routine to recommend to a brand-new user. Prefers
  /// "Full Body"; falls back to the alphabetical-first default.
  static Routine? _pickBeginnerRoutine(List<Routine> routines) {
    final defaults = routines.where((r) => r.isDefault).toList();
    if (defaults.isEmpty) return null;
    for (final r in defaults) {
      if (r.name == 'Full Body') return r;
    }
    defaults.sort((a, b) => a.name.compareTo(b.name));
    return defaults.first;
  }

  /// Starts an empty workout with the active-workout resume dialog guard.
  ///
  /// Mirrors the previous `HomeScreen._startEmptyWorkout` logic so the
  /// behavior is identical after the IA refresh.
  Future<void> _startQuickWorkout(BuildContext context, WidgetRef ref) async {
    final existingWorkout = ref.read(activeWorkoutProvider).value;
    if (existingWorkout != null) {
      if (!context.mounted) return;
      final result = await ResumeWorkoutDialog.show(
        context,
        workoutName: existingWorkout.workout.name,
        startedAt: existingWorkout.workout.startedAt,
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
          return;
        }
        return;
      } else {
        return;
      }
    }
    await ref.read(activeWorkoutProvider.notifier).startWorkout();
    if (!context.mounted) return;
    context.go('/workout/active');
  }
}

// ---------------------------------------------------------------------------
// Active plan: "Start {suggestedNext}"
// ---------------------------------------------------------------------------

class _ActivePlanHero extends ConsumerWidget {
  const _ActivePlanHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggested = ref.watch(suggestedNextProvider);
    if (suggested == null) return const SizedBox.shrink();

    final routines = ref.watch(routineListProvider).value ?? const <Routine>[];
    final routine = routines.cast<Routine?>().firstWhere(
      (r) => r?.id == suggested.routineId,
      orElse: () => null,
    );

    final label = routine?.name ?? 'Next workout';

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: routine == null
            ? null
            : () => startRoutineWorkout(context, ref, routine),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text('Start $label', overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lapsed: Plan your week (primary) + Quick workout (secondary)
// ---------------------------------------------------------------------------

class _LapsedHero extends StatelessWidget {
  const _LapsedHero({required this.onPlanWeek, required this.onQuickWorkout});

  final VoidCallback onPlanWeek;
  final VoidCallback onQuickWorkout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onPlanWeek,
          icon: const Icon(Icons.calendar_today_rounded),
          label: const Text('Plan your week'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: onQuickWorkout,
          child: const Text('Quick workout'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Week complete: Start new week
// ---------------------------------------------------------------------------

class _WeekCompleteHero extends StatelessWidget {
  const _WeekCompleteHero({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Start new week'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brand-new user: YOUR FIRST WORKOUT card (beginner CTA)
// ---------------------------------------------------------------------------

/// First-run banner CTA surfacing a recommended beginner routine with a
/// one-tap entry into an active workout. Dimensions (80dp) and copy are
/// preserved from the original implementation inside
/// `week_bucket_section.dart` so existing E2E selectors continue to match.
class _BeginnerCta extends StatelessWidget {
  const _BeginnerCta({required this.routine, required this.onTap});

  final Routine routine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final durationMin = estimateRoutineDurationMinutes(routine);
    final stats =
        '${routine.exercises.length} exercises \u00B7 ~$durationMin min';

    return Material(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusMd),
        onTap: onTap,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusMd),
            border: Border(
              left: BorderSide(color: theme.colorScheme.primary, width: 4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR FIRST WORKOUT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: mutedColor,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      routine.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stats,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.play_arrow,
                color: theme.colorScheme.primary,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
