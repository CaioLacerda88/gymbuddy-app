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

  /// Whether a load-more request is currently in progress.
  bool get isLoadingMore => _isLoadingMore;

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

/// Total count of finished workouts for the current user.
///
/// Uses a server-side `COUNT(*)` query rather than the paginated list length,
/// so it returns the real total regardless of page size.
///
/// `ref.keepAlive()` prevents Riverpod from disposing the provider when the
/// last listener unsubscribes — the count is watched from multiple screens
/// (Home's beginner CTA guard, Profile, Manage Data) and navigating between
/// them would otherwise re-issue the `COUNT(*)` query on every push/pop.
/// Explicit `ref.invalidate(workoutCountProvider)` calls (on workout save,
/// data reset) still force a fresh fetch regardless of keepAlive.
final workoutCountProvider = FutureProvider<int>((ref) {
  ref.keepAlive();
  final userId = ref.read(authRepositoryProvider).currentUser?.id;
  if (userId == null) return 0;
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.getFinishedWorkoutCount(userId);
});

/// Derived boolean: true iff the user has at least one finished workout.
///
/// Consumer widgets that only need the "has any history?" boolean should
/// watch this instead of [workoutHistoryProvider] — that way they rebuild
/// only on the false→true transition (or back to zero on data reset) and
/// NOT on every `loadMore()` page-append. Also faster to read at cold
/// start since [workoutCountProvider] is `keepAlive` and returns a single
/// integer rather than waiting on the paginated list.
final hasAnyWorkoutProvider = Provider<bool>((ref) {
  final count = ref.watch(workoutCountProvider).value;
  return count != null && count > 0;
});

/// Fetch full workout detail for a specific workout.
final workoutDetailProvider = FutureProvider.family<WorkoutDetail, String>((
  ref,
  workoutId,
) {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.getWorkoutDetail(workoutId);
});

/// Data about the user's most recent completed workout.
///
/// Returns the workout name and how long ago it was. Used by the editorial
/// "Last: ..." line on the Home screen. Derives from the already-loaded
/// history.
typedef LastSessionInfo = ({String name, String relativeDate, DateTime date});

// Returns null during loading, on error, or when no workouts exist.
// UI shows "No workouts yet" for all three.
final lastSessionProvider = Provider<LastSessionInfo?>((ref) {
  final history = ref.watch(workoutHistoryProvider).value;
  if (history == null || history.isEmpty) return null;
  final workout = history.first;
  final date = workout.finishedAt ?? workout.startedAt;
  return (
    name: workout.name,
    relativeDate: _formatRelativeDate(date),
    date: date,
  );
});

/// Format a date relative to today for stat cell display.
///
/// Normalizes both dates to local time before comparison, so UTC timestamps
/// from Supabase are correctly compared against the user's local "today".
String _formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final local = date.toLocal();
  final dateDay = DateTime(local.year, local.month, local.day);
  final diff = today.difference(dateDay).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return '$diff days ago';
  if (diff < 30) return '${(diff / 7).floor()}w ago';
  return '${(diff / 30).floor()}mo ago';
}
