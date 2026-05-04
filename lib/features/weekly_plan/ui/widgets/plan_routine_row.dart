import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/radii.dart';
import '../../../../l10n/app_localizations.dart';

/// A single routine row inside the reorderable bucket on the plan
/// management screen.
///
/// Renders the sequence number (or a green check when the routine has
/// already been completed this week), the routine name + exercise count,
/// and a drag handle for reordering. Pending (non-completed) rows are
/// wrapped in a [Dismissible] so the user can swipe-to-remove; completed
/// rows are not dismissible. The owning [ReorderableListView] handles
/// reorder semantics, so [index] must match the list index.
class PlanRoutineRow extends StatelessWidget {
  const PlanRoutineRow({
    required super.key,
    required this.index,
    required this.routineId,
    required this.sequenceNumber,
    required this.name,
    required this.exerciseCount,
    required this.isDone,
    this.onDismissed,
  });

  final int index;
  final String routineId;
  final int sequenceNumber;
  final String name;
  final int exerciseCount;
  final bool isDone;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Use the theme primary color (M3 green) instead of a hardcoded hex so
    // future brand/theme changes propagate here automatically.
    final primary = theme.colorScheme.primary;

    final content = Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDone
            ? primary.withValues(alpha: 0.08)
            : theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Row(
        children: [
          // Sequence number or checkmark.
          if (isDone)
            Icon(Icons.check_circle, color: primary, size: 24)
          else
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$sequenceNumber',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 12),
          // Name and exercise count.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDone ? primary : null,
                  ),
                ),
                Text(
                  l10n.exercisesCount(exerciseCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          // Drag handle (only for non-completed).
          if (!isDone)
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
        ],
      ),
    );

    if (isDone || onDismissed == null) return content;

    return Dismissible(
      key: ValueKey('dismiss-$routineId'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        child: const Icon(Icons.delete, color: AppColors.textCream),
      ),
      child: content,
    );
  }
}
