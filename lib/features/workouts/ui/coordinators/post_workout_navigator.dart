import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../personal_records/domain/pr_detection_service.dart';
import '../../../weekly_plan/providers/weekly_plan_provider.dart';
import '../widgets/add_to_plan_prompt.dart';

/// Stateless helper owning the post-finish navigation choreography.
///
/// **Why a separate type:** the post-finish path branches across three
/// signals (overflow card tap, PR celebration, plan-prompt) and consults
/// providers from a `postFrameCallback` that fires after the screen's
/// State has been disposed. Pulling the switch into a dedicated type
/// keeps the rules legible and isolates the lifetime-sensitive
/// `ProviderScope.containerOf` reads behind a single API.
///
/// All methods take `rootContext` (the root navigator's context, which
/// stays alive for the full app session) and use it for both the
/// `mounted` guard and provider-container access.
class PostWorkoutNavigator {
  const PostWorkoutNavigator();

  /// Whether to show the "Add to plan?" prompt after finishing.
  ///
  /// True when: the workout came from a routine, a plan exists for this
  /// week, and the routine is NOT already in the plan.
  ///
  /// **Why this is evaluated synchronously inside `_FinishWorkoutCoordinator`
  /// (BEFORE the `await notifier.finishWorkout()`):** after the save commits
  /// the active-workout notifier transitions to `AsyncData(null)`, which
  /// disposes `_ActiveWorkoutScreenState` and invalidates its `ref`.
  /// Calling `ref.read(weeklyPlanProvider)` on a disposed ref throws a
  /// `StateError`. The caller captures the bool synchronously and passes
  /// it to [navigateAfterFinish].
  bool shouldShowPlanPrompt(WidgetRef ref, String? routineId) {
    if (routineId == null) return false;
    final plan = ref.read(weeklyPlanProvider).value;
    if (plan == null) return false;
    return !plan.routines.any((r) => r.routineId == routineId);
  }

  /// Shows the add-to-plan prompt, then navigates home.
  ///
  /// **Why we read providers via [ProviderScope.containerOf] instead of `ref`:**
  /// this method is invoked from a `postFrameCallback` after the finish
  /// coordinator has awaited [CelebrationPlayer.play]. By that point the
  /// workout notifier has transitioned to `AsyncData(null)`, the screen has
  /// rebuilt, and the original `_ActiveWorkoutScreenState` is disposed —
  /// touching `ref` would throw [StateError]. The root navigator context
  /// stays alive for the full app session, so its container is the safe
  /// access path. (`navContext.mounted` guards are inert here because the
  /// root navigator never unmounts; they're left in place defensively for
  /// the post-prompt step where the user may have backgrounded the app.)
  Future<void> showPlanPromptAndGoHome(
    BuildContext navContext,
    String routineId,
    String routineName,
  ) async {
    final shouldAdd = await showAddToPlanPrompt(
      navContext,
      routineName: routineName,
    );
    if (!navContext.mounted) return;
    if (shouldAdd == true) {
      final container = ProviderScope.containerOf(navContext);
      await container
          .read(weeklyPlanProvider.notifier)
          .addRoutineToPlan(routineId);
    }
    if (!navContext.mounted) return;
    navContext.go('/home');
  }

  /// Schedule the post-finish navigation transition on the next frame.
  ///
  /// Defers the route transition by one frame: by the time we reach this
  /// point the celebration overflow card is gone (the player awaited the
  /// user-tap-or-timeout completer), so this post-frame callback is purely
  /// defensive scheduling — any post-await microtask (Riverpod listeners,
  /// analytics, etc.) gets a clean frame boundary before the route teardown
  /// begins.
  ///
  /// **Branch precedence:**
  ///   1. `userTappedOverflow` → `/profile` (Saga). Honors the explicit nav
  ///      choice the user made by tapping the overflow card; trumps PR
  ///      celebration and plan-prompt.
  ///   2. PR celebration → `/pr-celebration` (with optional plan-prompt
  ///      payload so the celebration screen can chain into it).
  ///   3. Plan-prompt → fire-and-forget [showPlanPromptAndGoHome] (the
  ///      dialog lives on a separate Overlay subtree; we don't await it).
  ///   4. Default → `/home`.
  void navigateAfterFinish({
    required BuildContext rootContext,
    required bool userTappedOverflow,
    required PRDetectionResult? prResult,
    required Map<String, String> exerciseNames,
    required bool shouldPrompt,
    required String? routineId,
    required String? routineName,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rootContext.mounted) return;
      if (userTappedOverflow) {
        rootContext.go('/profile');
      } else if (prResult != null && prResult.hasNewRecords) {
        rootContext.go(
          '/pr-celebration',
          extra: {
            'result': prResult,
            'exerciseNames': exerciseNames,
            if (shouldPrompt) 'planPromptRoutineId': routineId,
            if (shouldPrompt) 'planPromptRoutineName': routineName,
          },
        );
      } else if (shouldPrompt) {
        // Fire-and-forget: dialog lives on a separate Overlay subtree, so
        // we don't need to await it here. The dialog handles its own
        // navigate-home on dismiss.
        unawaited(
          showPlanPromptAndGoHome(rootContext, routineId!, routineName!),
        );
      } else {
        rootContext.go('/home');
      }
    });
  }
}
