import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
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
        return Semantics(
          container: true,
          identifier: 'home-status-line',
          child: Text(
            l10n.homeStatusWeekComplete(total),
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }

      return Semantics(
        container: true,
        identifier: 'home-status-line',
        child: Text.rich(
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
                text: l10n.homeStatusProgress(total),
                // BUG-023: WCAG AA contrast. textCream (#EEE7FA) at alpha 0.55
                // over abyss (#0D0319) was ~2.8:1 (fails AA 4.5:1 for normal
                // text). 0.75 yields ~8:1 which clears AA with margin.
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    // No active plan. Decide between "No plan this week" (has history) and
    // the brand-new display-name-only or silent state. Use the scoped
    // boolean provider instead of watching the full paginated history list —
    // that list is not keepAlive and would force this widget to rebuild on
    // every `loadMore()` page-append.
    final hasHistory = ref.watch(hasAnyWorkoutProvider);

    if (hasHistory) {
      return Semantics(
        container: true,
        identifier: 'home-status-line',
        child: Text(
          l10n.noPlanThisWeek,
          // BUG-023: same WCAG AA bump as the active-plan span above.
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    final profile = ref.watch(profileProvider).value;
    final displayName = profile?.displayName;
    if (displayName == null || displayName.isEmpty) {
      return const SizedBox.shrink();
    }

    return Semantics(
      container: true,
      identifier: 'home-status-line',
      child: Text(
        displayName,
        style: theme.textTheme.headlineMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
