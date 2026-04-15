import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routines/models/routine.dart';
import '../../../routines/providers/notifiers/routine_list_notifier.dart';
import '../../../routines/ui/start_routine_action.dart';
import '../../data/models/weekly_plan.dart';
import '../../providers/suggested_next_provider.dart';
import '../../providers/weekly_plan_provider.dart';
import 'routine_chip.dart';

/// Bucket chip row for the Home screen.
///
/// Per PLAN W8, the `THIS WEEK` label, progress counter, `Up next` card,
/// beginner CTA, empty state, week-complete review, and confirmation banner
/// have all been moved to sibling widgets (`HomeStatusLine`, `ActionHero`,
/// `_ConfirmBanner`, `_WeekReviewCard`). What remains here is a single
/// horizontal row of [RoutineChip]s reflecting bucket order/progress.
///
/// Rendering rules:
///
/// * Hidden (`SizedBox.shrink()`) when there is no active plan, the plan is
///   empty, the routine list is empty, or the week is complete.
/// * Long-pressing the row opens `/plan/week` to edit the plan.
/// * Tapping a non-done chip starts that routine's workout.
class WeekBucketSection extends ConsumerWidget {
  const WeekBucketSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(weeklyPlanProvider);
    final routinesAsync = ref.watch(routineListProvider);

    // Show previous data during reload instead of blank. Only hide on
    // initial load (no cached value) or error without cached value.
    if (planAsync.isLoading && !planAsync.hasValue) {
      return const SizedBox.shrink();
    }
    if (planAsync.hasError && !planAsync.hasValue) {
      return const SizedBox.shrink();
    }

    final plan = planAsync.value;
    final routines = routinesAsync.value ?? const <Routine>[];
    if (routines.isEmpty) return const SizedBox.shrink();
    if (plan == null || plan.routines.isEmpty) return const SizedBox.shrink();

    // Week-complete state is owned by HomeScreen's `_WeekReviewCard`. Render
    // nothing here so we don't duplicate the chip row under the review card.
    final isComplete = ref.watch(isWeekCompleteProvider);
    if (isComplete) return const SizedBox.shrink();

    final routineMap = <String, Routine>{for (final r in routines) r.id: r};
    final nameMap = <String, String>{for (final r in routines) r.id: r.name};

    return _ActiveBucketRow(
      plan: plan,
      routineMap: routineMap,
      nameMap: nameMap,
    );
  }
}

class _ActiveBucketRow extends ConsumerWidget {
  const _ActiveBucketRow({
    required this.plan,
    required this.routineMap,
    required this.nameMap,
  });

  final WeeklyPlan plan;
  final Map<String, Routine> routineMap;
  final Map<String, String> nameMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onLongPress: () => context.push('/plan/week'),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _buildChips(context, ref)),
        ),
      ),
    );
  }

  List<Widget> _buildChips(BuildContext context, WidgetRef ref) {
    final suggestedNext = ref.watch(suggestedNextProvider);

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
