import 'package:freezed_annotation/freezed_annotation.dart';

import '../../exercises/models/exercise.dart';

part 'routine_start_config.freezed.dart';

@freezed
class RoutineStartExercise with _$RoutineStartExercise {
  const factory RoutineStartExercise({
    required String exerciseId,
    required Exercise exercise,
    required int setCount,
    int? targetReps,
    int? restSeconds,
  }) = _RoutineStartExercise;
}

@freezed
class RoutineStartConfig with _$RoutineStartConfig {
  const factory RoutineStartConfig({
    required String routineName,
    required List<RoutineStartExercise> exercises,
  }) = _RoutineStartConfig;
}
