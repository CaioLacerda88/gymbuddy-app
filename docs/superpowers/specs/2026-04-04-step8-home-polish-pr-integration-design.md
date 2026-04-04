# Step 8: Home Screen Polish & PR Integration — Design Spec

**Date**: 2026-04-04
**Status**: Approved
**PLAN.md Step**: 8

## Context

Steps 5e and 6 rebuilt the home screen into a routine launchpad and restructured bottom navigation (Home | Exercises | Routines | Profile). Step 7 added full PR detection, celebration, and list. Step 8 focuses on polish and PR integration that depends on Step 7's data.

The home screen currently shows: greeting header, routines section (user or starter), recent workouts (last 3), and "Start Empty Workout" CTA. There is an active workout banner in the bottom nav bar (`_ActiveWorkoutBanner` in `app_router.dart`). PR data is fully queryable but not surfaced on the home screen or workout detail.

## Scope

Four deliverables:

1. Resume workout banner on home screen
2. Recent PRs section on home screen
3. PR badges on workout history detail sets
4. Nav bar banner pulse enhancement

One new repository method needed (`getPRsForWorkout`), plus a `limit` parameter on an existing one. No model or migration changes.

## 1. Resume Workout Banner (Home Screen)

### Placement

First child in the home screen's existing `Column` layout (inside `SingleChildScrollView`), above the routines section. Most prominent element when an active workout exists — pushes all other content down. Do NOT migrate to `CustomScrollView`/slivers for this step.

### Widget

New file: `lib/features/workouts/ui/widgets/resume_workout_banner.dart`

- `ResumeWorkoutBanner` — `ConsumerWidget` (no animation controller needed)
- Watches `activeWorkoutProvider` — renders only when state is non-null AND has at least 1 exercise or 1 completed set (avoids stuck banner for accidental starts)
- Full-width card, ~80dp min height
- Background: `theme.colorScheme.primary` at full opacity
- **No pulsing glow animation.** The live elapsed timer already communicates that the workout is active. Static strong treatment is more distinctive than the generic "breathing badge" pattern.
- Content row: fitness icon + column(workout name, elapsed time via `elapsedTimerProvider`) + trailing chevron icon
- Tap → `context.go('/workout/active')`
- `HapticFeedback.mediumImpact()` on tap

### Edge Cases

- Banner disappears reactively when `activeWorkoutProvider` emits null (workout finished or discarded)
- **Hidden when active workout has 0 exercises AND 0 completed sets** — prevents persistent stuck banner from accidental starts. User can still resume via the nav bar banner.
- No duplicate with nav bar banner — nav bar banner remains for non-home tabs

### Integration in Home Screen

In `home_screen.dart`, add `ResumeWorkoutBanner()` as the first child in the existing `Column` when an active workout exists. Conditionally include based on `activeWorkoutProvider.valueOrNull` being non-null with exercises or completed sets.

## 2. Recent PRs Section (Home Screen)

### Data

Add a `limit` parameter to the existing `getRecordsWithExercises()` repository method (or create a new `getRecentRecordsWithExercises(userId, {int limit = 3})` method). The LIMIT must be applied at the SQL/Supabase query level — do not fetch all records and slice in Dart.

New provider in `lib/features/personal_records/providers/pr_providers.dart`:

```dart
final recentPRsProvider = FutureProvider.autoDispose<List<PersonalRecordWithExercise>>((ref) async {
  final authRepo = ref.read(authRepositoryProvider);
  final userId = authRepo.currentUser!.id;
  final prRepo = ref.read(prRepositoryProvider);
  return prRepo.getRecentRecordsWithExercises(userId, limit: 3);
});
```

Capped at 3 to protect home screen scroll depth. "View All" link covers the rest.

### Widget

New file: `lib/features/personal_records/ui/widgets/recent_prs_section.dart`

- `RecentPRsSection` — `ConsumerWidget`
- Watches `recentPRsProvider`
- **Hidden entirely when**: loading, error, or empty list (no "No records" placeholder on home — avoids clutter)
- Section header: "RECENT RECORDS" label (left) + "View All" `TextButton` (right) → `context.go('/records')`
- PR items: full-width rows matching `_RecentWorkoutRow` visual pattern (not cards, not chips):
  - Left column: exercise name (`titleMedium`), record type label as subdued `bodySmall` ("Max Weight · Today")
  - Right: formatted value in `titleMedium` weight with `theme.colorScheme.primary` color — the number is the hero
  - Trailing: chevron if navigable, or nothing
- Rows arranged in a `Column` (vertical list, not horizontal scroll — matches "Recent Workouts" section pattern)
- **No record type icons** on home screen rows — they add visual noise; the text label is sufficient

### Integration in Home Screen

Add `RecentPRsSection()` below the "Recent Workouts" section, above "Start Empty Workout" button.

## 3. PR Badges on Workout History Detail

### Data

New provider in `lib/features/personal_records/providers/pr_providers.dart`:

```dart
final workoutPRSetIdsProvider = FutureProvider.autoDispose.family<Set<String>, String>((ref, workoutId) async {
  final authRepo = ref.read(authRepositoryProvider);
  final userId = authRepo.currentUser!.id;
  final prRepo = ref.read(prRepositoryProvider);
  // Fetch PRs for this user, filter to those with setIds matching this workout's sets
  // The PR table has set_id FK — query PRs where set_id is in the workout's set IDs
  final prs = await prRepo.getPRsForWorkout(workoutId, userId);
  return prs.map((pr) => pr.setId).whereType<String>().toSet();
});
```

Requires a new repository method: `getPRsForWorkout(workoutId, userId)`.

**Query strategy (two-query approach):**
1. First query: fetch all set IDs for the given workout via `sets` → `workout_exercises` → `workouts` join
2. Second query: fetch `personal_records` where `set_id` is in the set ID list from query 1

Two round trips but straightforward and maintainable. Avoids fragile Supabase nested selects across 4 tables. No RPC needed for a read-only query.

### UI Changes

In `workout_detail_screen.dart` → `_ReadOnlySetRow`:

- Accept an `isPR` boolean parameter
- When `isPR == true`: **substitute** the set number with a trophy icon (`Icons.emoji_events`, 18dp, `Colors.amber[300]`) in the same 40dp `SizedBox` slot, centered. This preserves column alignment with zero layout changes — the set number is already visible implicitly from row ordering.
- When `isPR == false`: show set number as normal
- No animation, just a static icon swap

**Loading state**: Set rows render without badges during async load of `workoutPRSetIdsProvider`. Badges appear reactively once the provider resolves. No shimmer or placeholder.

The parent widget (`_ExerciseCard` or equivalent) watches `workoutPRSetIdsProvider(workoutId)` and passes `isPR: prSetIds.contains(set.id)` to each `_ReadOnlySetRow`.

## 4. Nav Bar Banner Enhancement

### Current State

`_ActiveWorkoutBanner` in `app_router.dart` (lines 216-279): 56dp, primary color background at 0.85 opacity, static decoration.

### Changes

No animation. Instead, a static visual upgrade:

- Increase primary color to full opacity (remove 0.85 alpha)
- Add a 2dp top border in `theme.colorScheme.onPrimary` or a contrasting accent for visual separation from the screen content above
- The live elapsed timer already provides sufficient "alive" signal — no pulsing needed

This is more distinctive than the generic breathing-glow pattern and reads as a confident, opinionated design choice rather than a template effect.

## Files Changed

| File | Change |
|------|--------|
| `lib/features/workouts/ui/home_screen.dart` | Add `ResumeWorkoutBanner` + `RecentPRsSection` |
| `lib/features/workouts/ui/workout_detail_screen.dart` | Add PR badge to `_ReadOnlySetRow` |
| `lib/features/personal_records/providers/pr_providers.dart` | Add `recentPRsProvider`, `workoutPRSetIdsProvider` |
| `lib/features/personal_records/data/pr_repository.dart` | Add `getPRsForWorkout()` + `getRecentRecordsWithExercises()` methods |
| `lib/core/router/app_router.dart` | Static visual upgrade on `_ActiveWorkoutBanner` |

## New Files

| File | Purpose |
|------|---------|
| `lib/features/workouts/ui/widgets/resume_workout_banner.dart` | Resume banner widget |
| `lib/features/personal_records/ui/widgets/recent_prs_section.dart` | Recent PRs section widget |

## Testing

### Widget Tests
- Resume banner: renders when active workout with exercises exists, hidden when null, hidden when 0 exercises/0 sets, shows workout name + timer, tap navigates to `/workout/active`
- Recent PRs section: hidden when empty, shows up to 3 PRs, "View All" navigates to `/records`, displays correct values in row format
- Workout detail PR badges: trophy icon substitutes set number on PR sets, normal set number on non-PR sets, no badge during loading state
- Nav bar banner: full opacity background, top border visible

### Unit Tests
- `recentPRsProvider`: returns max 3, sorted by recency, uses LIMIT at query level
- `workoutPRSetIdsProvider`: returns correct set IDs via two-query approach
- `getPRsForWorkout()`: two-query strategy, returns only PRs for given workout
- `getRecentRecordsWithExercises()`: respects limit parameter

## Deferred

- Muscle group coverage insight ("You haven't trained back in 8 days") — v1.1 per PLAN.md
- PR trend charts or graphs
- Animated PR badge on workout detail (keep it static for now)
- "Best Lifts" summary card on home screen (top 3 all-time lifts) — v1.1
