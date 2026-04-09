import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/radii.dart';
import '../../../profile/providers/profile_providers.dart';
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
          final weightUnit =
              ref.watch(profileProvider).valueOrNull?.weightUnit ?? 'kg';
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: WeekReviewSection(
              plan: plan,
              routineNames: nameMap,
              totalVolume: stats?.totalVolume ?? 0,
              prCount: stats?.prCount ?? 0,
              weightUnit: weightUnit,
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

          // Section header row: THIS WEEK  [Edit icon]  [Next > pill]
          Row(
            children: [
              Text(
                'THIS WEEK',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              // Edit plan link.
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                tooltip: 'Edit weekly plan',
                onPressed: () => context.push('/plan/week'),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
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

          // Progress counter below title — not competing with pill.
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
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

      // For the "next" chip, pass exercise count from routine data.
      final routine = routineMap[bucket.routineId];
      final exerciseCount = routine?.exercises.length;

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: RoutineChip(
          sequenceNumber: bucket.order,
          routineName: name,
          chipState: chipState,
          exerciseCount: isNext ? exerciseCount : null,
          onTap: isDone
              ? null
              : () {
                  if (routine != null) {
                    startRoutineWorkout(context, ref, routine);
                  }
                },
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
        borderRadius: BorderRadius.circular(kRadiusMd),
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

/// Empty plan state — full-width bordered container at 72dp min-height
/// with centered text + icon.
class _EmptyBucketState extends StatelessWidget {
  const _EmptyBucketState({required this.hasRoutines});

  final bool hasRoutines;

  @override
  Widget build(BuildContext context) {
    if (!hasRoutines) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS WEEK',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => context.push('/plan/week'),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 72),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Plan your week',
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
        ],
      ),
    );
  }
}
