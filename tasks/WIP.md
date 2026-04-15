# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## P1 — Progress charts per exercise

**Branch:** `feature/p1-progress-charts`
**Source:** PLAN.md line 586 (Phase 13 Sprint B Slot 1 — final Sprint B item before Sprint C Resilience)
**Owner pipeline:** tech-lead → ui-ux-critic (design review) → qa-engineer → reviewer
**Status:** spec agreed (product-owner + ui-ux-critic briefs 2026-04-15)

### Design decisions (from product-owner + ui-ux-critic briefs)

- **Metric:** max completed working-set weight per session. Reuse the predicate from `lib/features/personal_records/domain/pr_detection_service.dart:120` (`s.setType == SetType.working && s.isCompleted`). Extract to a shared util so the chart and PR detection cannot drift apart.
- **Grouping:** group by *calendar date* of `workouts.finished_at`, not `workout_id` — two sessions same day merge to one point.
- **Time window:** `SegmentedButton` with **90d (default) / All time**. No 30d, no date picker.
- **Location:** inside existing exercise detail sheet, new `_ProgressChartSection` between `_PRSection` and the delete button. **Not a sub-route.**
- **Aesthetic (anti-generic):** 3dp primary-green line on `surfaceColor`, no gradient fill, no bezier (`LineCurves.linear`), filled 6dp green dots, **no card wrapper**, one midpoint hairline grid only, no x-axis labels, y-axis shows only min+max inline on right edge (`labelLarge`, 0.55 alpha).
- **Unit label:** section header reads `"Progress (kg)"` / `"Progress (lbs)"` — pulled from `profileProvider`. No per-label unit repetition.
- **Interactions:** read-only glance surface. **No tooltips, no zoom, no pan** in v1. Add `Semantics` label `"Progress chart, [N] sessions logged"`.
- **Empty states:**
  - 0 points: chart hidden; `bodyMedium` @ 0.4 alpha — `"Log this exercise to see your progress"`. Matches PR section's empty-state typography for consistency.
  - 1 point: chart renders with one dot and no connecting line; sub-caption `"1 session logged"` same treatment.
- **Fixed chart height:** 200dp.
- **Out of scope (v1.1+):** volume toggle, reps chart for bodyweight, trendline, share/screenshot, PR-date annotations, Epley 1RM.

### Implementation checklist

- [x] Add `fl_chart` dependency to `pubspec.yaml` (latest stable compatible with Flutter 3.11.4 / Dart SDK). — **1.2.0 locked.**
- [x] Extract shared working-set predicate into `lib/features/workouts/utils/set_filters.dart` — both `pr_detection_service.dart` and the new chart provider consume it. Removed the private `_completedWorkingSets` from `PRDetectionService`; behaviour unchanged (all 15 PR detection tests still pass).
- [x] New provider: `lib/features/exercises/providers/exercise_progress_provider.dart`
  - `FutureProvider.autoDispose.family<List<ProgressPoint>, ExerciseProgressKey>` — `AsyncNotifier` would've been marginal for a pure-query provider. `ExerciseProgressKey(exerciseId, TimeWindow)` handles the cache key.
  - Query via new `WorkoutRepository.getExerciseHistory(exerciseId, userId, since)` — zero `supabase.from()` in the provider.
  - `ref.keepAlive()`-guarded.
  - Pure `buildProgressPoints()` helper exported for unit tests.
- [x] New model: `ProgressPoint { DateTime date; double weight; int sessionReps; }` (Freezed, no JSON).
- [x] New widget: `lib/features/exercises/ui/widgets/progress_chart_section.dart`
  - `SegmentedButton` (90d default / All time) + `fl_chart LineChart` with 3dp green line, 6dp green dots, linear (no bezier), no gradient fill, no card wrapper, single midpoint hairline grid, no axis lines, inline min/max y-labels, month labels at left/right only when span > 12 weeks.
  - Reads `profileProvider.weightUnit` for header label (`Progress (kg)` / `Progress (lbs)`).
  - `lineTouchData: disabled` — no tooltips/zoom/pan in v1.
- [x] Integrate into `exercise_detail_screen.dart` between `_PRSection` and delete action.
- [x] Unit tests: working-set filter util (9 tests) + provider + transform (12 tests). Covers warmup/dropset/failure/incomplete/zero-rep/null-rep exclusion, same-day dedupe, multi-day sorting, 90d `since` cutoff, allTime `null since`, signed-out user isolation, Freezed equality.
- [x] Widget tests: empty state, single-point state + caption, multi-point state, kg↔lbs header swap, 90d→All time toggle re-fires provider, Semantics label plural vs singular (7 tests).
- [x] Verify `make ci` green (format + analyze + test + android-debug-build).
- [ ] ui-ux-critic design review after implementation (anti-generic-AI pass).
- [ ] qa-engineer: selector impact assessment on exercise detail (sheet reordered recently in PR #58). If any new user-visible copy, add `@smoke` Playwright test in `specs/exercises.spec.ts` asserting chart section rendering for an exercise with ≥2 sessions. This is additive UI, not a flow change — full E2E run not strictly required unless navigation added.
- [ ] reviewer pass — fix every finding in-cycle (no deferring).
- [ ] PR.
- [ ] Apply migrations — none expected (read-only feature).
- [ ] After merge: remove this section, condense P1 in PLAN.md to 3-5 bullet summary.

### Files touched (plan)

- `pubspec.yaml` (add fl_chart)
- `lib/features/workouts/utils/set_filters.dart` (new — shared predicate)
- `lib/features/personal_records/domain/pr_detection_service.dart` (refactor to shared predicate)
- `lib/features/exercises/models/progress_point.dart` (new)
- `lib/features/exercises/providers/exercise_progress_provider.dart` (new)
- `lib/features/exercises/ui/widgets/progress_chart_section.dart` (new)
- `lib/features/exercises/ui/exercise_detail_screen.dart` (integrate section)
- `test/unit/exercises/exercise_progress_provider_test.dart` (new)
- `test/unit/workouts/set_filters_test.dart` (new)
- `test/widget/exercises/progress_chart_section_test.dart` (new)
- `test/e2e/specs/exercises.spec.ts` (smoke assertion if needed) + `helpers/selectors.ts`

### Open questions / risks

- fl_chart version compatibility with current Flutter/Dart SDK — check `pub outdated` behavior before locking.
- `LineChart` behavior with a single data point — brief says dot-only with no line; verify via widget test.
- Timezone: `finished_at` is UTC in DB. Group by user-local date when bucketing per-day (use device timezone). Must match how PR section computes dates to stay consistent on-screen.

---

*Last merged: PR #58 (feat(exercises): exercise content standard + library expansion to 150 — P9, Phase 13 Sprint B Slot 1).*
