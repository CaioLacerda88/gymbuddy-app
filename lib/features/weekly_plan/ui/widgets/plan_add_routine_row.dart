import 'package:flutter/material.dart';

import '../../../../core/theme/radii.dart';
import '../../../../l10n/app_localizations.dart';

/// Bordered "Add routine" tap target rendered at the bottom of the
/// reorderable bucket list.
///
/// Visually de-emphasises itself when [atSoftCap] is true (the user has
/// already planned as many routines as their training frequency target),
/// but stays tappable so users can still add overflow routines if they
/// want to. Below the tap target, a small helper line shows the current
/// "X / N planned this week" or "N / N planned -- ready to go" copy.
class PlanAddRoutineRow extends StatelessWidget {
  const PlanAddRoutineRow({
    required super.key,
    required this.atSoftCap,
    required this.bucketCount,
    required this.trainingFrequency,
    required this.onTap,
  });

  final bool atSoftCap;
  final int bucketCount;
  final int trainingFrequency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(kRadiusMd),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: atSoftCap ? 0.1 : 0.2,
                    ),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: atSoftCap ? 0.3 : 0.55,
                      ),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      container: true,
                      identifier: 'weekly-plan-add-routine-row',
                      child: Text(
                        l10n.addRoutine,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: atSoftCap ? 0.3 : 0.55,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              atSoftCap
                  ? l10n.plannedReadyToGo(trainingFrequency, trainingFrequency)
                  : l10n.plannedThisWeek(bucketCount, trainingFrequency),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
