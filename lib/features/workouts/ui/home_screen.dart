import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/providers/profile_providers.dart';
import '../../routines/models/routine.dart';
import '../../routines/providers/notifiers/routine_list_notifier.dart';
import '../../routines/ui/start_routine_action.dart';
import '../../routines/ui/widgets/routine_action_sheet.dart';
import '../../routines/ui/widgets/routine_card.dart';
import '../../weekly_plan/providers/suggested_next_provider.dart';
import '../../weekly_plan/providers/week_review_stats_provider.dart';
import '../../weekly_plan/providers/weekly_plan_provider.dart';
import '../../weekly_plan/ui/widgets/week_bucket_section.dart';
import '../../weekly_plan/ui/widgets/week_review_section.dart';
import 'widgets/action_hero.dart';
import 'widgets/home_status_line.dart';
import 'widgets/last_session_line.dart';

/// The GymBuddy home surface.
///
/// Per PLAN W8, the composition is state-aware and intent-first:
///
/// 1. [HomeStatusLine]     — state-aware single-line status (replaces date
///                           header + greeting)
/// 2. Confirmation banner  — "Same plan this week?" (renders above hero when
///                           `weeklyPlanNeedsConfirmationProvider` is true)
/// 3. [WeekReviewSection]  — week-complete stats card (only when the current
///                           week's plan is fully done)
/// 4. [ActionHero]         — the banner CTA for the current state
/// 5. [WeekBucketSection]  — chip row (only when an active plan exists and is
///                           not yet complete)
/// 6. [LastSessionLine]    — editorial "Last: ..." line (hidden when no
///                           history)
/// 7. `_HomeRoutinesList`  — user's routines, top 3 + "See all", only when
///                           no active plan
///
/// Note: this build method intentionally does NOT watch any providers. Each
/// block is a ConsumerWidget that subscribes to only the state it needs, so
/// a change in (for example) `workoutHistoryProvider` does not rebuild the
/// status line or chip row.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeStatusLine(),
            SizedBox(height: 16),
            _ConfirmBanner(),
            _WeekReviewCard(),
            ActionHero(),
            SizedBox(height: 12),
            RepaintBoundary(child: WeekBucketSection()),
            LastSessionLine(),
            SizedBox(height: 16),
            _HomeRoutinesList(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confirmation banner ("Same plan this week?")
// ---------------------------------------------------------------------------

class _ConfirmBanner extends ConsumerWidget {
  const _ConfirmBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsConfirmation = ref.watch(weeklyPlanNeedsConfirmationProvider);
    if (!needsConfirmation) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
            TextButton(
              onPressed: () => context.push('/plan/week'),
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: () {
                ref.read(weeklyPlanNeedsConfirmationProvider.notifier).state =
                    false;
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Week review card (complete state)
// ---------------------------------------------------------------------------

/// Renders the [WeekReviewSection] stats card — and only the stats card — when
/// the current week's bucket is fully completed. The "Start new week" CTA is
/// owned by [ActionHero], so this card passes `onNewWeek: null` to keep the
/// review card chrome-free (no NEW WEEK link in the header).
class _WeekReviewCard extends ConsumerWidget {
  const _WeekReviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(weeklyPlanProvider).value;
    if (plan == null || plan.routines.isEmpty) return const SizedBox.shrink();

    final isComplete = ref.watch(isWeekCompleteProvider);
    if (!isComplete) return const SizedBox.shrink();

    final routines = ref.watch(routineListProvider).value ?? const <Routine>[];
    final nameMap = <String, String>{for (final r in routines) r.id: r.name};
    final weightUnit = ref.watch(profileProvider).value?.weightUnit ?? 'kg';
    final stats = ref.watch(weekReviewStatsProvider).value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WeekReviewSection(
        plan: plan,
        routineNames: nameMap,
        totalVolume: stats?.totalVolume ?? 0,
        prCount: stats?.prCount ?? 0,
        weightUnit: weightUnit,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My Routines list (only when no active plan)
// ---------------------------------------------------------------------------

/// Maximum number of user routines shown inline on Home. When the user has
/// more, a "See all" pill links to `/routines`.
const _homeRoutineLimit = 3;

class _HomeRoutinesList extends ConsumerWidget {
  const _HomeRoutinesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(weeklyPlanProvider);
    // Retain previous data during reload so we don't flash the list in/out.
    final plan = planAsync.value;
    final hasActivePlan = plan != null && plan.routines.isNotEmpty;
    if (hasActivePlan) return const SizedBox.shrink();

    final routinesAsync = ref.watch(routineListProvider);
    return routinesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (routines) {
        final userRoutines = routines
            .where((r) => r.userId != null && !r.isDefault)
            .toList();
        if (userRoutines.isEmpty) {
          return const _CreateRoutineCta();
        }

        final shown = userRoutines.take(_homeRoutineLimit).toList();
        final hasMore = userRoutines.length > _homeRoutineLimit;
        final theme = Theme.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MY ROUTINES',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 8),
            for (final r in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RoutineCard(
                  routine: r,
                  onTap: () => startRoutineWorkout(context, ref, r),
                  onLongPress: () => showRoutineActionSheet(context, ref, r),
                ),
              ),
            if (hasMore)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.go('/routines'),
                  child: const Text('See all'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CreateRoutineCta extends StatelessWidget {
  const _CreateRoutineCta();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/routines/create'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.add_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Create Your First Routine',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
