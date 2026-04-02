import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/workout_local_storage.dart';
import '../data/workout_repository.dart';

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
