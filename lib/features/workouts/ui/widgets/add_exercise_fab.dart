import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// "Add exercise" FAB shown on the active-workout screen when at least one
/// exercise is already in the workout.
///
/// Phase 18c repurposed the FAB slot from "Finish workout" (now the bottom
/// bar) to "Add exercise mid-session" — a genuinely thumb-reach action.
///
/// **Selector contract:** the outer [Semantics] carries
/// `identifier: 'workout-add-exercise'`. The same identifier is reused on
/// the empty-state CTA in [EmptyWorkoutBody] so a single Playwright selector
/// matches whichever entry point is currently visible. Do not rename.
class AddExerciseFab extends StatelessWidget {
  const AddExerciseFab({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      identifier: 'workout-add-exercise',
      label: AppLocalizations.of(context).addExerciseToWorkoutSemantics,
      button: true,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(28),
        ),
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          backgroundColor: Colors.transparent,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 0,
          icon: const Icon(Icons.add_rounded),
          // Phase 18c: FAB freed up from "Finish" → repurposed for
          // "Add exercise" mid-session (genuinely thumb-reach action).
          label: Text(AppLocalizations.of(context).addExerciseFabLabel),
        ),
      ),
    );
  }
}
