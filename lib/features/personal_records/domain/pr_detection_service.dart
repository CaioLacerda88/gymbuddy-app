import 'package:uuid/uuid.dart';

import '../../exercises/models/exercise.dart';
import '../../workouts/models/active_workout_state.dart';
import '../../workouts/models/exercise_set.dart';
import '../../workouts/models/set_type.dart';
import '../models/personal_record.dart';
import '../models/record_type.dart';

const _uuid = Uuid();

class PRDetectionResult {
  const PRDetectionResult({
    required this.newRecords,
    required this.isFirstWorkout,
  });

  final List<PersonalRecord> newRecords;
  final bool isFirstWorkout;

  bool get hasNewRecords => newRecords.isNotEmpty;
}

class PRDetectionService {
  /// Detect new personal records from a finished workout.
  ///
  /// [exercises] — the workout exercises with their sets and Exercise model.
  /// [existingRecords] — current PRs keyed by exerciseId (from batch fetch).
  /// [totalFinishedWorkouts] — total number of finished workouts for the user.
  ///   When provided, used for accurate first-workout detection. A value of 1
  ///   means the just-finished workout is the user's only completed workout.
  ///
  /// Returns [PRDetectionResult] with new records to upsert and first-workout flag.
  PRDetectionResult detectPRs({
    required String userId,
    required List<ActiveWorkoutExercise> exercises,
    required Map<String, List<PersonalRecord>> existingRecords,
    int? totalFinishedWorkouts,
  }) {
    final newRecords = <PersonalRecord>[];

    for (final entry in exercises) {
      final exercise = entry.workoutExercise.exercise;
      if (exercise == null) continue;

      final exerciseId = entry.workoutExercise.exerciseId;
      final workingSets = _completedWorkingSets(entry.sets);
      if (workingSets.isEmpty) continue;

      final existing = existingRecords[exerciseId] ?? [];
      // An exercise is bodyweight-only when it uses bodyweight equipment
      // AND none of the completed sets carry a positive weight value.
      // Non-bodyweight exercises (barbell, dumbbell, cable, etc.) always
      // go through the weighted branch even when weight is null — this
      // prevents accidentally recording only maxReps due to null weight
      // from upstream bugs (see BUG-4).
      final isBodyweightOnly =
          exercise.equipmentType == EquipmentType.bodyweight &&
          workingSets.every((s) => (s.weight ?? 0) <= 0);

      if (isBodyweightOnly) {
        _checkRecord(
          newRecords: newRecords,
          existing: existing,
          userId: userId,
          exerciseId: exerciseId,
          type: RecordType.maxReps,
          sets: workingSets,
          valueExtractor: (s) => (s.reps ?? 0).toDouble(),
        );
      } else {
        _checkRecord(
          newRecords: newRecords,
          existing: existing,
          userId: userId,
          exerciseId: exerciseId,
          type: RecordType.maxWeight,
          sets: workingSets,
          valueExtractor: (s) => s.weight ?? 0,
        );
        _checkRecord(
          newRecords: newRecords,
          existing: existing,
          userId: userId,
          exerciseId: exerciseId,
          type: RecordType.maxReps,
          sets: workingSets,
          valueExtractor: (s) => (s.reps ?? 0).toDouble(),
        );
        _checkVolume(
          newRecords: newRecords,
          existing: existing,
          userId: userId,
          exerciseId: exerciseId,
          sets: workingSets,
        );
      }
    }

    // A workout is the user's first only if they have exactly 1 finished workout
    // (the one being completed now). When totalFinishedWorkouts is not provided,
    // fall back to the legacy heuristic of checking existing records, but this
    // can produce false positives for veteran users trying new exercises.
    final bool isFirstWorkout;
    if (totalFinishedWorkouts != null) {
      isFirstWorkout = totalFinishedWorkouts <= 1 && newRecords.isNotEmpty;
    } else {
      isFirstWorkout =
          existingRecords.values.every((list) => list.isEmpty) &&
          newRecords.isNotEmpty;
    }

    return PRDetectionResult(
      newRecords: newRecords,
      isFirstWorkout: isFirstWorkout,
    );
  }

  /// Filters to completed working sets with valid reps.
  List<ExerciseSet> _completedWorkingSets(List<ExerciseSet> sets) {
    return sets
        .where(
          (s) =>
              s.setType == SetType.working &&
              s.isCompleted &&
              (s.reps ?? 0) > 0,
        )
        .toList();
  }

  /// Check a single record type (maxWeight or maxReps).
  void _checkRecord({
    required List<PersonalRecord> newRecords,
    required List<PersonalRecord> existing,
    required String userId,
    required String exerciseId,
    required RecordType type,
    required List<ExerciseSet> sets,
    required double Function(ExerciseSet) valueExtractor,
  }) {
    ExerciseSet? bestSet;
    var bestValue = 0.0;

    for (final s in sets) {
      final v = valueExtractor(s);
      if (v > bestValue) {
        bestValue = v;
        bestSet = s;
      }
    }

    if (bestSet == null || bestValue <= 0) return;

    final existingRecord = _findExisting(existing, type);
    if (existingRecord != null && bestValue <= existingRecord.value) return;

    newRecords.add(
      PersonalRecord(
        id: _uuid.v4(),
        userId: userId,
        exerciseId: exerciseId,
        recordType: type,
        value: bestValue,
        achievedAt: DateTime.now().toUtc(),
        setId: bestSet.id,
      ),
    );
  }

  /// Check maxVolume (weight * reps per set). Skips if best volume is 0.
  void _checkVolume({
    required List<PersonalRecord> newRecords,
    required List<PersonalRecord> existing,
    required String userId,
    required String exerciseId,
    required List<ExerciseSet> sets,
  }) {
    ExerciseSet? bestSet;
    var bestVolume = 0.0;

    for (final s in sets) {
      final volume = (s.weight ?? 0) * (s.reps ?? 0);
      if (volume > bestVolume) {
        bestVolume = volume;
        bestSet = s;
      }
    }

    if (bestSet == null || bestVolume <= 0) return;

    final existingRecord = _findExisting(existing, RecordType.maxVolume);
    if (existingRecord != null && bestVolume <= existingRecord.value) return;

    newRecords.add(
      PersonalRecord(
        id: _uuid.v4(),
        userId: userId,
        exerciseId: exerciseId,
        recordType: RecordType.maxVolume,
        value: bestVolume,
        achievedAt: DateTime.now().toUtc(),
        setId: bestSet.id,
      ),
    );
  }

  PersonalRecord? _findExisting(List<PersonalRecord> records, RecordType type) {
    for (final r in records) {
      if (r.recordType == type) return r;
    }
    return null;
  }
}
