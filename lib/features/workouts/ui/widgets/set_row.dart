import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/number_format.dart';
import '../../../../core/utils/enum_l10n.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/reps_stepper.dart';
import '../../../../shared/widgets/weight_stepper.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../models/exercise_set.dart';
import '../../models/set_type.dart';
import '../../providers/notifiers/active_workout_notifier.dart';
import 'pr_chip.dart';

/// Displays a single set within an exercise card during an active workout.
///
/// Shows set number, type badge, weight/reps steppers, RPE indicator,
/// and a completion checkbox. Wrapped in [Dismissible] for swipe-to-delete.
class SetRow extends ConsumerStatefulWidget {
  const SetRow({
    required this.set,
    required this.workoutExerciseId,
    this.onCompleted,
    this.lastSet,
    this.isNew = false,
    this.isPrCandidate = false,
    super.key,
  });

  final ExerciseSet set;
  final String workoutExerciseId;

  /// Called after the set completion is toggled (for rest timer integration).
  final VoidCallback? onCompleted;

  /// The matching set from the previous workout session, used to show a hint.
  final ExerciseSet? lastSet;

  /// Whether this set was just added. When true, the completion checkbox
  /// is locked for 600ms to prevent accidental taps from thumb drift.
  final bool isNew;

  /// Phase 18c, spec §13: when `true`, the inline [PrChip] renders to the
  /// right of the reps stepper. Set by the parent (active workout screen)
  /// only AFTER set commit — typing weight/reps mid-keystroke must not
  /// flash the chip. The parent computes candidacy via
  /// [isPrCandidateAfterCommit] and persists the chip for the rest of the
  /// session (chip persistence == set stays committed).
  final bool isPrCandidate;

  @override
  ConsumerState<SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<SetRow> {
  bool _locked = false;
  Timer? _lockTimer;

  static Map<SetType, String> _setTypeLabels(AppLocalizations l10n) => {
    SetType.working: l10n.setTypeAbbrWorking,
    SetType.warmup: l10n.setTypeAbbrWarmup,
    SetType.dropset: l10n.setTypeAbbrDropset,
    SetType.failure: l10n.setTypeAbbrFailure,
  };

  @override
  void initState() {
    super.initState();
    if (widget.isNew) {
      _locked = true;
      _lockTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _locked = false);
      });
    }
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  void _cycleSetType() {
    const types = SetType.values;
    final nextIndex = (types.indexOf(widget.set.setType) + 1) % types.length;
    ref
        .read(activeWorkoutProvider.notifier)
        .updateSet(
          widget.workoutExerciseId,
          widget.set.id,
          setType: types[nextIndex],
        );
  }

  void _copyLastSet() {
    ref
        .read(activeWorkoutProvider.notifier)
        .copyLastSet(widget.workoutExerciseId, widget.set.id);
  }

  void _onComplete() {
    if (_locked) return;
    final wasCompleted = widget.set.isCompleted;
    ref
        .read(activeWorkoutProvider.notifier)
        .completeSet(widget.workoutExerciseId, widget.set.id);
    if (!wasCompleted) {
      HapticFeedback.mediumImpact();
      widget.onCompleted?.call();
    }
  }

  /// Whether the hint line should be shown.
  ///
  /// Suppress the hint when pre-filled values match the last session exactly
  /// and the set is not yet completed (the hint is redundant in that case).
  bool _shouldShowHint() {
    final lastSet = widget.lastSet;
    if (lastSet == null) return false;
    if (widget.set.isCompleted) return false;

    final currentWeight = widget.set.weight ?? 0;
    final currentReps = widget.set.reps ?? 0;
    final lastWeight = lastSet.weight ?? 0;
    final lastReps = lastSet.reps ?? 0;

    // Hide hint when values match exactly.
    if (currentWeight == lastWeight.toDouble() && currentReps == lastReps) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final set = widget.set;
    final weightUnit = ref.watch(profileProvider).value?.weightUnit ?? 'kg';
    final notifier = ref.read(activeWorkoutProvider.notifier);

    return Dismissible(
      key: ValueKey(set.id),
      direction: DismissDirection.endToStart,
      background: _DismissBackground(theme: theme),
      confirmDismiss: (_) async {
        // Guard against concurrent swipes removing the same set twice.
        // If the set was already deleted by a prior swipe gesture, the
        // state will no longer contain it.
        final current = ref.read(activeWorkoutProvider).value;
        if (current == null) return false;
        final exercise = current.exercises
            .where((e) => e.workoutExercise.id == widget.workoutExerciseId)
            .firstOrNull;
        if (exercise == null) return false;
        return exercise.sets.any((s) => s.id == set.id);
      },
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        // Save the set data before deleting so we can restore on undo.
        final deletedSet = set;
        notifier.deleteSet(widget.workoutExerciseId, set.id);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).setDeleted(deletedSet.setNumber),
              ),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: AppLocalizations.of(context).undo,
                onPressed: () {
                  notifier.restoreSet(widget.workoutExerciseId, deletedSet);
                },
              ),
            ),
          );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_shouldShowHint())
            Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 4),
              child: Text(
                AppLocalizations.of(context).previousSet(
                  AppNumberFormat.weight(
                    (widget.lastSet!.weight ?? 0).toDouble(),
                    locale: Localizations.localeOf(context).languageCode,
                  ),
                  weightUnit,
                  widget.lastSet!.reps ?? 0,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Set number with copy-last-set and long-press for set type.
                // Uses 48dp minimum touch target per Material guidelines.
                Semantics(
                  label: set.setNumber > 1
                      ? AppLocalizations.of(context).setNumberCopySemantics(
                          set.setNumber,
                          set.setType.localizedName(
                            AppLocalizations.of(context),
                          ),
                        )
                      : AppLocalizations.of(context).setNumberSemantics(
                          set.setNumber,
                          set.setType.localizedName(
                            AppLocalizations.of(context),
                          ),
                        ),
                  child: Tooltip(
                    message: set.setNumber > 1
                        ? AppLocalizations.of(
                            context,
                          ).tooltipCopyLastSetAndChangeType
                        : AppLocalizations.of(context).tooltipChangeType,
                    preferBelow: true,
                    child: InkWell(
                      onTap: set.setNumber > 1 ? _copyLastSet : null,
                      onLongPress: _cycleSetType,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        // BUG-018: bumped from 40x40 to Material's 48dp tap-
                        // target minimum so the set-number cell (tap-to-copy
                        // / long-press-to-cycle-type) is reliably hittable
                        // mid-workout.
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
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.8,
                                      )
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                                fontWeight: FontWeight.w700,
                                // Underline hint for tap-to-copy on sets > 1.
                                decoration: set.setNumber > 1
                                    ? TextDecoration.underline
                                    : null,
                                decorationColor: set.setNumber > 1
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.4,
                                      )
                                    : null,
                                decorationStyle: TextDecorationStyle.dotted,
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
                                _setTypeLabels(
                                      AppLocalizations.of(context),
                                    )[set.setType] ??
                                    AppLocalizations.of(
                                      context,
                                    ).setTypeAbbrWorking,
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
                ),

                // Weight stepper + unit label
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: WeightStepper(
                          value: set.weight ?? 0,
                          unit: weightUnit,
                          onChanged: (v) => notifier.updateSet(
                            widget.workoutExerciseId,
                            set.id,
                            weight: v,
                          ),
                        ),
                      ),
                      Text(
                        weightUnit,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Reps stepper
                Expanded(
                  flex: 2,
                  child: RepsStepper(
                    value: set.reps ?? 0,
                    onChanged: (v) => notifier.updateSet(
                      widget.workoutExerciseId,
                      set.id,
                      reps: v,
                    ),
                  ),
                ),

                // Inline PR chip — rendered only when the parent has marked
                // the set as a PR candidate AFTER commit. Wrapped in
                // [SizedBox] with a fixed-height container so the row's
                // overall height does not shift when the chip appears
                // (spec §13: "no row height expansion").
                if (widget.isPrCandidate)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, right: 4),
                    child: PrChip(),
                  ),

                // Completion checkbox
                Semantics(
                  container: true,
                  identifier: set.isCompleted
                      ? 'workout-set-completed'
                      : 'workout-set-done',
                  label: set.isCompleted
                      ? AppLocalizations.of(context).setCompleted
                      : AppLocalizations.of(context).markSetAsDone,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Checkbox(
                      value: set.isCompleted,
                      onChanged: (_) => _onComplete(),
                      activeColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final l10n = AppLocalizations.of(context);
    final currentRpe = rpe;

    return Semantics(
      label: currentRpe != null ? l10n.rpeValue(currentRpe) : l10n.setRpe,
      child: PopupMenuButton<int>(
        onSelected: onChanged,
        tooltip: l10n.rpeTooltip,
        constraints: const BoxConstraints(minWidth: 56),
        position: PopupMenuPosition.under,
        itemBuilder: (_) => List.generate(
          10,
          (i) => PopupMenuItem<int>(
            value: i + 1,
            height: 40,
            child: Text(
              l10n.rpeMenuItem(i + 1),
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
            rpe != null ? '$rpe' : l10n.rpeLabel,
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
