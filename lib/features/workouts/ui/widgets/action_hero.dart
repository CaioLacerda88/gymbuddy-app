import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/connectivity/connectivity_provider.dart';
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

/// Selects the routine to recommend to a brand-new user. Prefers
/// "Full Body"; falls back to the alphabetical-first default.
///
/// Top-level because it is a pure function over [List<Routine>] with no
/// dependency on widget state — keeping it outside the widget class makes it
/// trivially testable in isolation.
Routine? pickBeginnerRoutine(List<Routine> routines) {
  final defaults = routines.where((r) => r.isDefault).toList();
  if (defaults.isEmpty) return null;
  for (final r in defaults) {
    if (r.name == 'Full Body') return r;
  }
  defaults.sort((a, b) => a.name.compareTo(b.name));
  return defaults.first;
}

/// The banner CTA on the Home screen. Resolves to one of four state modes
/// per PLAN W8:
///
/// 1. **Active plan, incomplete** — primary `"Start {suggestedNext}"`. Tapping
///    starts the next uncompleted routine in the bucket.
/// 2. **Brand new (no plan, no history)** — beginner CTA surfacing the
///    default Full Body (or alphabetical-first default) routine.
/// 3. **Lapsed (no plan, has history)** — a `_HeroBanner` "Plan your week"
///    primary (same surface vocabulary as the other three hero states) plus
///    a clearly-secondary "Quick workout" `OutlinedButton` below.
/// 4. **Week complete** — primary `"Start new week"` that navigates to
///    `/plan/week`.
///
/// Watches only the minimum set of providers required to decide the current
/// mode. Per-state widgets are extracted so Riverpod only registers listeners
/// that are actually needed for the active branch — e.g. [_BrandNewHero]
/// owns its `routineListProvider` subscription so [ActionHero] does NOT
/// rebuild whenever any routine is added/edited/deleted.
class ActionHero extends ConsumerWidget {
  const ActionHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Scoped subscription: this derived provider only flips when a plan is
    // created / cleared / emptied, not on every routine mutation inside a
    // plan.
    final hasActivePlan = ref.watch(hasActivePlanProvider);

    if (hasActivePlan) {
      final isComplete = ref.watch(isWeekCompleteProvider);
      if (isComplete) {
        return _WeekCompleteHero(onTap: () => context.push('/plan/week'));
      }
      return const _ActivePlanHero();
    }

    // No active plan. Differentiate brand-new vs lapsed on workoutCount.
    final workoutCountAsync = ref.watch(workoutCountProvider);
    // Wait for a committed value before deciding between the beginner CTA
    // and the lapsed CTA. Without this guard the wrong branch flashes in
    // the 200-600ms cold-start window.
    //
    // Note: `workoutCountProvider` is `keepAlive` — once warmed up, it
    // survives nav transitions, so this wait only matters on the very first
    // Home mount of the session. `workoutHistoryProvider` does NOT keepAlive
    // and would need a full page load to repopulate, giving a noticeably
    // longer flash window if we gated on it here instead.
    if (!workoutCountAsync.hasValue) return const SizedBox.shrink();
    final workoutCount = workoutCountAsync.value!;

    if (workoutCount == 0) {
      return const _BrandNewHero();
    }

    // Lapsed: user has history but no plan this week.
    return _LapsedHero(
      onPlanWeek: () => context.push('/plan/week'),
      onQuickWorkout: () => _startQuickWorkout(context, ref),
    );
  }

  /// Starts an empty workout with the active-workout resume dialog guard.
  ///
  /// Three outcomes when an existing workout is present:
  /// * **Resume** — navigate to `/workout/active` and keep the existing
  ///   workout intact.
  /// * **Discard** — delete the existing workout, start a fresh one, and
  ///   navigate to `/workout/active`. The user chose "Quick workout" intending
  ///   to start fresh; stopping after the discard would leave them staring at
  ///   Home with nothing happening.
  /// * **Dismissed** (`result == null`) — currently impossible because the
  ///   dialog is shown with `barrierDismissible: false`, but guarded here as
  ///   a no-op so a future dismissible variant does not need to touch this
  ///   code.
  ///
  /// When there is no existing workout we just start one and navigate.
  Future<void> _startQuickWorkout(BuildContext context, WidgetRef ref) async {
    // Guard: starting a workout requires a network call to create it.
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(kOfflineStartWorkoutMessage)),
        );
      }
      return;
    }

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
          return; // discard failed — do not silently start a new workout
        }
        if (!context.mounted) return;
        await ref.read(activeWorkoutProvider.notifier).startWorkout();
        if (!context.mounted) return;
        context.go('/workout/active');
        return;
      }
      // result == null (dialog dismissed). Unreachable today due to
      // barrierDismissible: false — treat as cancel.
      return;
    }
    await ref.read(activeWorkoutProvider.notifier).startWorkout();
    if (!context.mounted) return;
    context.go('/workout/active');
  }
}

// ---------------------------------------------------------------------------
// Active plan: 80dp banner — UP NEXT label + routine name + metadata
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
    if (routine == null) return const SizedBox.shrink();

    final durationMin = estimateRoutineDurationMinutes(routine);
    final metadata =
        '${routine.exercises.length} exercises \u00B7 ~$durationMin min';

    return _HeroBanner(
      label: 'UP NEXT',
      headline: routine.name,
      subline: metadata,
      onTap: () => startRoutineWorkout(context, ref, routine),
      semanticsIdentifier: 'home-up-next',
    );
  }
}

// ---------------------------------------------------------------------------
// Brand new: YOUR FIRST WORKOUT — recommended default routine (e.g. Full Body)
// ---------------------------------------------------------------------------

/// First-run hero. Extracted as its own [ConsumerWidget] so the
/// `routineListProvider` subscription lives only on this branch — otherwise
/// `ActionHero` would re-subscribe whenever any routine is added/edited/
/// deleted, regardless of which state the hero is actually in.
class _BrandNewHero extends ConsumerWidget {
  const _BrandNewHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routineListProvider).value ?? const <Routine>[];
    final beginner = pickBeginnerRoutine(routines);
    if (beginner == null) return const SizedBox.shrink();
    return _BeginnerCta(
      routine: beginner,
      onTap: () => startRoutineWorkout(context, ref, beginner),
    );
  }
}

// ---------------------------------------------------------------------------
// Lapsed: [_HeroBanner] "Plan your week" (primary) + OutlinedButton
// "Quick workout" (secondary)
// ---------------------------------------------------------------------------

/// Lapsed-state hero. Shares the [_HeroBanner] surface with the three other
/// hero states (active plan / brand-new / week-complete) so the four modes
/// read as variants of one banner, not four unrelated components. Underneath
/// the banner we keep a secondary [OutlinedButton] "Quick workout" — a
/// clearly-secondary affordance, not a second hero.
class _LapsedHero extends StatelessWidget {
  const _LapsedHero({required this.onPlanWeek, required this.onQuickWorkout});

  final VoidCallback onPlanWeek;
  final VoidCallback onQuickWorkout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroBanner(
          label: 'NO PLAN',
          headline: 'Plan your week',
          subline: 'Pick routines for the week',
          onTap: onPlanWeek,
          semanticsIdentifier: 'home-plan-your-week',
        ),
        const SizedBox(height: 8),
        Semantics(
          container: true,
          identifier: 'home-quick-workout',
          child: OutlinedButton(
            onPressed: onQuickWorkout,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Quick workout'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Week complete: 80dp banner — NEW WEEK label + "Start new week" + Y of Y done
// ---------------------------------------------------------------------------

class _WeekCompleteHero extends ConsumerWidget {
  const _WeekCompleteHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(totalBucketCountProvider);
    return _HeroBanner(
      label: 'NEW WEEK',
      headline: 'Start new week',
      subline: total > 0 ? '$total of $total done' : null,
      onTap: onTap,
      semanticsIdentifier: 'home-start-new-week',
    );
  }
}

// ---------------------------------------------------------------------------
// Brand-new user: YOUR FIRST WORKOUT card (beginner CTA)
// ---------------------------------------------------------------------------

/// First-run banner CTA surfacing a recommended beginner routine with a
/// one-tap entry into an active workout. Shares the [_HeroBanner] vocabulary
/// with [_ActivePlanHero] and [_WeekCompleteHero] so the four hero states
/// read as variants of one surface, not four unrelated cards.
class _BeginnerCta extends StatelessWidget {
  const _BeginnerCta({required this.routine, required this.onTap});

  final Routine routine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final durationMin = estimateRoutineDurationMinutes(routine);
    final stats =
        '${routine.exercises.length} exercises \u00B7 ~$durationMin min';

    return _HeroBanner(
      label: 'YOUR FIRST WORKOUT',
      headline: routine.name,
      subline: stats,
      onTap: onTap,
      semanticsIdentifier: 'first-workout-card',
      labelIdentifier: 'first-workout-label',
    );
  }
}

// ---------------------------------------------------------------------------
// Shared 80dp banner surface for all four hero variants (active plan,
// brand-new beginner, lapsed "Plan your week", week complete). One
// Material+InkWell card with a left accent border in primary green,
// label / headline / subline rows, and a trailing play glyph. Background
// flows through theme.cardTheme.color so the banner inherits app-wide
// surface tokens.
// ---------------------------------------------------------------------------

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.label,
    required this.headline,
    this.subline,
    required this.onTap,
    this.semanticsIdentifier,
    this.labelIdentifier,
  });

  /// Small uppercase label, e.g. "UP NEXT", "YOUR FIRST WORKOUT", "NO PLAN",
  /// "NEW WEEK".
  final String label;

  /// Primary content line, e.g. routine name, "Plan your week", "Start new
  /// week".
  final String headline;

  /// Optional metadata line below the headline (exercises x duration, "Y of Y
  /// done", etc.). When null the banner renders only the label + headline.
  final String? subline;

  /// Optional Semantics identifier for locale-independent E2E selectors.
  final String? semanticsIdentifier;

  /// Optional Semantics identifier for the label Text widget.
  final String? labelIdentifier;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Semantics(
      container: true,
      identifier: semanticsIdentifier,
      child: Material(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusMd),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border(
                  left: BorderSide(color: theme.colorScheme.primary, width: 4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            container: true,
                            identifier: labelIdentifier,
                            child: Text(
                              label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: mutedColor,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Bare container prevents AOM merging headline
                          // into the label's accessible text node.
                          Semantics(
                            container: true,
                            child: Text(
                              headline,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (subline != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subline!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: mutedColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
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
          ),
        ),
      ),
    );
  }
}
