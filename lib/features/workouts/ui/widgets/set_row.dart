import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/reps_stepper.dart';
import '../../../../shared/widgets/weight_stepper.dart';
import '../../models/exercise_set.dart';
import '../../models/set_type.dart';
import '../../providers/notifiers/active_workout_notifier.dart';

/// Displays a single set within an exercise card during an active workout.
///
/// Shows set number, type badge, weight/reps steppers, RPE indicator,
/// and a completion checkbox. Wrapped in [Dismissible] for swipe-to-delete.
class SetRow extends ConsumerWidget {
  const SetRow({
    required this.set,
    required this.workoutExerciseId,
    this.onCompleted,
    super.key,
  });

  final ExerciseSet set;
  final String workoutExerciseId;

  /// Called after the set completion is toggled (for rest timer integration).
  final VoidCallback? onCompleted;

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

  void _copyLastSet(WidgetRef ref) {
    ref
        .read(activeWorkoutProvider.notifier)
        .copyLastSet(workoutExerciseId, set.id);
  }

  void _onComplete(WidgetRef ref) {
    final wasCompleted = set.isCompleted;
    ref
        .read(activeWorkoutProvider.notifier)
        .completeSet(workoutExerciseId, set.id);
    if (!wasCompleted) {
      HapticFeedback.mediumImpact();
      onCompleted?.call();
    }
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
        HapticFeedback.lightImpact();
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
            // Set number with copy-last-set and long-press for set type.
            // Uses 48dp minimum touch target per Material guidelines.
            Semantics(
              label: set.setNumber > 1
                  ? 'Set ${set.setNumber}. Tap to copy previous set. '
                        'Long press to change type: ${set.setType.displayName}'
                  : 'Set ${set.setNumber}. '
                        'Long press to change type: ${set.setType.displayName}',
              child: InkWell(
                onTap: set.setNumber > 1 ? () => _copyLastSet(ref) : null,
                onLongPress: () => _cycleSetType(ref),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${set.setNumber}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: set.setNumber > 1
                              ? theme.colorScheme.primary.withValues(alpha: 0.8)
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      // Show set type label below the number
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _setTypeBadgeColor(theme, set.setType),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _setTypeLabels[set.setType] ?? 'W',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

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
            Expanded(
              child: RepsStepper(
                value: set.reps ?? 0,
                onChanged: (v) =>
                    notifier.updateSet(workoutExerciseId, set.id, reps: v),
              ),
            ),

            // Completion checkbox
            Semantics(
              label: set.isCompleted ? 'Set completed' : 'Mark set as done',
              child: SizedBox(
                width: 48,
                height: 48,
                child: Checkbox(
                  value: set.isCompleted,
                  onChanged: (_) => _onComplete(ref),
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

/// Compact RPE indicator that opens a popup picker on tap.
///
/// Retained for future re-enablement when RPE tracking is added back.
// ignore: unused_element
class _RpeIndicator extends StatelessWidget {
  const _RpeIndicator({required this.rpe, required this.onChanged});

  final int? rpe;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: rpe != null ? 'RPE $rpe. Tap to change.' : 'Set RPE',
      child: PopupMenuButton<int>(
        onSelected: onChanged,
        tooltip: 'Rate of perceived exertion',
        constraints: const BoxConstraints(minWidth: 56),
        position: PopupMenuPosition.under,
        itemBuilder: (_) => List.generate(
          10,
          (i) => PopupMenuItem<int>(
            value: i + 1,
            height: 40,
            child: Text(
              'RPE ${i + 1}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: (i + 1) == rpe ? FontWeight.w700 : null,
                color: (i + 1) == rpe ? theme.colorScheme.primary : null,
              ),
            ),
          ),
        ),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rpe != null
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : theme.colorScheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            rpe != null ? '$rpe' : 'RPE',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: rpe != null ? 13 : 9,
              fontWeight: FontWeight.w700,
              color: rpe != null
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
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
