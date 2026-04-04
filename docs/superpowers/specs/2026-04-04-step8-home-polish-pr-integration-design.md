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

No model, repository, or migration changes needed. All data already exists.

## 1. Resume Workout Banner (Home Screen)

### Placement

Top of home screen `CustomScrollView`, above the routines section. Most prominent element when an active workout exists — pushes all other content down.

### Widget

New file: `lib/features/workouts/ui/widgets/resume_workout_banner.dart`

- `ResumeWorkoutBanner` — `ConsumerStatefulWidget` (needs `AnimationController`)
- Watches `activeWorkoutProvider` — renders only when state is non-null
- Full-width card, ~80dp min height
- Background: `theme.colorScheme.primary`
- Pulsing border glow: `BoxDecoration` with animated `boxShadow` using `AnimationController.repeat(reverse: true)` over 2 seconds. Shadow color is primary at 0.0–0.6 opacity, blur radius 4–12.
- Content row: fitness icon + column(workout name, elapsed time via `elapsedTimerProvider`) + trailing chevron/arrow icon
- Tap → `context.go('/workout/active')`
- `HapticFeedback.mediumImpact()` on tap

### Edge Cases

- Banner disappears reactively when `activeWorkoutProvider` emits null (workout finished or discarded)
- Empty workouts (0 exercises added) still show the banner
- No duplicate with nav bar banner — nav bar banner remains for non-home tabs

### Integration in Home Screen

In `home_screen.dart`, add `ResumeWorkoutBanner()` as the first sliver child (or first item in the list) when an active workout exists. Conditionally include based on `activeWorkoutProvider.valueOrNull != null`.

## 2. Recent PRs Section (Home Screen)

### Data

New provider in `lib/features/personal_records/providers/pr_providers.dart`:

```dart
final recentPRsProvider = FutureProvider.autoDispose<List<PersonalRecordWithExercise>>((ref) async {
  final authRepo = ref.read(authRepositoryProvider);
  final userId = authRepo.currentUser!.id;
  final prRepo = ref.read(prRepositoryProvider);
  final allPRs = await prRepo.getRecordsWithExercises(userId);
  // Already sorted by achieved_at DESC from repository
  return allPRs.take(5).toList();
});
```

Uses existing `getRecordsWithExercises()` method. Takes the 5 most recent.

### Widget

New file: `lib/features/personal_records/ui/widgets/recent_prs_section.dart`

- `RecentPRsSection` — `ConsumerWidget`
- Watches `recentPRsProvider`
- **Hidden entirely when**: loading, error, or empty list (no "No records" placeholder on home — avoids clutter)
- Section header: "RECENT RECORDS" label (left) + "View All" `TextButton` (right) → `context.go('/records')`
- PR items: compact horizontal cards showing:
  - Exercise name (primary text, ellipsized)
  - Record type icon (fitness_center / repeat / bar_chart — reuse from PR list screen)
  - Formatted value ("100 kg", "12 reps", "1200 vol")
  - Relative date ("3d ago", "Today")
- Cards arranged in a `Column` (vertical list, not horizontal scroll — matches "Recent Workouts" pattern)

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

Requires a new repository method: `getPRsForWorkout(workoutId, userId)` that joins `personal_records` → `sets` → `workout_exercises` → `workouts` to find PRs achieved during a specific workout. This is a read query, no schema changes.

### UI Changes

In `workout_detail_screen.dart` → `_ReadOnlySetRow`:

- Accept an `isPR` boolean parameter
- When `isPR == true`: show a small trophy icon (`Icons.emoji_events`, 16dp, amber/gold `Colors.amber`) at the leading edge of the row, before the set number
- Subtle but unmistakable — no animation, just a static icon

The parent widget (`_ExerciseCard` or equivalent) watches `workoutPRSetIdsProvider(workoutId)` and passes `isPR: prSetIds.contains(set.id)` to each `_ReadOnlySetRow`.

## 4. Nav Bar Banner Pulse Enhancement

### Current State

`_ActiveWorkoutBanner` in `app_router.dart` (lines 216-279): 56dp, primary color background at 0.85 opacity, static decoration.

### Changes

Convert `_ActiveWorkoutBanner` to a `StatefulWidget` (or `ConsumerStatefulWidget` if not already) to hold an `AnimationController`.

- Add pulsing `boxShadow` animation: primary color shadow, opacity oscillates 0.0–0.4, blur radius 2–8, 2.5s cycle with `repeat(reverse: true)`
- Subtler than home screen banner (shorter blur range, lower max opacity) — this is a background reminder, not a hero CTA
- No other visual changes to the banner content

## Files Changed

| File | Change |
|------|--------|
| `lib/features/workouts/ui/home_screen.dart` | Add `ResumeWorkoutBanner` + `RecentPRsSection` |
| `lib/features/workouts/ui/workout_detail_screen.dart` | Add PR badge to `_ReadOnlySetRow` |
| `lib/features/personal_records/providers/pr_providers.dart` | Add `recentPRsProvider`, `workoutPRSetIdsProvider` |
| `lib/features/personal_records/data/pr_repository.dart` | Add `getPRsForWorkout()` method |
| `lib/core/router/app_router.dart` | Pulse animation on `_ActiveWorkoutBanner` |

## New Files

| File | Purpose |
|------|---------|
| `lib/features/workouts/ui/widgets/resume_workout_banner.dart` | Resume banner widget |
| `lib/features/personal_records/ui/widgets/recent_prs_section.dart` | Recent PRs section widget |

## Testing

### Widget Tests
- Resume banner: renders when active workout exists, hidden when null, shows workout name + timer, tap navigates to `/workout/active`, pulsing animation runs
- Recent PRs section: hidden when empty, shows up to 5 PRs, "View All" navigates to `/records`, displays correct values and icons
- Workout detail PR badges: trophy icon shows on PR sets, absent on non-PR sets
- Nav bar banner: pulse animation active when workout exists

### Unit Tests
- `recentPRsProvider`: returns max 5, sorted by recency
- `workoutPRSetIdsProvider`: returns correct set IDs
- `getPRsForWorkout()`: correct join query, returns only PRs for given workout

## Deferred

- Muscle group coverage insight ("You haven't trained back in 8 days") — v1.1 per PLAN.md
- PR trend charts or graphs
- Animated PR badge on workout detail (keep it static for now)
