import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/exercise_image.dart';
import '../../../shared/widgets/exercise_info_sections.dart';
import '../models/active_workout_state.dart';
import '../models/exercise_set.dart';
import '../models/weight_unit.dart';
import '../models/set_type.dart';
import '../utils/set_defaults.dart';
import '../../exercises/models/exercise.dart';
import '../../personal_records/models/personal_record.dart';
import '../../personal_records/providers/pr_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../../personal_records/models/record_type.dart';
import '../../routines/providers/notifiers/routine_list_notifier.dart';
import '../../weekly_plan/providers/weekly_plan_provider.dart';
import '../providers/workout_providers.dart';
import '../providers/workout_history_providers.dart';
import 'widgets/add_to_plan_prompt.dart';
import 'widgets/discard_workout_dialog.dart';
import 'widgets/exercise_picker_sheet.dart';
import 'widgets/finish_workout_dialog.dart';
import 'widgets/rest_timer_overlay.dart';
import 'widgets/set_row.dart';

/// Full-screen active workout experience.
///
/// Displayed outside the shell route (no bottom nav). Watches
/// [activeWorkoutProvider] and renders exercise cards with sets.
/// Overlays the [RestTimerOverlay] when a rest timer is running.
class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(activeWorkoutProvider);
    final timerState = ref.watch(restTimerProvider);

    // valueOrNull retains the previous data during AsyncLoading transitions.
    final displayState = asyncState.value;

    if (displayState == null && !asyncState.isLoading) {
      // Workout was finished or discarded -- navigate home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/home');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (displayState == null) {
      // Still loading initial state — wrap with PopScope so Android back
      // does not close the app.
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && context.mounted) context.go('/home');
        },
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showDiscardDialog(context, ref, displayState);
      },
      child: Stack(
        children: [
          _ActiveWorkoutBody(state: displayState),
          if (asyncState.isLoading)
            const ModalBarrier(dismissible: false, color: Colors.black54),
          if (asyncState.isLoading)
            const Center(child: CircularProgressIndicator()),
          if (timerState != null) const RestTimerOverlay(),
        ],
      ),
    );
  }

  /// Shows the discard workout dialog and handles the result.
  ///
  /// Extracted to the top-level [ActiveWorkoutScreen] so PopScope can invoke it
  /// regardless of the internal widget tree state.
  Future<void> _showDiscardDialog(
    BuildContext context,
    WidgetRef ref,
    ActiveWorkoutState state,
  ) async {
    final elapsed = DateTime.now().toUtc().difference(state.workout.startedAt);
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
          const SnackBar(
            content: Text('Failed to discard workout. Please retry.'),
          ),
        );
        return;
      }
      context.go('/home');
    }
  }
}

class _ActiveWorkoutBody extends ConsumerStatefulWidget {
  const _ActiveWorkoutBody({required this.state});

  final ActiveWorkoutState state;

  @override
  ConsumerState<_ActiveWorkoutBody> createState() => _ActiveWorkoutBodyState();
}

class _ActiveWorkoutBodyState extends ConsumerState<_ActiveWorkoutBody> {
  bool _reorderMode = false;
  bool _isEditingName = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.state.workout.name);
    // Keep the screen on while the user is actively logging sets. Errors
    // are swallowed so unsupported platforms (e.g. some web browsers or
    // test environments without a platform handler) don't break logging.
    unawaited(WakelockPlus.enable().catchError((_) {}));
  }

  @override
  void didUpdateWidget(_ActiveWorkoutBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditingName &&
        oldWidget.state.workout.name != widget.state.workout.name) {
      _nameController.text = widget.state.workout.name;
    }
  }

  @override
  void dispose() {
    // Release the wakelock before tearing down so the phone can sleep
    // again once the user leaves the logging view. Fire-and-forget with
    // error swallowing to stay consistent with the enable path.
    unawaited(WakelockPlus.disable().catchError((_) {}));
    _nameController.dispose();
    super.dispose();
  }

  void _submitName() {
    final trimmed = _nameController.text.trim();
    if (trimmed.isNotEmpty) {
      ref.read(activeWorkoutProvider.notifier).renameWorkout(trimmed);
    } else {
      _nameController.text = widget.state.workout.name;
    }
    setState(() => _isEditingName = false);
  }

  bool get _hasCompletedSet =>
      widget.state.exercises.any((e) => e.sets.any((s) => s.isCompleted));

  Future<void> _onBackPressed() async {
    final elapsed = DateTime.now().toUtc().difference(
      widget.state.workout.startedAt,
    );
    final shouldDiscard = await DiscardWorkoutDialog.show(
      context,
      elapsedDuration: elapsed,
    );
    if (shouldDiscard == true && mounted) {
      await ref.read(activeWorkoutProvider.notifier).discardWorkout();
      if (!mounted) return;

      final result = ref.read(activeWorkoutProvider);
      if (result.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to discard workout. Please retry.'),
          ),
        );
        return;
      }
      context.go('/home');
    }
  }

  Future<void> _onFinish() async {
    final notifier = ref.read(activeWorkoutProvider.notifier);
    final incompleteCount = notifier.incompleteSetsCount;

    final result = await FinishWorkoutDialog.show(
      context,
      incompleteCount: incompleteCount,
    );
    if (result == null || !mounted) return;

    // Capture exercise names before finishing (state is cleared after).
    final currentState = ref.read(activeWorkoutProvider).value;
    final exerciseNames = <String, String>{};
    if (currentState != null) {
      for (final e in currentState.exercises) {
        final ex = e.workoutExercise.exercise;
        if (ex != null) {
          exerciseNames[e.workoutExercise.exerciseId] = ex.name;
        }
      }
    }

    // Capture routine context before finishing (state is cleared after).
    // Look up the immutable routine name from the provider — workout.name
    // is mutable (user can rename mid-session).
    final routineId = currentState?.routineId;
    final routineName = routineId != null
        ? ref
              .read(routineListProvider)
              .value
              ?.where((r) => r.id == routineId)
              .firstOrNull
              ?.name
        : null;

    final prResult = await notifier.finishWorkout(notes: result.notes);
    if (!mounted) return;

    final state = ref.read(activeWorkoutProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save workout. Please retry.')),
      );
      return;
    }

    // Invalidate caches so stat cards and lists reflect the new workout.
    ref.invalidate(workoutHistoryProvider);
    ref.invalidate(workoutCountProvider);
    ref.invalidate(prListProvider);
    ref.invalidate(prCountProvider);
    ref.invalidate(recentPRsProvider);

    // Determine if we should prompt to add this routine to the plan.
    final shouldPrompt = _shouldShowPlanPrompt(routineId);

    // Navigate to PR celebration if there are new records, otherwise go home.
    if (prResult != null && prResult.hasNewRecords) {
      context.go(
        '/pr-celebration',
        extra: {
          'result': prResult,
          'exerciseNames': exerciseNames,
          if (shouldPrompt) 'planPromptRoutineId': routineId,
          if (shouldPrompt) 'planPromptRoutineName': routineName,
        },
      );
    } else if (shouldPrompt) {
      await _showPlanPromptAndGoHome(routineId!, routineName!);
    } else {
      context.go('/home');
    }
  }

  /// Whether to show the "Add to plan?" prompt after finishing.
  ///
  /// True when: the workout came from a routine, a plan exists for this week,
  /// and the routine is NOT already in the plan.
  bool _shouldShowPlanPrompt(String? routineId) {
    if (routineId == null) return false;
    final plan = ref.read(weeklyPlanProvider).value;
    if (plan == null) return false;
    return !plan.routines.any((r) => r.routineId == routineId);
  }

  /// Shows the add-to-plan prompt, then navigates home.
  Future<void> _showPlanPromptAndGoHome(
    String routineId,
    String routineName,
  ) async {
    final shouldAdd = await showAddToPlanPrompt(
      context,
      routineName: routineName,
    );
    if (!mounted) return;
    if (shouldAdd == true) {
      await ref.read(weeklyPlanProvider.notifier).addRoutineToPlan(routineId);
    }
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _onAddExercise() async {
    final exercise = await ExercisePickerSheet.show(context);
    if (exercise != null) {
      ref.read(activeWorkoutProvider.notifier).addExercise(exercise);
    }
  }

  void _toggleReorderMode() {
    setState(() => _reorderMode = !_reorderMode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: Semantics(
          label: 'Discard workout',
          child: IconButton(
            onPressed: _onBackPressed,
            icon: const Icon(Icons.close),
            tooltip: 'Discard workout',
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isEditingName)
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _nameController,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.sentences,
                  style: theme.textTheme.titleMedium,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: UnderlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                  onSubmitted: (_) => _submitName(),
                  onTapOutside: (_) => _submitName(),
                ),
              )
            else
              Semantics(
                label: '${widget.state.workout.name}. Tap to rename workout.',
                child: GestureDetector(
                  onTap: () {
                    _nameController.text = widget.state.workout.name;
                    setState(() => _isEditingName = true);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.state.workout.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            _ElapsedTimer(startedAt: widget.state.workout.startedAt),
          ],
        ),
        centerTitle: true,
        actions: [
          if (widget.state.exercises.length > 1)
            IconButton(
              onPressed: _toggleReorderMode,
              icon: Icon(_reorderMode ? Icons.done : Icons.swap_vert),
              tooltip: _reorderMode ? 'Exit reorder mode' : 'Reorder exercises',
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_hasCompletedSet)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Complete at least one set to finish',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: _hasCompletedSet ? _onFinish : null,
                icon: const Icon(Icons.check_circle),
                label: const Text('Finish Workout'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: widget.state.exercises.isEmpty
          ? _EmptyWorkoutBody(onAddExercise: _onAddExercise)
          : _ExerciseList(
              exercises: widget.state.exercises,
              onAddExercise: _onAddExercise,
              reorderMode: _reorderMode,
            ),
      floatingActionButton: widget.state.exercises.isNotEmpty
          ? _AddExerciseFab(onPressed: _onAddExercise)
          : null,
    );
  }
}

class _ElapsedTimer extends ConsumerWidget {
  const _ElapsedTimer({required this.startedAt});

  final DateTime startedAt;

  String _format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final elapsed = ref.watch(elapsedTimerProvider(startedAt));

    return Text(
      elapsed.when(
        data: _format,
        loading: () => '00:00',
        error: (_, _) => '00:00',
      ),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EmptyWorkoutBody extends StatelessWidget {
  const _EmptyWorkoutBody({required this.onAddExercise});

  final VoidCallback onAddExercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Add your first exercise',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to get started',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddExercise,
              icon: const Icon(Icons.add),
              label: const Text('Add Exercise'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseList extends StatelessWidget {
  const _ExerciseList({
    required this.exercises,
    required this.onAddExercise,
    required this.reorderMode,
  });

  final List<ActiveWorkoutExercise> exercises;
  final VoidCallback onAddExercise;
  final bool reorderMode;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88, top: 8),
      itemCount: exercises.length,
      itemBuilder: (context, index) => _ExerciseCard(
        activeExercise: exercises[index],
        reorderMode: reorderMode,
        isFirst: index == 0,
        isLast: index == exercises.length - 1,
      ),
    );
  }
}

class _ExerciseCard extends ConsumerStatefulWidget {
  const _ExerciseCard({
    required this.activeExercise,
    required this.reorderMode,
    required this.isFirst,
    required this.isLast,
  });

  final ActiveWorkoutExercise activeExercise;
  final bool reorderMode;
  final bool isFirst;
  final bool isLast;

  @override
  ConsumerState<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends ConsumerState<_ExerciseCard> {
  /// IDs of sets that were just added and should receive the isNew flag.
  final Set<String> _newSetIds = {};

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Exercise?'),
        content: Text(
          'Remove ${widget.activeExercise.workoutExercise.exercise?.name ?? 'this exercise'} '
          'and all its sets?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref
          .read(activeWorkoutProvider.notifier)
          .removeExercise(widget.activeExercise.workoutExercise.id);
    }
  }

  Future<void> _swapExercise(BuildContext context) async {
    final exercise = await ExercisePickerSheet.show(context);
    if (exercise != null) {
      ref
          .read(activeWorkoutProvider.notifier)
          .swapExercise(widget.activeExercise.workoutExercise.id, exercise);
    }
  }

  void _onSetCompleted() {
    final restSeconds = widget.activeExercise.workoutExercise.restSeconds ?? 90;
    final exerciseName = widget.activeExercise.workoutExercise.exercise?.name;
    ref
        .read(restTimerProvider.notifier)
        .start(restSeconds, exerciseName: exerciseName);
  }

  void _fillRemaining(BuildContext context) {
    ref
        .read(activeWorkoutProvider.notifier)
        .fillRemainingSets(widget.activeExercise.workoutExercise.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filled remaining sets'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Returns true when there are incomplete sets after the last completed set.
  /// The fill-remaining action only affects those sets, so the button should
  /// be hidden when there is nothing to fill.
  bool _hasFillableSets(List<ExerciseSet> sets) {
    final lastCompletedNumber = sets
        .where((s) => s.isCompleted)
        .fold<int>(0, (max, s) => s.setNumber > max ? s.setNumber : max);
    if (lastCompletedNumber == 0) return false;
    return sets.any((s) => !s.isCompleted && s.setNumber > lastCompletedNumber);
  }

  void _showExerciseDetail(BuildContext context, Exercise exercise) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExerciseDetailSheet(exercise: exercise),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeExercise = widget.activeExercise;
    final exercise = activeExercise.workoutExercise.exercise;
    final weId = activeExercise.workoutExercise.id;
    final exerciseId = activeExercise.workoutExercise.exerciseId;

    // Fetch previous session sets for this exercise.
    final lastSetsAsync = ref.watch(lastWorkoutSetsProvider(exerciseId));
    final lastSetsMap = lastSetsAsync.value ?? {};
    final lastSets = lastSetsMap[exerciseId] ?? [];

    // Get weight unit for equipment-type defaults.
    final weightUnitStr = ref.watch(profileProvider).value?.weightUnit ?? 'kg';
    final weightUnit = WeightUnit.fromString(weightUnitStr);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: name + info icon + reorder/delete buttons
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label:
                        'Exercise: ${exercise?.name ?? 'Exercise'}. '
                        'Tap for details. Long press to swap.',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: exercise != null
                          ? () => _showExerciseDetail(context, exercise)
                          : null,
                      onLongPress: () => _swapExercise(context),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  exercise?.name ?? 'Exercise',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.reorderMode) ...[
                  Semantics(
                    label: 'Move exercise up',
                    child: IconButton(
                      onPressed: widget.isFirst
                          ? null
                          : () => ref
                                .read(activeWorkoutProvider.notifier)
                                .reorderExercise(weId, -1),
                      icon: const Icon(Icons.arrow_upward),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      tooltip: 'Move up',
                    ),
                  ),
                  Semantics(
                    label: 'Move exercise down',
                    child: IconButton(
                      onPressed: widget.isLast
                          ? null
                          : () => ref
                                .read(activeWorkoutProvider.notifier)
                                .reorderExercise(weId, 1),
                      icon: const Icon(Icons.arrow_downward),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      tooltip: 'Move down',
                    ),
                  ),
                ] else ...[
                  Semantics(
                    label: 'Swap exercise',
                    child: IconButton(
                      onPressed: () => _swapExercise(context),
                      icon: Icon(
                        Icons.swap_horiz,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      tooltip: 'Swap exercise',
                    ),
                  ),
                  Semantics(
                    label: 'Remove exercise',
                    child: IconButton(
                      onPressed: () => _confirmRemove(context),
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error.withValues(alpha: 0.7),
                      ),
                      tooltip: 'Remove exercise',
                    ),
                  ),
                ],
              ],
            ),

            if (activeExercise.sets.isNotEmpty) ...[
              const SizedBox(height: 8),

              // Column headers
              _SetColumnHeaders(theme: theme),
              const Divider(height: 1),

              // Set rows
              ...activeExercise.sets.indexed.map((entry) {
                final (index, s) = entry;
                // Match by position: set 1 maps to lastSets[0], etc.
                final lastSet = index < lastSets.length
                    ? lastSets[index]
                    : null;
                final isNew = _newSetIds.contains(s.id);
                return SetRow(
                  key: ValueKey(s.id),
                  set: s,
                  workoutExerciseId: weId,
                  onCompleted: _onSetCompleted,
                  lastSet: lastSet,
                  isNew: isNew,
                );
              }),
            ],

            // Add set + fill remaining
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: OutlinedButton.icon(
                onPressed: () {
                  // Smart defaults priority chain:
                  // 1. Previous session set at matching position
                  // 2. Last set in current session (skip warmup->working)
                  // 3. Equipment-type defaults
                  // 4. 0/0
                  final newSetIndex = activeExercise.sets.length;
                  double? defaultWeight;
                  int? defaultReps;

                  // Priority 1: previous session at matching position
                  final lastSetForNewRow = newSetIndex < lastSets.length
                      ? lastSets[newSetIndex]
                      : null;

                  if (lastSetForNewRow != null) {
                    defaultWeight = lastSetForNewRow.weight ?? 0;
                    defaultReps = lastSetForNewRow.reps ?? 0;
                  } else if (activeExercise.sets.isNotEmpty) {
                    // Priority 2: last set in current session (not just
                    // last completed — always copy from the most recent set
                    // so weight is never lost).
                    final prevSet = activeExercise.sets.last;
                    // Skip if previous set is warmup (new set defaults to
                    // working, so don't carry warmup weights forward).
                    if (prevSet.setType != SetType.warmup) {
                      defaultWeight = prevSet.weight ?? 0;
                      defaultReps = prevSet.reps ?? 0;
                    } else {
                      // Warmup -> working: use equipment defaults
                      final equipType = exercise?.equipmentType;
                      if (equipType != null) {
                        final defaults = defaultSetValues(
                          equipType,
                          weightUnit,
                        );
                        defaultWeight = defaults.weight;
                        defaultReps = defaults.reps;
                      }
                    }
                  } else {
                    // Priority 3: equipment-type defaults for first-ever set
                    final equipType = exercise?.equipmentType;
                    if (equipType != null) {
                      final defaults = defaultSetValues(equipType, weightUnit);
                      defaultWeight = defaults.weight;
                      defaultReps = defaults.reps;
                    }
                  }

                  // Record the current set count before adding.
                  final setCountBefore = activeExercise.sets.length;
                  ref
                      .read(activeWorkoutProvider.notifier)
                      .addSet(
                        weId,
                        defaultWeight: defaultWeight,
                        defaultReps: defaultReps,
                      );

                  // Mark the newly added set as new after state updates.
                  // The notifier adds the set synchronously, so we can
                  // read back the updated state to find the new set ID.
                  final updated = ref.read(activeWorkoutProvider).value;
                  if (updated != null) {
                    final updatedExercise = updated.exercises
                        .where((e) => e.workoutExercise.id == weId)
                        .firstOrNull;
                    if (updatedExercise != null &&
                        updatedExercise.sets.length > setCountBefore) {
                      setState(() {
                        _newSetIds.add(updatedExercise.sets.last.id);
                      });
                      // Clear after the frame so SetRow.initState captures isNew
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _newSetIds.remove(updatedExercise.sets.last.id);
                      });
                    }
                  }
                },
                onLongPress: () => _fillRemaining(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Set'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            // Show "Fill remaining" only when there are incomplete sets
            // after the last completed set — otherwise the button does
            // nothing and confuses users (BUG-3).
            if (_hasFillableSets(activeExercise.sets))
              Center(
                child: Semantics(
                  label: 'Fill remaining sets with last completed values',
                  child: TextButton(
                    onPressed: () => _fillRemaining(context),
                    child: Text(
                      'Fill remaining',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SetColumnHeaders extends StatelessWidget {
  const _SetColumnHeaders({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('SET', style: style)),
          Expanded(
            flex: 3,
            child: Text('WEIGHT', style: style, textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 2,
            child: Text('REPS', style: style, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _AddExerciseFab extends StatelessWidget {
  const _AddExerciseFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Add exercise to workout',
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
          label: const Text('Add Exercise'),
        ),
      ),
    );
  }
}

/// Bottom sheet that shows exercise details (name, muscle group, equipment,
/// images, PRs) without navigating away from the active workout screen.
class _ExerciseDetailSheet extends ConsumerWidget {
  const _ExerciseDetailSheet({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncRecords = ref.watch(exercisePRsProvider(exercise.id));
    final weightUnit = ref.watch(profileProvider).value?.weightUnit ?? 'kg';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  // Exercise name
                  Text(exercise.name, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  // Muscle group + equipment chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SheetChip(
                        icon: exercise.muscleGroup.icon,
                        label: exercise.muscleGroup.displayName,
                      ),
                      _SheetChip(
                        icon: exercise.equipmentType.icon,
                        label: exercise.equipmentType.displayName,
                      ),
                    ],
                  ),
                  // Images
                  if (exercise.imageStartUrl != null ||
                      exercise.imageEndUrl != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 160,
                      child: Row(
                        children: [
                          if (exercise.imageStartUrl != null)
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ExerciseImage(
                                      imageUrl: exercise.imageStartUrl,
                                      fallbackIcon: exercise.muscleGroup.icon,
                                      height: 136,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Start',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (exercise.imageStartUrl != null &&
                              exercise.imageEndUrl != null)
                            const SizedBox(width: 8),
                          if (exercise.imageEndUrl != null)
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ExerciseImage(
                                      imageUrl: exercise.imageEndUrl,
                                      fallbackIcon: exercise.muscleGroup.icon,
                                      height: 136,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'End',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  ExerciseDescriptionSection(description: exercise.description),
                  ExerciseFormTipsSection(formTips: exercise.formTips),
                  const SizedBox(height: 24),
                  // Personal records
                  _SheetPRSection(
                    asyncRecords: asyncRecords,
                    equipmentType: exercise.equipmentType,
                    weightUnit: weightUnit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurface),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetPRSection extends StatelessWidget {
  const _SheetPRSection({
    required this.asyncRecords,
    required this.equipmentType,
    required this.weightUnit,
  });

  final AsyncValue<List<PersonalRecord>> asyncRecords;
  final EquipmentType equipmentType;
  final String weightUnit;

  String _formatValue(RecordType type, double value) {
    return switch (type) {
      RecordType.maxWeight => '$value $weightUnit',
      RecordType.maxReps => '${value.toInt()} reps',
      RecordType.maxVolume => '$value $weightUnit',
    };
  }

  IconData _iconForType(RecordType type) {
    return switch (type) {
      RecordType.maxWeight => Icons.fitness_center,
      RecordType.maxReps => Icons.repeat,
      RecordType.maxVolume => Icons.bar_chart,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return asyncRecords.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => _emptyRow(theme),
      data: (records) {
        if (records.isEmpty) return _emptyRow(theme);

        // For bodyweight exercises, skip maxWeight and maxVolume.
        final filtered = equipmentType == EquipmentType.bodyweight
            ? records.where((r) => r.recordType == RecordType.maxReps).toList()
            : records;

        if (filtered.isEmpty) return _emptyRow(theme);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal Records', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...filtered.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _iconForType(r.recordType),
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      r.recordType.displayName,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Text(
                      _formatValue(r.recordType, r.value),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyRow(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.emoji_events_rounded,
          size: 20,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 4),
        Text(
          'No records yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
