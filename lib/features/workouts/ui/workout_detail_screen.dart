import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/workout_formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../personal_records/providers/pr_providers.dart';
import '../../profile/providers/profile_providers.dart';
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

    final l10n = AppLocalizations.of(context);
    return asyncDetail.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.workout)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.failedToLoadWorkout,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(workoutDetailProvider(workoutId)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
      data: (detail) => Scaffold(body: _WorkoutDetailBody(detail: detail)),
    );
  }
}

class _WorkoutDetailBody extends ConsumerWidget {
  const _WorkoutDetailBody({required this.detail});

  final WorkoutDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final workout = detail.workout;
    final weightUnit = ref.watch(profileProvider).value?.weightUnit ?? 'kg';
    final locale = Localizations.localeOf(context).toString();
    final dateText = WorkoutFormatters.formatWorkoutDate(
      workout.finishedAt ?? workout.startedAt,
      l10n: l10n,
      locale: locale,
    );
    final durationText = WorkoutFormatters.formatDuration(
      workout.durationSeconds,
      l10n: l10n,
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
            return _ReadOnlyExerciseCard(
              exercise: exercise,
              sets: sets,
              workoutId: detail.workout.id,
              weightUnit: weightUnit,
            );
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
                      Text(l10n.notes, style: theme.textTheme.titleMedium),
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
                  l10n.totalVolume(
                    WorkoutFormatters.formatVolume(
                      totalVolume,
                      weightUnit: weightUnit,
                      locale: locale,
                    ),
                  ),
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

class _ReadOnlyExerciseCard extends ConsumerWidget {
  const _ReadOnlyExerciseCard({
    required this.exercise,
    required this.sets,
    required this.workoutId,
    required this.weightUnit,
  });

  final WorkoutExercise exercise;
  final List<ExerciseSet> sets;
  final String workoutId;
  final String weightUnit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final prSetIds = ref.watch(workoutPRSetIdsProvider(workoutId)).value ?? {};

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.exercise?.name ?? l10n.exerciseGeneric,
              style: theme.textTheme.titleMedium,
            ),
            if (sets.isNotEmpty) ...[
              const SizedBox(height: 12),
              // Column headers
              _SetColumnHeaders(theme: theme),
              const Divider(height: 1),
              ...sets.map(
                (s) => _ReadOnlySetRow(
                  set: s,
                  isPR: prSetIds.contains(s.id),
                  weightUnit: weightUnit,
                ),
              ),
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
    final l10n = AppLocalizations.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(l10n.setColumnSet, style: style)),
          Expanded(
            child: Text(
              l10n.setColumnWeight,
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              l10n.setColumnReps,
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              l10n.setColumnType,
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlySetRow extends StatelessWidget {
  const _ReadOnlySetRow({
    required this.set,
    required this.weightUnit,
    this.isPR = false,
  });

  final ExerciseSet set;
  final bool isPR;
  final String weightUnit;

  String _typeLabel(AppLocalizations l10n) => switch (set.setType) {
    SetType.working => l10n.setTypeAbbrWorking,
    SetType.warmup => l10n.setTypeAbbrWarmupShort,
    SetType.dropset => l10n.setTypeAbbrDropset,
    SetType.failure => l10n.setTypeAbbrFailure,
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
            child: isPR
                ? const Icon(
                    Icons.emoji_events,
                    size: 18,
                    color: AppTheme.prBadgeColor,
                  )
                : Text(
                    '${set.setNumber}.',
                    style: textStyle?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
          ),
          Expanded(
            child: Text(
              '${set.weight?.toStringAsFixed(set.weight == set.weight?.roundToDouble() ? 0 : 1) ?? '-'} $weightUnit',
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
                  _typeLabel(AppLocalizations.of(context)),
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
