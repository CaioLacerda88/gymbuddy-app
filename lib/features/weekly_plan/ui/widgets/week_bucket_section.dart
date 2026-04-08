import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routines/models/routine.dart';
import '../../../routines/providers/notifiers/routine_list_notifier.dart';
import '../../../routines/ui/start_routine_action.dart';
import '../../data/models/weekly_plan.dart';
import '../../providers/suggested_next_provider.dart';
import '../../providers/week_review_stats_provider.dart';
import '../../providers/weekly_plan_provider.dart';
import 'routine_chip.dart';
import 'week_review_section.dart';

/// The THIS WEEK section on the Home screen.
///
/// Displays an ordered row of routine chips showing bucket progress.
/// Transforms to WEEK COMPLETE when all routines are done.
/// Hidden when user has no routines at all.
class WeekBucketSection extends ConsumerWidget {
  const WeekBucketSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(weeklyPlanProvider);
    final routinesAsync = ref.watch(routineListProvider);
    final needsConfirmation = ref.watch(weeklyPlanNeedsConfirmationProvider);

    return planAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (plan) {
        final routines = routinesAsync.valueOrNull ?? [];
        if (routines.isEmpty) return const SizedBox.shrink();

        // Build routine name map from available routines.
        final routineMap = <String, Routine>{for (final r in routines) r.id: r};
        final nameMap = <String, String>{
          for (final r in routines) r.id: r.name,
        };

        // No plan set yet — show "Plan your week" CTA.
        if (plan == null || plan.routines.isEmpty) {
          return _EmptyBucketState(hasRoutines: routines.isNotEmpty);
        }

        // Check if week is complete.
        final isComplete = ref.watch(isWeekCompleteProvider);
        if (isComplete) {
          final stats = ref.watch(weekReviewStatsProvider).valueOrNull;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: WeekReviewSection(
              plan: plan,
              routineNames: nameMap,
              totalVolume: stats?.totalVolume ?? 0,
              prCount: stats?.prCount ?? 0,
              onNewWeek: () => _startNewWeek(context, ref),
            ),
          );
        }

        // Active week — show bucket section.
        return _ActiveBucketSection(
          plan: plan,
          routineMap: routineMap,
          nameMap: nameMap,
          needsConfirmation: needsConfirmation,
        );
      },
    );
  }

  void _startNewWeek(BuildContext context, WidgetRef ref) {
    context.push('/plan/week');
  }
}

class _ActiveBucketSection extends ConsumerWidget {
  const _ActiveBucketSection({
    required this.plan,
    required this.routineMap,
    required this.nameMap,
    required this.needsConfirmation,
  });

  final WeeklyPlan plan;
  final Map<String, Routine> routineMap;
  final Map<String, String> nameMap;
  final bool needsConfirmation;

  static const _primaryGreen = Color(0xFF00E676);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final suggestedNext = ref.watch(suggestedNextProvider);
    final completedCount = ref.watch(completedCountProvider);
    final totalCount = ref.watch(totalBucketCountProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confirmation banner (auto-populated week).
          if (needsConfirmation) ...[
            _ConfirmBanner(
              onConfirm: () {
                ref.read(weeklyPlanNeedsConfirmationProvider.notifier).state =
                    false;
              },
              onEdit: () => context.push('/plan/week'),
            ),
            const SizedBox(height: 8),
          ],

          // Section header: THIS WEEK  2 of 4  [Next >]
          Row(
            children: [
              Text(
                'THIS WEEK',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$completedCount',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _primaryGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' of $totalCount',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Suggested-next pill chip.
              if (suggestedNext != null) ...[
                _SuggestedNextPill(
                  routineName:
                      nameMap[suggestedNext.routineId] ?? 'Next workout',
                  onTap: () {
                    final routine = routineMap[suggestedNext.routineId];
                    if (routine != null) {
                      startRoutineWorkout(context, ref, routine);
                    }
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Routine chips (horizontal scroll).
          GestureDetector(
            onLongPress: () => context.push('/plan/week'),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _buildChips(context, ref)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChips(BuildContext context, WidgetRef ref) {
    final suggestedNext = ref.read(suggestedNextProvider);

    final sortedRoutines = [...plan.routines]
      ..sort((a, b) => a.order.compareTo(b.order));

    return sortedRoutines.map((bucket) {
      final name = nameMap[bucket.routineId] ?? 'Routine';
      final isDone = bucket.completedWorkoutId != null;
      final isNext =
          suggestedNext != null &&
          bucket.routineId == suggestedNext.routineId &&
          !isDone;

      final chipState = isDone
          ? RoutineChipState.done
          : isNext
          ? RoutineChipState.next
          : RoutineChipState.remaining;

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: RoutineChip(
          sequenceNumber: bucket.order,
          routineName: name,
          chipState: chipState,
          onTap: isNext
              ? () {
                  final routine = routineMap[bucket.routineId];
                  if (routine != null) {
                    startRoutineWorkout(context, ref, routine);
                  }
                }
              : null,
        ),
      );
    }).toList();
  }
}

class _SuggestedNextPill extends StatelessWidget {
  const _SuggestedNextPill({required this.routineName, required this.onTap});

  final String routineName;
  final VoidCallback onTap;

  static const _primaryGreen = Color(0xFF00E676);
  static const _cardColor = Color(0xFF232340);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: _cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: _primaryGreen, width: 1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  routineName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: _primaryGreen, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmBanner extends StatelessWidget {
  const _ConfirmBanner({required this.onConfirm, required this.onEdit});

  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF232340),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00E676).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Same plan this week?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Edit')),
          TextButton(onPressed: onConfirm, child: const Text('Confirm')),
        ],
      ),
    );
  }
}

class _EmptyBucketState extends StatelessWidget {
  const _EmptyBucketState({required this.hasRoutines});

  final bool hasRoutines;

  @override
  Widget build(BuildContext context) {
    if (!hasRoutines) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => context.push('/plan/week'),
        child: Text(
          'Plan your week \u2192',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}
