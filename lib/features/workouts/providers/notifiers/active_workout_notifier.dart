import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/device/platform_info.dart';
import '../../../../core/exceptions/app_exception.dart' as app;
import '../../../../core/observability/sentry_report.dart';
import '../../../analytics/data/models/analytics_event.dart';
import '../../../analytics/providers/analytics_providers.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../exercises/models/exercise.dart';
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

  @override
  FutureOr<ActiveWorkoutState?> build() {
    _repo = ref.watch(workoutRepositoryProvider);
    _localStorage = ref.watch(workoutLocalStorageProvider);
    return _localStorage.loadActiveWorkout();
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
      _saveToHive(activeState);
      _trackWorkoutEvent(
        event: const AnalyticsEvent.workoutStarted(
          source: 'empty',
          routineId: null,
          exerciseCount: 0,
          hadActiveWorkoutConflict: false,
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
      final weightUnitStr =
          ref.read(profileProvider).valueOrNull?.weightUnit ?? 'kg';
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
      _saveToHive(activeState);
      // TODO post-PR: differentiate planned_bucket when config exposes the flag
      _trackWorkoutEvent(
        event: AnalyticsEvent.workoutStarted(
          source: 'routine_card',
          routineId: config.routineId,
          exerciseCount: config.exercises.length,
          hadActiveWorkoutConflict: false,
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
  void renameWorkout(String name) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(workout: current.workout.copyWith(name: name)),
    );
    _saveToHive(state.valueOrNull!);
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
  void addExercise(Exercise exercise) {
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
    _saveToHive(newState);
  }

  /// Remove an exercise and reorder remaining exercises.
  void removeExercise(String workoutExerciseId) {
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
    _saveToHive(newState);
  }

  /// Add a new empty set to an exercise.
  ///
  /// Optional [defaultWeight] and [defaultReps] pre-fill the new set
  /// (e.g. from the previous workout session).
  void addSet(
    String workoutExerciseId, {
    double? defaultWeight,
    int? defaultReps,
  }) {
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
    _saveToHive(newState);
  }

  /// Update fields on a specific set.
  void updateSet(
    String workoutExerciseId,
    String setId, {
    double? weight,
    int? reps,
    int? rpe,
    SetType? setType,
    String? notes,
  }) {
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
    _saveToHive(newState);
  }

  /// Toggle the completion status of a set.
  void completeSet(String workoutExerciseId, String setId) {
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
    _saveToHive(newState);
  }

  /// Delete a set and renumber the remaining sets.
  void deleteSet(String workoutExerciseId, String setId) {
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
    _saveToHive(newState);
  }

  /// Restore a previously deleted set at its original position.
  ///
  /// Inserts the [deletedSet] back into the exercise's set list and
  /// renumbers all sets sequentially. Used for undo-delete functionality.
  void restoreSet(String workoutExerciseId, ExerciseSet deletedSet) {
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
    _saveToHive(newState);
  }

  /// Copy weight and reps from the previous set into the given set.
  void copyLastSet(String workoutExerciseId, String setId) {
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
    _saveToHive(newState);
  }

  /// Fill all incomplete sets after the last completed set with its values.
  void fillRemainingSets(String workoutExerciseId) {
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
    _saveToHive(newState);
  }

  /// Reorder an exercise by swapping it with its neighbour.
  ///
  /// [direction] must be -1 (move up) or +1 (move down).
  void reorderExercise(String workoutExerciseId, int direction) {
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
    _saveToHive(newState);
  }

  /// Replace the exercise on a [WorkoutExercise] while keeping all sets.
  void swapExercise(String workoutExerciseId, Exercise newExercise) {
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
    _saveToHive(newState);
  }

  /// Discard the active workout (deletes from server and clears local state).
  Future<void> discardWorkout() async {
    final current = state.value;
    if (current == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
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
  }

  /// Finish the active workout, save to server, detect PRs, and return results.
  Future<PRDetectionResult?> finishWorkout({String? notes}) async {
    final current = state.value;
    if (current == null) return null;

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

    state = await AsyncValue.guard(() async {
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

      await _repo.saveWorkout(
        workout: workout,
        exercises: workoutExercises,
        sets: sets,
      );

      // PR detection: batch-fetch existing records, then detect new ones.
      try {
        final prRepo = ref.read(prRepositoryProvider);
        final prService = ref.read(prDetectionServiceProvider);

        final existingRecords = await prRepo.getRecordsForExercises(
          exerciseIds,
        );

        // Fetch total finished workout count for accurate first-workout detection.
        // The current workout is already saved at this point, so count >= 1.
        workoutCount = await _repo.getFinishedWorkoutCount(_userId);

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
              'PR record save failed: $e',
              name: 'ActiveWorkoutNotifier',
              level: 900,
            );
            // prResult is still set — user sees celebration even if save failed.
            // Records will be re-detected on next workout finish.
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
          final plan = ref.read(weeklyPlanProvider).valueOrNull;
          if (plan != null && plan.routines.isNotEmpty) {
            final hasBucketMatch = plan.routines.any(
              (r) =>
                  r.routineId == matchedRoutineId &&
                  r.completedWorkoutId == null,
            );
            if (hasBucketMatch) {
              await ref
                  .read(weeklyPlanProvider.notifier)
                  .markRoutineComplete(
                    routineId: matchedRoutineId,
                    workoutId: workout.id,
                  );
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

    return prResult;
  }

  /// Persist the current state to Hive (fire-and-forget).
  void _saveToHive(ActiveWorkoutState activeState) {
    unawaited(
      _localStorage.saveActiveWorkout(activeState).catchError((Object e) {
        log(
          'Failed to persist workout to Hive: $e',
          name: 'ActiveWorkoutNotifier',
          level: 900,
        );
      }),
    );
  }

  /// Fire-and-forget insert of a product analytics event plus a matching
  /// Sentry breadcrumb.
  ///
  /// Only called from workout lifecycle methods where the user is already
  /// authenticated (a workout is active), so `_userId` is safe to access.
  /// The underlying [AnalyticsRepository.insertEvent] swallows all errors.
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
