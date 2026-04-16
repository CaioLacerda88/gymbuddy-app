import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/providers/profile_providers.dart';
import '../../../weekly_plan/providers/suggested_next_provider.dart';
import '../../../weekly_plan/providers/weekly_plan_provider.dart';
import '../../providers/workout_history_providers.dart';

/// State-aware one-line status displayed at the top of the Home screen.
///
/// Replaces the old date + greeting header. Content per state:
///
/// * Active plan, incomplete: `"X of Y this week"` — `X` in primary green,
///   ` of Y this week` muted.
/// * Active plan, complete:   `"Week complete — Y of Y done"`.
/// * No plan + has history:   `"No plan this week"` (muted).
/// * Brand-new (no plan, no history): display name only (no date, no
///   greeting). Renders nothing when the display name is absent/empty.
///
/// This widget watches only the minimal set of providers it needs so its
/// rebuilds are scoped and do not invalidate siblings.
class HomeStatusLine extends ConsumerWidget {
  const HomeStatusLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final planAsync = ref.watch(weeklyPlanProvider);

    // Prefer committed values. During reload (AsyncLoading with previous data)
    // we keep showing the prior state to avoid flicker, matching the pattern
    // used by [WeekBucketSection].
    final plan = planAsync.value;
    final hasActivePlan = plan != null && plan.routines.isNotEmpty;

    if (hasActivePlan) {
      final completed = ref.watch(completedCountProvider);
      final total = ref.watch(totalBucketCountProvider);
      final isComplete = ref.watch(isWeekCompleteProvider);

      // Active/complete states use titleLarge so the status line outranks the
      // hero content directly below — the hero reads as a consequence of the
      // status, not a sibling. Lapsed (further down) stays at titleMedium.
      if (isComplete) {
        return Text(
          'Week complete \u2014 $total of $total done',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        );
      }

      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$completed',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: ' of $total this week',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // No active plan. Decide between "No plan this week" (has history) and
    // the brand-new display-name-only or silent state.
    final history = ref.watch(workoutHistoryProvider).value;
    final hasHistory = history != null && history.isNotEmpty;

    if (hasHistory) {
      return Text(
        'No plan this week',
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final profile = ref.watch(profileProvider).value;
    final displayName = profile?.displayName;
    if (displayName == null || displayName.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(displayName, style: theme.textTheme.headlineMedium);
  }
}
