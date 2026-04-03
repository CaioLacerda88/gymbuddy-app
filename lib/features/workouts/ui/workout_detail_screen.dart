import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/workout_formatters.dart';
import '../data/workout_repository.dart';
import '../models/exercise_set.dart';
import '../models/set_type.dart';
import '../models/workout_exercise.dart';
import '../providers/workout_history_providers.dart';

/// Read-only detail view of a completed workout.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({required this.workoutId, super.key});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(workoutDetailProvider(workoutId));

    return asyncDetail.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to load workout',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(workoutDetailProvider(workoutId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (detail) => Scaffold(body: _WorkoutDetailBody(detail: detail)),
    );
  }
}

class _WorkoutDetailBody extends StatelessWidget {
  const _WorkoutDetailBody({required this.detail});

  final WorkoutDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workout = detail.workout;
    final dateText = WorkoutFormatters.formatWorkoutDate(
      workout.finishedAt ?? workout.startedAt,
    );
    final durationText = WorkoutFormatters.formatDuration(
      workout.durationSeconds,
    );

    // Calculate total volume across all exercises.
    final allSets = detail.setsByExercise.values.expand((s) => s).toList();
    final totalVolume = WorkoutFormatters.calculateVolume(allSets);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(workout.name),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '$dateText  ·  $durationText',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
        // Exercise cards
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final exercise = detail.exercises[index];
            final sets = detail.setsByExercise[exercise.id] ?? [];
            return _ReadOnlyExerciseCard(exercise: exercise, sets: sets);
          }, childCount: detail.exercises.length),
        ),
        // Notes section
        if (workout.notes != null && workout.notes!.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notes', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        workout.notes!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Total volume footer
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Total Volume: ${WorkoutFormatters.formatVolume(totalVolume)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyExerciseCard extends StatelessWidget {
  const _ReadOnlyExerciseCard({required this.exercise, required this.sets});

  final WorkoutExercise exercise;
  final List<ExerciseSet> sets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.exercise?.name ?? 'Exercise',
              style: theme.textTheme.titleMedium,
            ),
            if (sets.isNotEmpty) ...[
              const SizedBox(height: 12),
              // Column headers
              _SetColumnHeaders(theme: theme),
              const Divider(height: 1),
              ...sets.map((s) => _ReadOnlySetRow(set: s)),
            ],
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
            child: Text('WEIGHT', style: style, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text('REPS', style: style, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 48,
            child: Text('TYPE', style: style, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlySetRow extends StatelessWidget {
  const _ReadOnlySetRow({required this.set});

  final ExerciseSet set;

  String get _typeLabel => switch (set.setType) {
    SetType.working => 'W',
    SetType.warmup => 'Wu',
    SetType.dropset => 'D',
    SetType.failure => 'F',
  };

  Color _typeColor(ThemeData theme) => switch (set.setType) {
    SetType.working => theme.colorScheme.primary,
    SetType.warmup => theme.colorScheme.secondary,
    SetType.dropset => theme.colorScheme.tertiary,
    SetType.failure => theme.colorScheme.error,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${set.setNumber}.',
              style: textStyle?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${set.weight?.toStringAsFixed(set.weight == set.weight?.roundToDouble() ? 0 : 1) ?? '-'} kg',
              style: textStyle,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '${set.reps ?? '-'}',
              style: textStyle,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 48,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _typeColor(theme).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _typeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _typeColor(theme),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
