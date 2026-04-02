import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../shared/widgets/exercise_image.dart';
import '../models/exercise.dart';
import '../providers/exercise_providers.dart'
    show exerciseListProvider, exerciseRepositoryProvider;

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  late Future<Exercise> _exerciseFuture;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _exerciseFuture = ref
        .read(exerciseRepositoryProvider)
        .getExerciseById(widget.exerciseId);
  }

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
      await ref
          .read(exerciseRepositoryProvider)
          .softDeleteExercise(exercise.id, userId: userId);
      ref.invalidate(exerciseListProvider);
      if (mounted) context.pop();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Details')),
      body: FutureBuilder<Exercise>(
        future: _exerciseFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load exercise',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          final exercise = snapshot.data!;
          return _ExerciseDetailBody(
            exercise: exercise,
            isDeleting: _isDeleting,
            onDelete: exercise.isDefault
                ? null
                : () => _deleteExercise(exercise),
          );
        },
      ),
    );
  }
}

class _ExerciseDetailBody extends StatelessWidget {
  const _ExerciseDetailBody({
    required this.exercise,
    required this.isDeleting,
    this.onDelete,
  });

  final Exercise exercise;
  final bool isDeleting;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Text(
                'Personal records & workout history coming soon',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
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
