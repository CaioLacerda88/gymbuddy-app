import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/workout_repository.dart';
import '../models/workout.dart';
import 'workout_providers.dart';

/// Paginated workout history (finished workouts only).
class WorkoutHistoryNotifier extends AsyncNotifier<List<Workout>> {
  static const _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  FutureOr<List<Workout>> build() async {
    _isLoadingMore = false;
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return [];
    final repo = ref.watch(workoutRepositoryProvider);
    final workouts = await repo.getWorkoutHistory(userId, limit: _pageSize);
    _hasMore = workouts.length >= _pageSize;
    return workouts;
  }

  /// Whether more pages are available.
  bool get hasMore => _hasMore;

  /// Load the next page and append to the current list.
  Future<void> loadMore() async {
    if (_isLoadingMore) return;
    final current = state.value ?? [];
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null || !_hasMore) return;
    _isLoadingMore = true;
    try {
      final repo = ref.read(workoutRepositoryProvider);
      final more = await repo.getWorkoutHistory(
        userId,
        limit: _pageSize,
        offset: current.length,
      );
      _hasMore = more.length >= _pageSize;
      state = AsyncData([...current, ...more]);
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Force-refresh from the first page.
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// Provides paginated workout history.
final workoutHistoryProvider =
    AsyncNotifierProvider<WorkoutHistoryNotifier, List<Workout>>(
      WorkoutHistoryNotifier.new,
    );

/// Fetch full workout detail for a specific workout.
final workoutDetailProvider = FutureProvider.family<WorkoutDetail, String>((
  ref,
  workoutId,
) {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.getWorkoutDetail(workoutId);
});
