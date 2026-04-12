import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/weekly_plan.dart';
import 'weekly_plan_provider.dart';

/// Computes the "up next" routine — the lowest-order uncompleted bucket entry.
///
/// Returns null if all routines are complete or no plan exists.
final suggestedNextProvider = Provider<BucketRoutine?>((ref) {
  final plan = ref.watch(weeklyPlanProvider).value;
  if (plan == null || plan.routines.isEmpty) return null;

  final uncompleted =
      plan.routines.where((r) => r.completedWorkoutId == null).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  return uncompleted.isEmpty ? null : uncompleted.first;
});

/// Whether all bucket routines are complete for the current week.
final isWeekCompleteProvider = Provider<bool>((ref) {
  final plan = ref.watch(weeklyPlanProvider).value;
  if (plan == null || plan.routines.isEmpty) return false;
  return plan.routines.every((r) => r.completedWorkoutId != null);
});

/// Count of completed routines in the current week's plan.
final completedCountProvider = Provider<int>((ref) {
  final plan = ref.watch(weeklyPlanProvider).value;
  if (plan == null) return 0;
  return plan.routines.where((r) => r.completedWorkoutId != null).length;
});

/// Total routines in the current week's plan.
final totalBucketCountProvider = Provider<int>((ref) {
  final plan = ref.watch(weeklyPlanProvider).value;
  if (plan == null) return 0;
  return plan.routines.length;
});
