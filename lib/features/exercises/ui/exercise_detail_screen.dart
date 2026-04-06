import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../shared/widgets/exercise_image.dart';
import '../../personal_records/models/record_type.dart';
import '../../personal_records/providers/pr_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../models/exercise.dart';
import '../providers/exercise_providers.dart'
    show deleteExercise, exerciseByIdProvider;

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  bool _isDeleting = false;

  Future<void> _deleteExercise(Exercise exercise) async {
    final userId = exercise.userId;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogTheme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: dialogTheme.cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Delete Exercise'),
          content: Text('Are you sure you want to delete "${exercise.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: dialogTheme.colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await deleteExercise(ref, exercise.id, userId: userId);
      if (mounted) context.pop();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncExercise = ref.watch(exerciseByIdProvider(widget.exerciseId));

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Details')),
      body: asyncExercise.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load exercise', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(exerciseByIdProvider(widget.exerciseId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (exercise) => _ExerciseDetailBody(
          exercise: exercise,
          isDeleting: _isDeleting,
          onDelete: exercise.isDefault ? null : () => _deleteExercise(exercise),
        ),
      ),
    );
  }
}

class _ExerciseDetailBody extends ConsumerWidget {
  const _ExerciseDetailBody({
    required this.exercise,
    required this.isDeleting,
    this.onDelete,
  });

  final Exercise exercise;
  final bool isDeleting;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final dateFormat = DateFormat.yMMMMd();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.name, style: theme.textTheme.headlineLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DetailChip(
                icon: exercise.muscleGroup.icon,
                label: exercise.muscleGroup.displayName,
              ),
              _DetailChip(
                icon: exercise.equipmentType.icon,
                label: exercise.equipmentType.displayName,
              ),
            ],
          ),
          if (exercise.imageStartUrl != null ||
              exercise.imageEndUrl != null) ...[
            const SizedBox(height: 16),
            _ExerciseImageRow(exercise: exercise),
          ],
          const SizedBox(height: 16),
          Text(
            'Created ${dateFormat.format(exercise.createdAt)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (!exercise.isDefault) ...[
            const SizedBox(height: 8),
            Text(
              'Custom exercise',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: primary.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _PRSection(
            exerciseId: exercise.id,
            equipmentType: exercise.equipmentType,
          ),
          if (onDelete != null) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: 'Delete exercise',
                child: OutlinedButton.icon(
                  onPressed: isDeleting ? null : onDelete,
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  label: Text(isDeleting ? 'Deleting...' : 'Delete Exercise'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

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

class _ExerciseImageRow extends StatelessWidget {
  const _ExerciseImageRow({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
    );

    return SizedBox(
      height: 160,
      child: Row(
        children: [
          if (exercise.imageStartUrl != null)
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _TappableImage(
                      imageUrl: exercise.imageStartUrl,
                      label: '${exercise.name} start position',
                      fallbackIcon: exercise.muscleGroup.icon,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Start', style: labelStyle),
                ],
              ),
            ),
          if (exercise.imageStartUrl != null && exercise.imageEndUrl != null)
            const SizedBox(width: 8),
          if (exercise.imageEndUrl != null)
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _TappableImage(
                      imageUrl: exercise.imageEndUrl,
                      label: '${exercise.name} end position',
                      fallbackIcon: exercise.muscleGroup.icon,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('End', style: labelStyle),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PRSection extends ConsumerWidget {
  const _PRSection({required this.exerciseId, required this.equipmentType});

  final String exerciseId;
  final EquipmentType equipmentType;

  String _formatValue(RecordType type, double value, String weightUnit) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncRecords = ref.watch(exercisePRsProvider(exerciseId));
    final weightUnit =
        ref.watch(profileProvider).valueOrNull?.weightUnit ?? 'kg';

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
      error: (_, _) => _emptyPRRow(theme),
      data: (records) {
        if (records.isEmpty) return _emptyPRRow(theme);

        // For bodyweight exercises, skip maxWeight and maxVolume if absent.
        final filtered = equipmentType == EquipmentType.bodyweight
            ? records.where((r) => r.recordType == RecordType.maxReps).toList()
            : records;

        if (filtered.isEmpty) return _emptyPRRow(theme);

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
                      _formatValue(r.recordType, r.value, weightUnit),
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

  Widget _emptyPRRow(ThemeData theme) {
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

class _TappableImage extends StatelessWidget {
  const _TappableImage({
    required this.imageUrl,
    required this.label,
    required this.fallbackIcon,
  });

  final String? imageUrl;
  final String label;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      image: true,
      child: GestureDetector(
        onTap: imageUrl != null
            ? () => _showFullScreen(context, imageUrl!, label, fallbackIcon)
            : null,
        child: ExerciseImage(
          imageUrl: imageUrl,
          fallbackIcon: fallbackIcon,
          height: 136,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static void _showFullScreen(
    BuildContext context,
    String imageUrl,
    String label,
    IconData fallbackIcon,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Scaffold(
        backgroundColor: Theme.of(ctx).colorScheme.scrim,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(),
            tooltip: 'Close',
          ),
        ),
        body: GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Semantics(
              label: label,
              image: true,
              child: ExerciseImage(
                imageUrl: imageUrl,
                fallbackIcon: fallbackIcon,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
