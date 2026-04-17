import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/workout_local_storage.dart';
import '../data/workout_repository.dart';
import '../models/exercise_set.dart';

export 'notifiers/active_workout_notifier.dart';
export 'notifiers/rest_timer_notifier.dart';

/// Provides the [WorkoutRepository] singleton.
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(Supabase.instance.client);
});

/// Provides the [WorkoutLocalStorage] singleton.
final workoutLocalStorageProvider = Provider<WorkoutLocalStorage>((ref) {
  return WorkoutLocalStorage();
});

/// Whether there is an active workout persisted in Hive.
final hasActiveWorkoutProvider = Provider<bool>((ref) {
  return ref.watch(workoutLocalStorageProvider).hasActiveWorkout;
});

/// Batch-fetch previous workout sets for a list of exercise IDs.
///
/// Keyed by a sorted, comma-joined string of exercise IDs for stable caching
/// (two `List<String>` with identical contents are not `==` in Dart).
/// Callers should pass `(exerciseIds..sort()).join(',')`.
/// Uses `autoDispose` so cached entries are freed when the UI screen
/// navigates away (e.g. finishing a workout). Without autoDispose, every
/// distinct comma-joined ID key lives forever.
final lastWorkoutSetsProvider = FutureProvider.autoDispose
    .family<Map<String, List<ExerciseSet>>, String>((ref, joinedIds) {
      final repo = ref.watch(workoutRepositoryProvider);
      final ids = joinedIds.isEmpty ? <String>[] : joinedIds.split(',');
      return repo.getLastWorkoutSets(ids);
    });

/// Elapsed time since workout started, emitting every second.
final elapsedTimerProvider = StreamProvider.family<Duration, DateTime>((
  ref,
  startedAt,
) {
  return Stream.periodic(const Duration(seconds: 1), (_) {
    return DateTime.now().toUtc().difference(startedAt);
  });
});
