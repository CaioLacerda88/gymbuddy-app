import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/personal_records/models/personal_record.dart';
import '../../features/personal_records/providers/pr_providers.dart';
import '../../features/weekly_plan/providers/weekly_plan_provider.dart';
import '../../features/workouts/models/exercise_set.dart';
import '../../features/workouts/models/workout.dart';
import '../../features/workouts/models/workout_exercise.dart';
import '../../features/workouts/providers/workout_providers.dart';
import 'offline_queue_service.dart';
import 'pending_action.dart';

/// Exposes the pending-sync queue count as reactive state.
///
/// UI widgets (badge, sheet) watch this provider to react to queue changes.
/// Mutations go through the notifier methods so the count auto-updates.
class PendingSyncNotifier extends Notifier<int> {
  late OfflineQueueService _queue;

  @override
  int build() {
    _queue = ref.watch(offlineQueueServiceProvider);
    return _queue.pendingCount;
  }

  /// Add an action to the offline queue and update the badge count.
  Future<void> enqueue(PendingAction action) async {
    await _queue.enqueue(action);
    state = _queue.pendingCount;
  }

  /// List all pending actions (sorted by queuedAt).
  List<PendingAction> getAll() => _queue.getAll();

  /// Retry a single queued item by executing the appropriate repo call.
  ///
  /// On success: dequeues the item and decrements the count.
  /// On failure: increments retryCount, stores the error, and rethrows.
  Future<void> retryItem(String id) async {
    final actions = _queue.getAll();
    final action = actions.where((a) => a.id == id).firstOrNull;
    if (action == null) return;

    try {
      await _executeAction(action);
      await _queue.dequeue(id);
      state = _queue.pendingCount;
    } catch (e) {
      log(
        'Retry failed for action $id: $e',
        name: 'PendingSyncNotifier',
        level: 900,
      );
      final updated = _withRetry(action, e.toString());
      await _queue.updateAction(updated);
      state = _queue.pendingCount;
      rethrow;
    }
  }

  /// Execute a pending action against the appropriate repository.
  Future<void> _executeAction(PendingAction action) async {
    switch (action) {
      case PendingSaveWorkout(
        :final workoutJson,
        :final exercisesJson,
        :final setsJson,
      ):
        final repo = ref.read(workoutRepositoryProvider);
        await repo.saveWorkout(
          workout: Workout.fromJson(workoutJson),
          exercises: exercisesJson.map(WorkoutExercise.fromJson).toList(),
          sets: setsJson.map(ExerciseSet.fromJson).toList(),
        );

      case PendingUpsertRecords(:final recordsJson):
        final repo = ref.read(prRepositoryProvider);
        await repo.upsertRecords(
          recordsJson.map(PersonalRecord.fromJson).toList(),
        );

      case PendingMarkRoutineComplete(
        :final planId,
        :final routineId,
        :final workoutId,
      ):
        final plan = ref.read(weeklyPlanProvider).value;
        if (plan != null && plan.id == planId) {
          await ref
              .read(weeklyPlanProvider.notifier)
              .markRoutineComplete(routineId: routineId, workoutId: workoutId);
        } else {
          log(
            'Skipping stale markRoutineComplete: plan $planId no longer current',
            name: 'PendingSyncNotifier',
          );
        }
    }
  }

  /// Create an updated copy of [action] with incremented retryCount and error.
  PendingAction _withRetry(PendingAction action, String error) {
    return switch (action) {
      PendingSaveWorkout() => action.copyWith(
        retryCount: action.retryCount + 1,
        lastError: error,
      ),
      PendingUpsertRecords() => action.copyWith(
        retryCount: action.retryCount + 1,
        lastError: error,
      ),
      PendingMarkRoutineComplete() => action.copyWith(
        retryCount: action.retryCount + 1,
        lastError: error,
      ),
    };
  }
}

/// Provides the pending-sync queue count (int) as reactive state.
final pendingSyncProvider = NotifierProvider<PendingSyncNotifier, int>(
  PendingSyncNotifier.new,
);
