import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/radii.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../../routines/models/routine.dart';
import '../../../routines/providers/notifiers/routine_list_notifier.dart';
import '../../../routines/ui/start_routine_action.dart';
import '../../../workouts/providers/workout_history_providers.dart';
import '../../data/models/weekly_plan.dart';
import '../../providers/suggested_next_provider.dart';
import '../../providers/week_review_stats_provider.dart';
import '../../providers/weekly_plan_provider.dart';
import '../../utils/routine_duration_estimator.dart';
import 'routine_chip.dart';
import 'week_review_section.dart';

/// The THIS WEEK section on the Home screen.
///
/// Displays an ordered row of routine chips showing bucket progress.
/// Transforms to WEEK COMPLETE when all routines are done.
/// Hidden when user has no routines at all.
class WeekBucketSection extends ConsumerWidget {
  const WeekBucketSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(weeklyPlanProvider);
    final routinesAsync = ref.watch(routineListProvider);
    final needsConfirmation = ref.watch(weeklyPlanNeedsConfirmationProvider);

    // Show previous data during reload instead of blank. Only hide on
    // initial load (no cached value) or error without cached value.
    if (planAsync.isLoading && !planAsync.hasValue) {
      return const SizedBox.shrink();
    }
    if (planAsync.hasError && !planAsync.hasValue) {
      return const SizedBox.shrink();
    }

    final plan = planAsync.value;
    final routines = routinesAsync.value ?? [];
    if (routines.isEmpty) return const SizedBox.shrink();

    // Build routine name map from available routines.
    final routineMap = <String, Routine>{for (final r in routines) r.id: r};
    final nameMap = <String, String>{for (final r in routines) r.id: r.name};

    // No plan set yet — decide between beginner CTA and "Plan your week" CTA.
    if (plan == null || plan.routines.isEmpty) {
      // Brand-new users (zero finished workouts) get a one-tap beginner CTA
      // that jumps straight into a Full Body workout, bypassing the "plan
      // your week" configuration step which is paradox-of-choice for someone
      // who has never lifted. Once they log their first workout the CTA
      // disappears and the normal "Plan your week" prompt returns.
      final workoutCountAsync = ref.watch(workoutCountProvider);
      // Wait for a committed value before deciding between the beginner CTA
      // and the "Plan your week" fallback. Without this guard the CTA flashes
      // the wrong branch during the 200-600ms cold-start window (value is
      // null → count != 0 → _EmptyBucketState), and on transient errors the
      // CTA would never render that session.
      if (!workoutCountAsync.hasValue) return const SizedBox.shrink();
      final workoutCount = workoutCountAsync.value!;
      if (workoutCount == 0) {
        final beginnerRoutine = _pickBeginnerRoutine(routines);
        if (beginnerRoutine != null) {
          return _BeginnerRoutineCta(
            routine: beginnerRoutine,
            onTap: () => startRoutineWorkout(context, ref, beginnerRoutine),
          );
        }
        // No defaults to suggest — don't fall back to "Plan your week"
        // either; render nothing so the screen stays calm.
        return const SizedBox.shrink();
      }
      return _EmptyBucketState(hasRoutines: routines.isNotEmpty);
    }

    // Check if week is complete.
    final isComplete = ref.watch(isWeekCompleteProvider);
    if (isComplete) {
      final stats = ref.watch(weekReviewStatsProvider).value;
      final weightUnit = ref.watch(profileProvider).value?.weightUnit ?? 'kg';
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: WeekReviewSection(
          plan: plan,
          routineNames: nameMap,
          totalVolume: stats?.totalVolume ?? 0,
          prCount: stats?.prCount ?? 0,
          weightUnit: weightUnit,
          onNewWeek: () => _startNewWeek(context, ref),
        ),
      );
    }

    // Active week — show bucket section.
    return _ActiveBucketSection(
      plan: plan,
      routineMap: routineMap,
      nameMap: nameMap,
      needsConfirmation: needsConfirmation,
    );
  }

  void _startNewWeek(BuildContext context, WidgetRef ref) {
    context.push('/plan/week');
  }

  /// Selects the routine to recommend to a brand-new user.
  ///
  /// Prefers the default routine named "Full Body" (total-body beginner
  /// program seeded by `supabase/seed.sql`). Falls back to the first default
  /// routine by alphabetical name (deterministic across reloads) when Full
  /// Body is missing. Returns null when no default routines exist — caller
  /// should render nothing rather than show a broken card.
  static Routine? _pickBeginnerRoutine(List<Routine> routines) {
    final defaults = routines.where((r) => r.isDefault).toList();
    if (defaults.isEmpty) return null;
    for (final r in defaults) {
      if (r.name == 'Full Body') return r;
    }
    defaults.sort((a, b) => a.name.compareTo(b.name));
    return defaults.first;
  }
}

class _ActiveBucketSection extends ConsumerWidget {
  const _ActiveBucketSection({
    required this.plan,
    required this.routineMap,
    required this.nameMap,
    required this.needsConfirmation,
  });

  final WeeklyPlan plan;
  final Map<String, Routine> routineMap;
  final Map<String, String> nameMap;
  final bool needsConfirmation;

  static const _primaryGreen = Color(0xFF00E676);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final suggestedNext = ref.watch(suggestedNextProvider);
    final completedCount = ref.watch(completedCountProvider);
    final totalCount = ref.watch(totalBucketCountProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confirmation banner (auto-populated week).
          if (needsConfirmation) ...[
            _ConfirmBanner(
              onConfirm: () {
                ref.read(weeklyPlanNeedsConfirmationProvider.notifier).state =
                    false;
              },
              onEdit: () => context.push('/plan/week'),
            ),
            const SizedBox(height: 8),
          ],

          // Section header row: THIS WEEK + edit icon.
          Row(
            children: [
              Text(
                'THIS WEEK',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              // Edit plan link.
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                tooltip: 'Edit weekly plan',
                onPressed: () => context.push('/plan/week'),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          // Progress counter below title.
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$completedCount',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' of $totalCount',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Suggested-next card (between counter and chips).
          if (suggestedNext != null) ...[
            const SizedBox(height: 8),
            _SuggestedNextCard(
              routineName: nameMap[suggestedNext.routineId] ?? 'Next workout',
              onTap: () {
                final routine = routineMap[suggestedNext.routineId];
                if (routine != null) {
                  startRoutineWorkout(context, ref, routine);
                }
              },
            ),
            const SizedBox(height: 8),
          ],

          // Routine chips (horizontal scroll).
          GestureDetector(
            onLongPress: () => context.push('/plan/week'),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _buildChips(context, ref)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChips(BuildContext context, WidgetRef ref) {
    final suggestedNext = ref.read(suggestedNextProvider);

    final sortedRoutines = [...plan.routines]
      ..sort((a, b) => a.order.compareTo(b.order));

    return sortedRoutines.map((bucket) {
      final name = nameMap[bucket.routineId] ?? 'Routine';
      final isDone = bucket.completedWorkoutId != null;
      final isNext =
          suggestedNext != null &&
          bucket.routineId == suggestedNext.routineId &&
          !isDone;

      final chipState = isDone
          ? RoutineChipState.done
          : isNext
          ? RoutineChipState.next
          : RoutineChipState.remaining;

      // For the "next" chip, pass exercise count from routine data.
      final routine = routineMap[bucket.routineId];
      final exerciseCount = routine?.exercises.length;

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: RoutineChip(
          sequenceNumber: bucket.order,
          routineName: name,
          chipState: chipState,
          exerciseCount: isNext ? exerciseCount : null,
          onTap: isDone
              ? null
              : () {
                  if (routine != null) {
                    startRoutineWorkout(context, ref, routine);
                  }
                },
        ),
      );
    }).toList();
  }
}

class _SuggestedNextCard extends StatelessWidget {
  const _SuggestedNextCard({required this.routineName, required this.onTap});

  final String routineName;
  final VoidCallback onTap;

  static const _primaryGreen = Color(0xFF00E676);
  static const _cardColor = Color(0xFF232340);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: _cardColor,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusMd),
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusMd),
            border: const Border(
              left: BorderSide(color: _primaryGreen, width: 4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.play_arrow, color: _primaryGreen, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Up next',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    Text(
                      routineName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First-run CTA: a single recommended beginner workout with a one-tap entry
/// into an active workout. Shown instead of the "Plan your week" prompt when
/// the user has not yet logged any workouts and at least one default routine
/// is available.
///
/// Taller (80dp) than [_SuggestedNextCard] (56dp) because it is the primary
/// CTA for a brand-new user, and carries three lines of content: a label,
/// the routine name headline, and a short stats line.
class _BeginnerRoutineCta extends StatelessWidget {
  const _BeginnerRoutineCta({required this.routine, required this.onTap});

  final Routine routine;
  final VoidCallback onTap;

  static const _primaryGreen = Color(0xFF00E676);
  static const _cardColor = Color(0xFF232340);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    // Derive the duration estimate from the routine's set_configs so Push/Pull
    // Day, Leg Day, etc. show honest numbers — not just "~45 min" pinned to
    // Full Body. See `estimateRoutineDurationMinutes` for the heuristic.
    final durationMin = estimateRoutineDurationMinutes(routine);
    final stats =
        '${routine.exercises.length} exercises \u00B7 ~$durationMin min';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusMd),
          onTap: onTap,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadiusMd),
              border: const Border(
                left: BorderSide(color: _primaryGreen, width: 4),
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
                const Icon(Icons.play_arrow, color: _primaryGreen, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmBanner extends StatelessWidget {
  const _ConfirmBanner({required this.onConfirm, required this.onEdit});

  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  static const _primaryGreen = Color(0xFF00E676);
  static const _cardColor = Color(0xFF232340);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(
          color: _primaryGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Same plan this week?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Edit')),
          TextButton(onPressed: onConfirm, child: const Text('Confirm')),
        ],
      ),
    );
  }
}

/// Empty plan state — full-width bordered container at 72dp min-height
/// with centered text + icon.
class _EmptyBucketState extends StatelessWidget {
  const _EmptyBucketState({required this.hasRoutines});

  final bool hasRoutines;

  @override
  Widget build(BuildContext context) {
    if (!hasRoutines) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS WEEK',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => context.push('/plan/week'),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 72),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Plan your week',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
