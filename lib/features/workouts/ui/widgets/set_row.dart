import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/reps_stepper.dart';
import '../../../../shared/widgets/weight_stepper.dart';
import '../../models/exercise_set.dart';
import '../../models/set_type.dart';
import '../../providers/notifiers/active_workout_notifier.dart';

/// Displays a single set within an exercise card during an active workout.
///
/// Shows set number, type badge, weight/reps steppers, and a completion checkbox.
/// Wrapped in [Dismissible] for swipe-to-delete.
class SetRow extends ConsumerWidget {
  const SetRow({required this.set, required this.workoutExerciseId, super.key});

  final ExerciseSet set;
  final String workoutExerciseId;

  static const _setTypeLabels = {
    SetType.working: 'W',
    SetType.warmup: 'WU',
    SetType.dropset: 'D',
    SetType.failure: 'F',
  };

  void _cycleSetType(WidgetRef ref) {
    const types = SetType.values;
    final nextIndex = (types.indexOf(set.setType) + 1) % types.length;
    ref
        .read(activeWorkoutProvider.notifier)
        .updateSet(workoutExerciseId, set.id, setType: types[nextIndex]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(activeWorkoutProvider.notifier);

    return Dismissible(
      key: ValueKey(set.id),
      direction: DismissDirection.endToStart,
      background: _DismissBackground(theme: theme),
      onDismissed: (_) {
        notifier.deleteSet(workoutExerciseId, set.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Set ${set.setNumber} deleted'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // Set number
            SizedBox(
              width: 28,
              child: Text(
                '${set.setNumber}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Set type badge
            Semantics(
              label: 'Set type: ${set.setType.displayName}. Tap to change.',
              child: InkWell(
                onTap: () => _cycleSetType(ref),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _setTypeBadgeColor(theme, set.setType),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _setTypeLabels[set.setType] ?? 'W',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 4),

            // Weight stepper + "kg" label
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WeightStepper(
                    value: set.weight ?? 0,
                    onChanged: (v) => notifier.updateSet(
                      workoutExerciseId,
                      set.id,
                      weight: v,
                    ),
                  ),
                  Text(
                    'kg',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Reps stepper
            RepsStepper(
              value: set.reps ?? 0,
              onChanged: (v) =>
                  notifier.updateSet(workoutExerciseId, set.id, reps: v),
            ),

            // Completion checkbox
            Semantics(
              label: set.isCompleted ? 'Set completed' : 'Mark set as done',
              child: SizedBox(
                width: 48,
                height: 48,
                child: Checkbox(
                  value: set.isCompleted,
                  onChanged: (_) =>
                      notifier.completeSet(workoutExerciseId, set.id),
                  activeColor: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _setTypeBadgeColor(ThemeData theme, SetType type) {
    return switch (type) {
      SetType.working => theme.colorScheme.primary.withValues(alpha: 0.2),
      SetType.warmup => theme.colorScheme.secondary.withValues(alpha: 0.2),
      SetType.dropset => theme.colorScheme.tertiary.withValues(alpha: 0.2),
      SetType.failure => theme.colorScheme.error.withValues(alpha: 0.2),
    };
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 16),
      color: theme.colorScheme.error.withValues(alpha: 0.3),
      child: Icon(Icons.delete_outline, color: theme.colorScheme.error),
    );
  }
}
