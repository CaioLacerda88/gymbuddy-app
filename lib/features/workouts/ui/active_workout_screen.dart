import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/exercise_image.dart';
import '../models/active_workout_state.dart';
import '../providers/workout_providers.dart';
import 'widgets/discard_workout_dialog.dart';
import 'widgets/exercise_picker_sheet.dart';
import 'widgets/set_row.dart';

/// Full-screen active workout experience.
///
/// Displayed outside the shell route (no bottom nav). Watches
/// [activeWorkoutProvider] and renders exercise cards with sets.
class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(activeWorkoutProvider);

    // Use previousData to keep showing the workout while saving/discarding.
    final currentState = asyncState.valueOrNull;
    final previousState = asyncState.whenData((v) => v).valueOrNull;
    final displayState = currentState ?? previousState;

    if (displayState == null && !asyncState.isLoading) {
      // Workout was finished or discarded — navigate home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/home');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (displayState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Stack(
      children: [
        _ActiveWorkoutBody(state: displayState),
        if (asyncState.isLoading)
          const ModalBarrier(dismissible: false, color: Colors.black54),
        if (asyncState.isLoading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ActiveWorkoutBody extends ConsumerWidget {
  const _ActiveWorkoutBody({required this.state});

  final ActiveWorkoutState state;

  bool get _hasCompletedSet =>
      state.exercises.any((e) => e.sets.any((s) => s.isCompleted));

  Future<void> _onBackPressed(BuildContext context, WidgetRef ref) async {
    final elapsed = DateTime.now().toUtc().difference(state.workout.startedAt);
    final shouldDiscard = await DiscardWorkoutDialog.show(
      context,
      elapsedDuration: elapsed,
    );
    if (shouldDiscard == true && context.mounted) {
      await ref.read(activeWorkoutProvider.notifier).discardWorkout();
      if (context.mounted) context.go('/home');
    }
  }

  Future<void> _onFinish(BuildContext context, WidgetRef ref) async {
    await ref.read(activeWorkoutProvider.notifier).finishWorkout();
    if (!context.mounted) return;

    final result = ref.read(activeWorkoutProvider);
    if (result.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save workout. Please retry.')),
      );
      return;
    }
    context.go('/home');
  }

  Future<void> _onAddExercise(BuildContext context, WidgetRef ref) async {
    final exercise = await ExercisePickerSheet.show(context);
    if (exercise != null) {
      ref.read(activeWorkoutProvider.notifier).addExercise(exercise);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackPressed(context, ref);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => _onBackPressed(context, ref),
            icon: const Icon(Icons.close),
            tooltip: 'Discard workout',
          ),
          title: Column(
            children: [
              Text(state.workout.name, style: theme.textTheme.titleMedium),
              _ElapsedTimer(startedAt: state.workout.startedAt),
            ],
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _hasCompletedSet
                    ? () => _onFinish(context, ref)
                    : null,
                child: const Text('Finish'),
              ),
            ),
          ],
        ),
        body: state.exercises.isEmpty
            ? _EmptyWorkoutBody(
                onAddExercise: () => _onAddExercise(context, ref),
              )
            : _ExerciseList(
                exercises: state.exercises,
                onAddExercise: () => _onAddExercise(context, ref),
              ),
        floatingActionButton: state.exercises.isNotEmpty
            ? _AddExerciseFab(onPressed: () => _onAddExercise(context, ref))
            : null,
      ),
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
  const _ExerciseList({required this.exercises, required this.onAddExercise});

  final List<ActiveWorkoutExercise> exercises;
  final VoidCallback onAddExercise;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88, top: 8),
      itemCount: exercises.length,
      itemBuilder: (context, index) =>
          _ExerciseCard(activeExercise: exercises[index]),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({required this.activeExercise});

  final ActiveWorkoutExercise activeExercise;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Exercise?'),
        content: Text(
          'Remove ${activeExercise.workoutExercise.exercise?.name ?? 'this exercise'} '
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
          .removeExercise(activeExercise.workoutExercise.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final exercise = activeExercise.workoutExercise.exercise;
    final weId = activeExercise.workoutExercise.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: image + name + delete button
            Row(
              children: [
                if (exercise?.imageStartUrl != null) ...[
                  ExerciseImage(
                    imageUrl: exercise!.imageStartUrl,
                    fallbackIcon: Icons.fitness_center,
                    width: 40,
                    height: 40,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    exercise?.name ?? 'Exercise',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Semantics(
                  label: 'Remove exercise',
                  child: IconButton(
                    onPressed: () => _confirmRemove(context, ref),
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error.withValues(alpha: 0.7),
                    ),
                    tooltip: 'Remove exercise',
                  ),
                ),
              ],
            ),

            if (activeExercise.sets.isNotEmpty) ...[
              const SizedBox(height: 8),

              // Column headers
              _SetColumnHeaders(theme: theme),
              const Divider(height: 1),

              // Set rows
              ...activeExercise.sets.map(
                (s) => SetRow(
                  key: ValueKey(s.id),
                  set: s,
                  workoutExerciseId: weId,
                ),
              ),
            ],

            // Add set button
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(activeWorkoutProvider.notifier).addSet(weId),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Set'),
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
          SizedBox(width: 28, child: Text('SET', style: style)),
          SizedBox(width: 36, child: Text('TYPE', style: style)),
          const SizedBox(width: 4),
          Expanded(
            child: Text('WEIGHT', style: style, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 140,
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
