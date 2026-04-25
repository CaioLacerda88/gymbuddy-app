import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_provider.dart';
import '../../personal_records/data/pr_repository.dart';
import '../../personal_records/providers/pr_providers.dart';
import '../../workouts/data/workout_repository.dart';
import '../../workouts/providers/workout_providers.dart';
import 'weekly_plan_provider.dart';

/// Computed stats for the week review section.
///
/// Fetches workout details for completed bucket routines and sums total volume
/// (weight * reps across all completed sets). Also counts PRs whose set_id
/// belongs to any of the completed workouts.
class WeekReviewStats {
  const WeekReviewStats({this.totalVolume = 0, this.prCount = 0});

  final double totalVolume;
  final int prCount;
}

/// Provider that computes week review stats from completed workouts.
///
/// Only produces meaningful data when the plan has completed routines.
/// Returns default zeros while loading or if no plan exists.
final weekReviewStatsProvider = FutureProvider<WeekReviewStats>((ref) async {
  final plan = ref.watch(weeklyPlanProvider).value;
  if (plan == null || plan.routines.isEmpty) {
    return const WeekReviewStats();
  }

  final completedIds = plan.routines
      .where((r) => r.completedWorkoutId != null)
      .map((r) => r.completedWorkoutId!)
      .toList();

  if (completedIds.isEmpty) return const WeekReviewStats();

  final workoutRepo = ref.read(workoutRepositoryProvider);
  final prRepo = ref.read(prRepositoryProvider);
  final userId = plan.userId;
  final locale = ref.watch(localeProvider).languageCode;

  // Fetch volume and PR count in parallel.
  final results = await Future.wait([
    _computeTotalVolume(workoutRepo, completedIds, userId, locale),
    _countPRsForWorkouts(prRepo, completedIds, userId),
  ]);

  return WeekReviewStats(
    totalVolume: results[0] as double,
    prCount: results[1] as int,
  );
});

/// Sum of (weight * reps) across all completed sets in the given workouts.
Future<double> _computeTotalVolume(
  WorkoutRepository workoutRepo,
  List<String> workoutIds,
  String userId,
  String locale,
) async {
  var total = 0.0;
  for (final workoutId in workoutIds) {
    try {
      final detail = await workoutRepo.getWorkoutDetail(
        workoutId,
        userId: userId,
        locale: locale,
      );
      for (final sets in detail.setsByExercise.values) {
        for (final s in sets) {
          if (s.isCompleted) {
            total += (s.weight ?? 0) * (s.reps ?? 0);
          }
        }
      }
    } catch (_) {
      // Skip workouts that fail to load (e.g. deleted).
    }
  }
  return total;
}

/// Count PRs whose set_id belongs to any of the completed workouts.
Future<int> _countPRsForWorkouts(
  PRRepository prRepo,
  List<String> workoutIds,
  String userId,
) async {
  var count = 0;
  for (final workoutId in workoutIds) {
    try {
      final prs = await prRepo.getPRsForWorkout(workoutId, userId);
      count += prs.length;
    } catch (_) {
      // Skip workouts that fail to load.
    }
  }
  return count;
}
