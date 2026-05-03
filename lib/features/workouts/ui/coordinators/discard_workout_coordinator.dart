import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../models/active_workout_state.dart';
import '../../providers/workout_providers.dart';
import '../widgets/discard_workout_dialog.dart';

/// Owns the "discard workout" lifecycle.
///
/// Resolves BUG-041: previously `_isShowingDiscardDialog` was a file-level
/// `bool` shared between the outer screen's PopScope handler and the inner
/// body's AppBar close button. Hoisting it to a per-screen instance field
/// (this coordinator, owned by `_ActiveWorkoutScreenState`) eliminates the
/// global without losing the "single dialog at a time across both call
/// sites" guarantee — both call sites share the same coordinator instance.
///
/// **Lifetime:** as long as the active-workout screen's State. The screen
/// owns this coordinator and disposes it implicitly when its State is torn
/// down (no resources to release; the field is just a flag).
class DiscardWorkoutCoordinator {
  /// Re-entrance guard for [show]. Prevents stacked discard dialogs when the
  /// user taps the AppBar close button while a PopScope-triggered dialog is
  /// already open (or vice-versa).
  bool _isShowingDialog = false;

  /// Show the discard confirmation dialog and, on confirm, run the discard
  /// notifier action and navigate home.
  ///
  /// Idempotent within a single dialog lifecycle — concurrent invocations
  /// while a dialog is already up are no-ops.
  Future<void> show(
    BuildContext context,
    WidgetRef ref,
    ActiveWorkoutState state,
  ) async {
    if (_isShowingDialog) return;
    _isShowingDialog = true;
    try {
      final elapsed = DateTime.now().toUtc().difference(
        state.workout.startedAt,
      );
      final shouldDiscard = await DiscardWorkoutDialog.show(
        context,
        elapsedDuration: elapsed,
      );
      if (shouldDiscard == true && context.mounted) {
        await ref.read(activeWorkoutProvider.notifier).discardWorkout();
        if (!context.mounted) return;

        final result = ref.read(activeWorkoutProvider);
        if (result.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).failedToDiscardWorkout,
              ),
            ),
          );
          return;
        }
        context.go('/home');
      }
    } finally {
      _isShowingDialog = false;
    }
  }
}
