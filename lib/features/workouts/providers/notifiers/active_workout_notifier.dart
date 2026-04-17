import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/device/platform_info.dart';
import '../../../../core/exceptions/app_exception.dart' as app;
import '../../../../core/offline/pending_action.dart';
import '../../../../core/offline/pending_sync_provider.dart';
import '../../../../core/observability/sentry_report.dart';
import '../../../analytics/data/models/analytics_event.dart';
import '../../../analytics/providers/analytics_providers.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../exercises/models/exercise.dart';
import '../../../exercises/providers/exercise_progress_provider.dart';
import '../../../personal_records/domain/pr_detection_service.dart';
import '../../../personal_records/providers/pr_providers.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../../weekly_plan/providers/weekly_plan_provider.dart';
import '../../data/workout_local_storage.dart';
import '../../data/workout_repository.dart';
import '../../models/active_workout_state.dart';
import '../../models/exercise_set.dart';
import '../../models/routine_start_config.dart';
import '../../models/set_type.dart';
import '../../models/weight_unit.dart';
import '../../models/workout_exercise.dart';
import '../../utils/set_defaults.dart';
import '../workout_providers.dart';

const _uuid = Uuid();

/// Core state machine for active workouts.
///
/// Manages the full lifecycle: start -> add exercises/sets -> finish or discard.
/// All mutations are persisted to Hive for crash recovery.
class ActiveWorkoutNotifier extends AsyncNotifier<ActiveWorkoutState?> {
  late WorkoutRepository _repo;
  late WorkoutLocalStorage _localStorage;

  /// Re-entrance guard for [finishWorkout]. Prevents concurrent saves when
  /// the user double-taps "Finish Workout".
  bool _isFinishing = false;

  /// Re-entrance guard for [discardWorkout]. Prevents concurrent discards
  /// when Android back-button spam triggers multiple calls.
  bool _isDiscarding = false;

  /// Set by [cancelLoading] so that in-flight [finishWorkout] and
  /// [discardWorkout] futures skip the final `state =` assignment when they
  /// complete. Without this, the guard result overwrites the state restored
  /// by [cancelLoading], causing the workout to vanish unexpectedly.
  bool _cancelRequested = false;

  /// Stores the last valid [AsyncData] state so that [cancelLoading] can
  /// restore it if the user gives up waiting for a network operation.
  ActiveWorkoutState? _lastValidState;

  @override
  FutureOr<ActiveWorkoutState?> build() {
    _repo = ref.watch(workoutRepositoryProvider);
    _localStorage = ref.watch(workoutLocalStorageProvider);
    return _localStorage.loadActiveWorkout();
  }

  /// Cancel an in-flight loading operation by restoring the last valid state.
  ///
  /// Used by the loading overlay's timeout cancel button. The underlying
  /// network request continues in the background, but the UI is unblocked
  /// so the user can retry or discard. Resets re-entrance guards so the
  /// user can try again.
  void cancelLoading() {
    _cancelRequested = true;
    _isFinishing = false;
    _isDiscarding = false;
    savedOffline = false;
    if (_lastValidState != null) {
      state = AsyncData(_lastValidState);
    }
  }

  String get _userId {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) {
      throw const app.AuthException('Not authenticated', code: 'no_session');
    }
    return user.id;
  }

  /// Count of sets that are not yet completed.
  int get incompleteSetsCount {
    final current = state.value;
    if (current == null) return 0;
    return current.exercises
        .expand((e) => e.sets)
        .where((s) => !s.isCompleted)
        .length;
  }

  /// Start a new workout session.
  ///
  /// If [name] is omitted a date-based name is generated automatically,
  /// e.g. "Workout — Wed Apr 2".
  Future<void> startWorkout([String? name]) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = _userId;
      final workout = await _repo.createActiveWorkout(
        userId: userId,
        name: name ?? _generateWorkoutName(),
      );
      final activeState = ActiveWorkoutState(
        workout: workout,
        exercises: const [],
      );
      await _saveToHive(activeState);
      _trackWorkoutEvent(
        event: const AnalyticsEvent.workoutStarted(
          source: 'empty',
          routineId: null,
          exerciseCount: 0,
        ),
        breadcrumbMessage: 'started empty workout',
        breadcrumbData: {'workout_id': workout.id},
      );
      return activeState;
    });
  }

  /// Start a workout pre-populated from a routine template.
  Future<void> startFromRoutine(RoutineStartConfig config) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = _userId;
      final workout = await _repo.createActiveWorkout(
        userId: userId,
        name: config.routineName,
      );

      // Fetch last-workout weights for pre-filling sets.
      final exerciseIds = config.exercises.map((e) => e.exerciseId).toList();
      final lastSets = await _repo.getLastWorkoutSets(exerciseIds);
      final weightUnitStr = ref.read(profileProvider).value?.weightUnit ?? 'kg';
      final weightUnit = WeightUnit.fromString(weightUnitStr);

      // Build exercises with pre-filled sets.
      final exercises = <ActiveWorkoutExercise>[];
      for (var i = 0; i < config.exercises.length; i++) {
        final re = config.exercises[i];
        final workoutExerciseId = _uuid.v4();

        final workoutExercise = WorkoutExercise(
          id: workoutExerciseId,
          workoutId: workout.id,
          exerciseId: re.exerciseId,
          order: i,
          restSeconds: re.restSeconds,
          exercise: re.exercise,
        );

        final previousSets = lastSets[re.exerciseId] ?? [];
        final equipDefaults = defaultSetValues(
          re.exercise.equipmentType,
          weightUnit,
        );
        final sets = List.generate(re.setCount, (setIndex) {
          // Use the matching previous set, or the last previous set if fewer.
          final prev = previousSets.isNotEmpty
              ? previousSets[setIndex < previousSets.length
                    ? setIndex
                    : previousSets.length - 1]
              : null;

          return ExerciseSet(
            id: _uuid.v4(),
            workoutExerciseId: workoutExerciseId,
            setNumber: setIndex + 1,
            weight: prev?.weight ?? equipDefaults.weight,
            reps: re.targetReps ?? prev?.reps ?? equipDefaults.reps,
            setType: SetType.working,
            isCompleted: false,
            createdAt: DateTime.now().toUtc(),
          );
        });

        exercises.add(
          ActiveWorkoutExercise(workoutExercise: workoutExercise, sets: sets),
        );
      }

      final activeState = ActiveWorkoutState(
        workout: workout,
        exercises: exercises,
        routineId: config.routineId,
      );
      await _saveToHive(activeState);
      // TODO post-PR: differentiate planned_bucket when config exposes the flag
      _trackWorkoutEvent(
        event: AnalyticsEvent.workoutStarted(
          source: 'routine_card',
          routineId: config.routineId,
          exerciseCount: config.exercises.length,
        ),
        breadcrumbMessage: 'started workout from routine',
        breadcrumbData: {
          'workout_id': workout.id,
          'routine_id': config.routineId,
        },
      );
      return activeState;
    });
  }

  /// Rename the active workout in-memory and persist to Hive.
  Future<void> renameWorkout(String name) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(workout: current.workout.copyWith(name: name)),
    );
    await _saveToHive(state.value!);
  }

  String _generateWorkoutName() {
    final now = DateTime.now();
    final weekday = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][now.weekday - 1];
    final month = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][now.month - 1];
    return 'Workout \u2014 $weekday $month ${now.day}';
  }

  /// Add an exercise to the active workout.
  Future<void> addExercise(Exercise exercise) async {
    final current = state.value;
    if (current == null) return;

    final workoutExercise = WorkoutExercise(
      id: _uuid.v4(),
      workoutId: current.workout.id,
      exerciseId: exercise.id,
      order: current.exercises.length,
      exercise: exercise,
    );

    final newState = current.copyWith(
      exercises: [
        ...current.exercises,
        ActiveWorkoutExercise(workoutExercise: workoutExercise, sets: const []),
      ],
    );
    state = AsyncData(newState);
    await _saveToHive(newState);
  }

  /// Remove an exercise and reorder remaining exercises.
  Future<void> removeExercise(String workoutExerciseId) async {
    final current = state.value;
    if (current == null) return;

    final filtered = current.exercises
        .where((e) => e.workoutExercise.id != workoutExerciseId)
        .toList();

    // Reorder remaining exercises.
    final reordered = filtered.indexed
        .map(
          (entry) => entry.$2.copyWith(
            workoutExercise: entry.$2.workoutExercise.copyWith(order: entry.$1),
          ),
        )
        .toList();

    final newState = current.copyWith(exercises: reordered);
    state = AsyncData(newState);
    await _saveToHive(newState);
  }

  /// Add a new empty set to an exercise.
  ///
  /// Optional [defaultWeight] and [defaultReps] pre-fill the new set
  /// (e.g. from the previous workout session).
  Future<void> addSet(
    String workoutExerciseId, {
    double? defaultWeight,
    int? defaultReps,
  }) async {
    final current = state.value;
    if (current == null) return;

    final newState = current.copyWith(
      exercises: current.exercises.map((e) {
        if (e.workoutExercise.id != workoutExerciseId) return e;

        final newSet = ExerciseSet(
          id: _uuid.v4(),
          workoutExerciseId: workoutExerciseId,
          setNumber: e.sets.length + 1,
          weight: defaultWeight ?? 0,
          reps: defaultReps ?? 0,
          setType: SetType.working,
          isCompleted: false,
          createdAt: DateTime.now().toUtc(),
        );

        return e.copyWith(sets: [...e.sets, newSet]);
      }).toList(),
    );
    state = AsyncData(newState);
    await _saveToHive(newState);
  }

  /// Update fields on a specific set.
  Future<void> updateSet(
    String workoutExerciseId,
    String setId, {
    double? weight,
    int? reps,
    int? rpe,
    SetType? setType,
    String? notes,
  }) async {
    final current = state.value;
    if (current == null) return;

    final newState = current.copyWith(
      exercises: current.exercises.map((e) {
        if (e.workoutExercise.id != workoutExerciseId) return e;

        return e.copyWith(
          sets: e.sets.map((s) {
            if (s.id != setId) return s;
            return s.copyWith(
              weight: weight ?? s.weight,
              reps: reps ?? s.reps,
              rpe: rpe ?? s.rpe,
              setType: setType ?? s.setType,
              notes: notes ?? s.notes,
            );
          }).toList(),
        );
      }).toList(),
    );
    state = AsyncData(newState);
    await _saveToHive(newState);
  }

  /// Toggle the completion status of a set.
  Future<void> completeSet(String workoutExerciseId, String setId) async {
    final current = state.value;
    if (current == null) return;

    final newState = current.copyWith(
      exercises: current.exercises.map((e) {
        if (e.workoutExercise.id != workoutExerciseId) return e;

        return e.copyWith(
          sets: e.sets.map((s) {
            if (s.id != setId) return s;
            return s.copyWith(isCompleted: !s.isCompleted);
          }).toList(),
        );
      }).toList(),
    );
    state = AsyncData(newState);
    await _saveToHive(newState);
  }

  /// Delete a set and renumber the remaining sets.
  Future<void> deleteSet(String workoutExerciseId, String setId) async {
    final current = state.value;
    if (current == null) return;

    final newState = current.copyWith(
      exercises: current.exercises.map((e) {
        if (e.workoutExercise.id != workoutExerciseId) return e;

        final filtered = e.sets.where((s) => s.id != setId).toList();
        final renumbered = filtered.indexed
            .map((entry) => entry.$2.copyWith(setNumber: entry.$1 + 1))
            .toList();

        return e.copyWith(sets: renumbered);
      }).toList(),
    );
    state = AsyncData(newState);
    await _saveToHive(newState);
  }

  /// Restore a previously deleted set at its original position.
  ///
  /// Inserts the [deletedSet] back into the exercise's set list and
  /// renumbers all sets sequentially. Used for undo-delete functionality.
  Future<void> restoreSet(
    String workoutExerciseId,
    ExerciseSet deletedSet,
  ) async {
    final current = state.value;
    if (current == null) return;

    final newState = current.copyWith(
      exercises: current.exercises.map((e) {
        if (e.workoutExercise.id != workoutExerciseId) return e;

        final sets = [...e.sets];
        // Insert at the original position (clamped to list bounds).
        final insertIndex = (deletedSet.setNumber - 1).clamp(0, sets.length);
        sets.insert(insertIndex, deletedSet);

        // Renumber all sets sequentially.
        final renumbered = sets.indexed
            .map((entry) => entry.$2.copyWith(setNumber: entry.$1 + 1))
            .toList();

        return e.copyWith(sets: renumbered);
      }).toList(),
    );
    state = AsyncData(newState);
    await _saveToHive(newState);
  }

  /// Copy weight and reps from the previous set into the given set.
  Future<void> copyLastSet(String workoutExerciseId, String setId) async {
    final current = state.value;
    if (current == null) return;

    final newState = current.copyWith(
      exercises: current.exercises.map((e) {
        if (e.workoutExercise.id != workoutExerciseId) return e;

        final targetIndex = e.sets.indexWhere((s) => s.id == setId);
        if (targetIndex <= 0) return e; // no previous set or not found

        final previous = e.sets[targetIndex - 1];
        final updated = e.sets[targetIndex].copyWith(
          weight: previous.weight,
          reps: previous.reps,
        );

        return e.copyWith(
          sets: [
            ...e.sets.sublist(0, targetIndex),
            updated,
            ...e.sets.sublist(targetIndex + 1),
          ],
        );
      }).toList(),
    );
    state = AsyncData(newState);
    await _saveToHive(newState);
  }

  /// Fill all incomplete sets after the last completed set with its values.
  Future<void> fillRemainingSets(String workoutExerciseId) async {
    final current = state.value;
    if (current == null) return;

    final newState = current.copyWith(
      exercises: current.exercises.map((e) {
        if (e.workoutExercise.id != workoutExerciseId) return e;

        // Find the last completed set (highest setNumber).
        ExerciseSet? lastCompleted;
        for (final s in e.sets) {
          if (s.isCompleted) {
            if (lastCompleted == null ||
                s.setNumber > lastCompleted.setNumber) {
              lastCompleted = s;
            }
          }
        }
        if (lastCompleted == null) return e;

        return e.copyWith(
          sets: e.sets.map((s) {
            if (!s.isCompleted && s.setNumber > lastCompleted!.setNumber) {
              return s.copyWith(
                weight: lastCompleted.weight,
                reps: lastCompleted.reps,
                isCompleted: true,
              );
            }
            return s;
          }).toList(),
        );
      }).toList(),
    );
    state = AsyncData(newState);
    await _saveToHive(newState);
  }

  /// Reorder an exercise by swapping it with its neighbour.
  ///
  /// [direction] must be -1 (move up) or +1 (move down).
  Future<void> reorderExercise(String workoutExerciseId, int direction) async {
    assert(direction == -1 || direction == 1, 'direction must be -1 or 1');
    final current = state.value;
    if (current == null) return;

    final exercises = [...current.exercises];
    final index = exercises.indexWhere(
      (e) => e.workoutExercise.id == workoutExerciseId,
    );
    if (index < 0) return;

    final targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= exercises.length) return;

    // Swap order fields.
    final a = exercises[index];
    final b = exercises[targetIndex];
    exercises[index] = b.copyWith(
      workoutExercise: b.workoutExercise.copyWith(order: index),
    );
    exercises[targetIndex] = a.copyWith(
      workoutExercise: a.workoutExercise.copyWith(order: targetIndex),
    );

    final newState = current.copyWith(exercises: exercises);
    state = AsyncData(newState);
    await _saveToHive(newState);
  }

  /// Replace the exercise on a [WorkoutExercise] while keeping all sets.
  Future<void> swapExercise(
    String workoutExerciseId,
    Exercise newExercise,
  ) async {
    final current = state.value;
    if (current == null) return;

    final newState = current.copyWith(
      exercises: current.exercises.map((e) {
        if (e.workoutExercise.id != workoutExerciseId) return e;

        return e.copyWith(
          workoutExercise: e.workoutExercise.copyWith(
            exerciseId: newExercise.id,
            exercise: newExercise,
          ),
        );
      }).toList(),
    );
    state = AsyncData(newState);
    await _saveToHive(newState);
  }

  /// Discard the active workout (deletes from server and clears local state).
  Future<void> discardWorkout() async {
    final current = state.value;
    if (current == null) return;
    if (_isDiscarding) return;
    _isDiscarding = true;
    _lastValidState = current;
    _cancelRequested = false;

    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await _localStorage.clearActiveWorkout();
      await _repo.discardWorkout(current.workout.id, userId: _userId);

      final elapsedSeconds = DateTime.now()
          .toUtc()
          .difference(current.workout.startedAt)
          .inSeconds;
      final completedSets = current.exercises
          .expand((e) => e.sets)
          .where((s) => s.isCompleted)
          .length;
      // TODO post-PR: differentiate planned_bucket when config exposes the flag
      final source = current.routineId != null ? 'routine_card' : 'empty';
      _trackWorkoutEvent(
        event: AnalyticsEvent.workoutDiscarded(
          elapsedSeconds: elapsedSeconds,
          completedSets: completedSets,
          exerciseCount: current.exercises.length,
          source: source,
        ),
        breadcrumbMessage: 'discarded workout',
        breadcrumbData: {'workout_id': current.workout.id},
      );
      return null;
    });

    if (_cancelRequested) {
      _cancelRequested = false;
      _isDiscarding = false;
      return;
    }

    state = result;
    _isDiscarding = false;
  }

  /// Whether the last [finishWorkout] call saved the workout to the offline
  /// queue rather than syncing it to the server. UI reads this to show the
  /// "Will sync when back online" banner on the finish screen.
  bool savedOffline = false;

  /// Finish the active workout, save to server, detect PRs, and return results.
  ///
  /// When the network save fails, the workout is enqueued for offline sync
  /// and a locally-constructed [Workout] is used for downstream PR detection
  /// and weekly-plan updates. The [savedOffline] flag is set so the UI can
  /// display an appropriate message.
  Future<PRDetectionResult?> finishWorkout({String? notes}) async {
    final current = state.value;
    if (current == null) return null;
    if (_isFinishing) return null;
    _isFinishing = true;
    _lastValidState = current;
    _cancelRequested = false;
    savedOffline = false;

    // Capture workout data BEFORE setting loading state.
    final exercises = current.exercises;
    final exerciseIds = exercises
        .map((e) => e.workoutExercise.exerciseId)
        .toSet()
        .toList();

    state = const AsyncLoading();

    PRDetectionResult? prResult;
    // Hoisted so the analytics event can still report a number (0) when PR
    // detection throws before the count is fetched.
    int workoutCount = 0;

    final result = await AsyncValue.guard(() async {
      final now = DateTime.now().toUtc();
      final durationSeconds = now
          .difference(current.workout.startedAt)
          .inSeconds;

      final workout = current.workout.copyWith(
        finishedAt: now,
        durationSeconds: durationSeconds,
        isActive: false,
        notes: notes,
      );

      final workoutExercises = exercises.map((e) => e.workoutExercise).toList();
      final sets = exercises.expand((e) => e.sets).toList();

      // --- Save workout (online or offline queue) ---
      try {
        await _repo.saveWorkout(
          workout: workout,
          exercises: workoutExercises,
          sets: sets,
        );
      } catch (e) {
        log(
          'Network save failed, queueing offline: $e',
          name: 'ActiveWorkoutNotifier',
          level: 900,
        );
        savedOffline = true;

        // Build raw JSON maps matching the RPC shape.
        // Include all required Workout fields so Workout.fromJson succeeds
        // when retrying from the queue.
        final workoutJson = <String, dynamic>{
          'id': workout.id,
          'user_id': workout.userId,
          'name': workout.name,
          'started_at': workout.startedAt.toIso8601String(),
          'finished_at': workout.finishedAt?.toIso8601String(),
          'duration_seconds': workout.durationSeconds,
          'is_active': false,
          'notes': workout.notes,
          'created_at': workout.createdAt.toIso8601String(),
        };
        final exercisesJson = workoutExercises
            .map(
              (e) => <String, dynamic>{
                'id': e.id,
                'workout_id': e.workoutId,
                'exercise_id': e.exerciseId,
                'order': e.order,
                'rest_seconds': e.restSeconds,
              },
            )
            .toList();
        final setsJson = sets
            .map(
              (s) => <String, dynamic>{
                'id': s.id,
                'workout_exercise_id': s.workoutExerciseId,
                'set_number': s.setNumber,
                'reps': s.reps,
                'weight': s.weight,
                'rpe': s.rpe,
                'set_type': s.setType.name,
                'notes': s.notes,
                'is_completed': s.isCompleted,
              },
            )
            .toList();

        await ref
            .read(pendingSyncProvider.notifier)
            .enqueue(
              PendingAction.saveWorkout(
                id: workout.id,
                workoutJson: workoutJson,
                exercisesJson: exercisesJson,
                setsJson: setsJson,
                userId: workout.userId,
                queuedAt: now,
              ),
            );

        _repo.incrementCachedWorkoutCount(workout.userId);
        _repo.evictHistoryCaches(workout.userId);

        _trackWorkoutEvent(
          event: const AnalyticsEvent.workoutSyncQueued(
            actionType: 'save_workout',
          ),
          breadcrumbMessage: 'workout queued for offline sync',
          breadcrumbData: {'workout_id': workout.id},
        );
      }

      // Invalidate the per-exercise progress chart family so any exercise
      // whose detail sheet is re-opened this session reflects the newly
      // saved sets. Invalidating the whole family is correct — a finished
      // workout may touch any exercise, and the family is small per user.
      if (!savedOffline) {
        ref.invalidate(exerciseProgressProvider);
      }

      // PR detection: batch-fetch existing records, then detect new ones.
      // When offline, getRecordsForExercises falls back to pr_cache (14a).
      try {
        final prRepo = ref.read(prRepositoryProvider);
        final prService = ref.read(prDetectionServiceProvider);

        final existingRecords = await prRepo.getRecordsForExercises(
          exerciseIds,
        );

        // Fetch total finished workout count for accurate first-workout detection.
        if (savedOffline) {
          workoutCount = _repo.getCachedWorkoutCount(_userId) ?? 1;
        } else {
          try {
            workoutCount = await _repo.getFinishedWorkoutCount(_userId);
          } catch (_) {
            workoutCount = _repo.getCachedWorkoutCount(_userId) ?? 1;
          }
        }

        prResult = prService.detectPRs(
          userId: _userId,
          exercises: exercises,
          existingRecords: existingRecords,
          totalFinishedWorkouts: workoutCount,
        );

        if (prResult!.hasNewRecords) {
          try {
            await prRepo.upsertRecords(prResult!.newRecords);
          } catch (e) {
            log(
              'PR record save failed, queueing offline: $e',
              name: 'ActiveWorkoutNotifier',
              level: 900,
            );
            // Queue upsert for later sync.
            await ref
                .read(pendingSyncProvider.notifier)
                .enqueue(
                  PendingAction.upsertRecords(
                    id: _uuid.v4(),
                    recordsJson: prResult!.newRecords
                        .map((r) => r.toJson())
                        .toList(),
                    queuedAt: now,
                  ),
                );
            // prResult is still set — user sees celebration even if save failed.
          }
        }
      } catch (e) {
        // PR detection failure should NOT fail the workout save.
        log(
          'PR detection failed: $e',
          name: 'ActiveWorkoutNotifier',
          level: 900,
        );
      }

      // Weekly plan: mark matching bucket routine as complete.
      try {
        final matchedRoutineId = current.routineId;
        if (matchedRoutineId != null) {
          final plan = ref.read(weeklyPlanProvider).value;
          if (plan != null && plan.routines.isNotEmpty) {
            final hasBucketMatch = plan.routines.any(
              (r) =>
                  r.routineId == matchedRoutineId &&
                  r.completedWorkoutId == null,
            );
            if (hasBucketMatch) {
              try {
                await ref
                    .read(weeklyPlanProvider.notifier)
                    .markRoutineComplete(
                      routineId: matchedRoutineId,
                      workoutId: workout.id,
                    );
              } catch (e) {
                log(
                  'Weekly plan update failed, queueing offline: $e',
                  name: 'ActiveWorkoutNotifier',
                  level: 900,
                );
                await ref
                    .read(pendingSyncProvider.notifier)
                    .enqueue(
                      PendingAction.markRoutineComplete(
                        id: _uuid.v4(),
                        planId: plan.id,
                        routineId: matchedRoutineId,
                        workoutId: workout.id,
                        queuedAt: now,
                      ),
                    );
              }
            }
          }
        }
      } catch (e) {
        // Weekly plan update failure should NOT fail the workout save.
        log(
          'Weekly plan update failed: $e',
          name: 'ActiveWorkoutNotifier',
          level: 900,
        );
      }

      final totalSets = sets.length;
      final completedSetsCount = sets.where((s) => s.isCompleted).length;
      final incompleteSetsSkipped = totalSets - completedSetsCount;
      final hadPr = prResult?.newRecords.isNotEmpty ?? false;
      // TODO post-PR: differentiate planned_bucket when config exposes the flag
      final source = current.routineId != null ? 'routine_card' : 'empty';
      _trackWorkoutEvent(
        event: AnalyticsEvent.workoutFinished(
          durationSeconds: durationSeconds,
          exerciseCount: exercises.length,
          totalSets: totalSets,
          completedSets: completedSetsCount,
          incompleteSetsSkipped: incompleteSetsSkipped,
          hadPr: hadPr,
          source: source,
          workoutNumber: workoutCount,
        ),
        breadcrumbMessage: 'finished workout',
        breadcrumbData: {
          'workout_id': workout.id,
          'workout_number': workoutCount,
          'had_pr': hadPr,
        },
      );

      await _localStorage.clearActiveWorkout();
      return null;
    });

    if (_cancelRequested) {
      // User tapped Cancel while we were saving. cancelLoading() already
      // restored the previous state — discard this guard result so we don't
      // overwrite it.
      _cancelRequested = false;
      _isFinishing = false;
      return null;
    }

    state = result;
    _isFinishing = false;

    return prResult;
  }

  /// Persist the current state to Hive.
  ///
  /// Awaited so IndexedDB (web) flushes before the next state update,
  /// preventing data loss on page reload.
  Future<void> _saveToHive(ActiveWorkoutState activeState) async {
    try {
      await _localStorage.saveActiveWorkout(activeState);
    } catch (e) {
      log(
        'Failed to persist workout to Hive: $e',
        name: 'ActiveWorkoutNotifier',
        level: 900,
      );
    }
  }

  /// Fire-and-forget insert of a product analytics event plus a matching
  /// Sentry breadcrumb.
  ///
  /// Throws [app.AuthException] via the [_userId] getter if the user is not
  /// authenticated. Safe today because every call site runs inside
  /// `AsyncValue.guard` (which captures the exception into `AsyncError`) and
  /// is only reached after a workout has been started — which itself requires
  /// authentication. Do NOT call this from any code path that might run
  /// without an active session, or wrap the call in a try/catch.
  ///
  /// The underlying [AnalyticsRepository.insertEvent] swallows all errors
  /// itself, so there is nothing to await and nothing to handle here beyond
  /// the `_userId` read.
  void _trackWorkoutEvent({
    required AnalyticsEvent event,
    required String breadcrumbMessage,
    Map<String, Object?>? breadcrumbData,
  }) {
    final analyticsRepo = ref.read(analyticsRepositoryProvider);
    unawaited(
      analyticsRepo.insertEvent(
        userId: _userId,
        event: event,
        platform: currentPlatform(),
        appVersion: currentAppVersion(),
      ),
    );
    SentryReport.addBreadcrumb(
      category: 'workout',
      message: breadcrumbMessage,
      data: breadcrumbData,
    );
  }
}

final activeWorkoutProvider =
    AsyncNotifierProvider<ActiveWorkoutNotifier, ActiveWorkoutState?>(
      ActiveWorkoutNotifier.new,
    );
