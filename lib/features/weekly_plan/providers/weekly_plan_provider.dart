import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/models/weekly_plan.dart';
import '../data/weekly_plan_repository.dart';

/// Provides the [WeeklyPlanRepository] singleton.
final weeklyPlanRepositoryProvider = Provider<WeeklyPlanRepository>((ref) {
  return WeeklyPlanRepository(Supabase.instance.client);
});

/// Returns the Monday (ISO week start) for the given date.
DateTime currentWeekMonday([DateTime? now]) {
  final date = now ?? DateTime.now();
  // DateTime.weekday: Monday = 1, Sunday = 7
  final daysFromMonday = date.weekday - 1;
  final monday = DateTime(date.year, date.month, date.day - daysFromMonday);
  return monday;
}

/// Manages the current week's plan state.
class WeeklyPlanNotifier extends AsyncNotifier<WeeklyPlan?> {
  @override
  FutureOr<WeeklyPlan?> build() async {
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return null;
    final repo = ref.watch(weeklyPlanRepositoryProvider);
    final monday = currentWeekMonday();

    final existing = await repo.getPlanForWeek(userId, monday);
    if (existing != null) return existing;

    // No plan for this week — schedule auto-populate after build completes.
    // We must not perform write side-effects or modify other providers during
    // build() (Riverpod anti-pattern that causes "Cannot modify state during
    // build" errors and infinite rebuilds).
    Future.microtask(() => _tryAutoPopulate(userId, monday));
    return null;
  }

  /// Attempts to auto-populate the current week from the previous week's plan.
  ///
  /// Called via microtask after build() to avoid modifying state during build.
  /// Strips all completion data so the new week starts fresh (BUG-R1).
  Future<void> _tryAutoPopulate(String userId, DateTime monday) async {
    final repo = ref.read(weeklyPlanRepositoryProvider);
    final previous = await repo.getPreviousWeekPlan(userId, monday);
    if (previous == null || previous.routines.isEmpty) return;

    // Reset completions, keep order and routine IDs.
    final resetRoutines = previous.routines
        .map((r) => BucketRoutine(routineId: r.routineId, order: r.order))
        .toList();

    final plan = await repo.upsertPlan(
      userId: userId,
      weekStart: monday,
      routines: resetRoutines,
    );

    state = AsyncData(plan);

    // Signal the UI to show the "Same plan this week?" confirmation banner.
    ref.read(weeklyPlanNeedsConfirmationProvider.notifier).state = true;
  }

  /// Create or update the current week's plan with the given routines.
  Future<void> upsertPlan(List<BucketRoutine> routines) async {
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;
    final repo = ref.read(weeklyPlanRepositoryProvider);
    final monday = currentWeekMonday();
    state = await AsyncValue.guard(() async {
      return repo.upsertPlan(
        userId: userId,
        weekStart: monday,
        routines: routines,
      );
    });
  }

  /// Mark a routine in the bucket as completed by a workout.
  ///
  /// Uses the in-memory routines list to build the update payload,
  /// avoiding a redundant SELECT (single atomic UPDATE).
  Future<void> markRoutineComplete({
    required String routineId,
    required String workoutId,
  }) async {
    final plan = state.valueOrNull;
    if (plan == null) return;

    // Check if this routine is in the bucket and not yet completed.
    final hasMatch = plan.routines.any(
      (r) => r.routineId == routineId && r.completedWorkoutId == null,
    );
    if (!hasMatch) return;

    final repo = ref.read(weeklyPlanRepositoryProvider);
    state = await AsyncValue.guard(() async {
      return repo.markRoutineComplete(
        planId: plan.id,
        routineId: routineId,
        workoutId: workoutId,
        currentRoutines: plan.routines,
      );
    });
  }

  /// Auto-populate from last week's plan (reset completions).
  Future<WeeklyPlan?> autoPopulateFromLastWeek() async {
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return null;
    final repo = ref.read(weeklyPlanRepositoryProvider);
    final monday = currentWeekMonday();

    final previous = await repo.getPreviousWeekPlan(userId, monday);
    if (previous == null || previous.routines.isEmpty) return null;

    // Reset completions, keep order and routine IDs.
    final resetRoutines = previous.routines
        .map((r) => BucketRoutine(routineId: r.routineId, order: r.order))
        .toList();

    final plan = await repo.upsertPlan(
      userId: userId,
      weekStart: monday,
      routines: resetRoutines,
    );
    state = AsyncData(plan);
    return plan;
  }

  /// Add a routine to the current week's plan.
  ///
  /// Returns `true` if the routine was added, `false` if it was already
  /// present or no plan exists to add to.
  Future<bool> addRoutineToPlan(String routineId) async {
    final plan = state.valueOrNull;
    if (plan == null) return false;

    // Already in plan — nothing to do.
    if (plan.routines.any((r) => r.routineId == routineId)) return false;

    final updatedRoutines = [
      ...plan.routines,
      BucketRoutine(routineId: routineId, order: plan.routines.length + 1),
    ];
    await upsertPlan(updatedRoutines);
    return true;
  }

  /// Clear the current week's plan.
  Future<void> clearPlan() async {
    final plan = state.valueOrNull;
    if (plan == null) return;
    final repo = ref.read(weeklyPlanRepositoryProvider);
    await repo.deletePlan(plan.id);
    state = const AsyncData(null);
  }

  /// Force-refresh from the server.
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final weeklyPlanProvider =
    AsyncNotifierProvider<WeeklyPlanNotifier, WeeklyPlan?>(
      WeeklyPlanNotifier.new,
    );

/// Whether the current week plan needs confirmation (auto-populated but not
/// explicitly confirmed by the user). True when plan exists and was just
/// created by auto-populate at the start of the week.
///
/// This is a simple client-side state — we track it in memory only.
final weeklyPlanNeedsConfirmationProvider = StateProvider<bool>((ref) => false);
