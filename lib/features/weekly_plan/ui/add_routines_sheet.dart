import 'package:flutter/material.dart';

import '../../../core/theme/radii.dart';
import '../../../l10n/app_localizations.dart';
import '../../routines/models/routine.dart';

/// Bottom sheet for selecting routines to add to the weekly bucket.
///
/// Multi-select with checkmarks. Routines already in the plan are shown
/// as non-selectable with "IN PLAN" label.
class AddRoutinesSheet extends StatefulWidget {
  const AddRoutinesSheet({
    required this.availableRoutines,
    required this.inPlanIds,
    super.key,
  });

  /// Routines not already in the bucket.
  final List<Routine> availableRoutines;

  /// IDs of routines already in the plan (shown as non-selectable).
  final Set<String> inPlanIds;

  @override
  State<AddRoutinesSheet> createState() => _AddRoutinesSheetState();
}

class _AddRoutinesSheetState extends State<AddRoutinesSheet> {
  final _selected = <Routine>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar.
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Semantics(
                    container: true,
                    identifier: 'weekly-plan-add-sheet-title',
                    child: Text(
                      l10n.addRoutinesSheet,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const Spacer(),
                  if (widget.availableRoutines.isEmpty)
                    Text(
                      l10n.allRoutinesInPlan,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.availableRoutines.isEmpty
                  ? Center(
                      child: Text(
                        l10n.createMoreRoutines,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: widget.availableRoutines.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final routine = widget.availableRoutines[index];
                        final isSelected = _selected.contains(routine);

                        return _RoutineSelectTile(
                          routine: routine,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selected.remove(routine);
                              } else {
                                _selected.add(routine);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            // Add button.
            if (_selected.isNotEmpty)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Semantics(
                      container: true,
                      identifier: 'weekly-plan-add-confirm',
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.of(context).pop(_selected.toList()),
                        child: Text(l10n.addCountRoutines(_selected.length)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RoutineSelectTile extends StatelessWidget {
  const _RoutineSelectTile({
    required this.routine,
    required this.isSelected,
    required this.onTap,
  });

  final Routine routine;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l10n.exercisesCount(routine.exercises.length),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: theme.colorScheme.primary)
                else
                  Icon(
                    Icons.circle_outlined,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
