# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## BL-3 — Exercise progress chart full rebuild

**Branch:** `feature/bl3-progress-chart-rebuild`
**Source spec:** `tasks/backlog.md` → BL-3 (14 acceptance items, converged PO + UX pass 2026-04-16)
**Folded-in scope:** BL-1 (workout-count vs point-count disambiguation) — see backlog acceptance #14.

### Why this ticket

- Chart renders as a placeholder at every density (sparse and rich both look bad).
- PR card and chart measure different things (`Max Weight` raw vs chart plots raw max-per-day) — switch to **e1RM** (Epley) as primary so the numbers line up and rep-range changes don't lie.
- No axes, no dates, no PR marker, no trend interpretation → user cannot answer "when did I lift X?" or see their proudest moment.
- BL-1 bug: "1 session logged" shows when user logged 2 workouts same-day → broken trust.

### Files to create / modify

**New**
- [ ] `lib/features/exercises/utils/e1rm.dart` — pure Dart Epley formula + unit-conversion helpers
- [ ] `test/unit/features/exercises/utils/e1rm_test.dart` — pure-Dart unit tests
- [ ] `test/widget/features/exercises/widgets/progress_chart_section_test.dart` — 4 density states + empty + PR ring + metric toggle

**Modify**
- [ ] `lib/features/exercises/providers/exercise_progress_provider.dart` — add `TimeWindow.last30Days`, expose `workoutCount` + `e1RmSeries` + `peakPoint` + `trendDelta`, keep existing `buildProgressPoints` API backward-compat where possible
- [ ] `lib/features/exercises/ui/widgets/progress_chart_section.dart` — full reconfigure (trend copy row, Y-axis with unit + 3 ticks, X-axis always on with dates, gold PR ring `#FFD54F` on peak dot, container chrome `#232340` + 1dp border + 12dp radius, density-aware heights 120dp/200dp, dashed empty state, metric toggle `e1RM / Weight`, segmented window `30d / 90d / All time`, weekly-max aggregation for "All time" when N > 30)
- [ ] `lib/features/exercises/ui/exercise_detail_screen.dart` — `_ExerciseDetailBody` threads `prValue` from `exercisePRsProvider` to `ProgressChartSection`, removes standalone "Progress (kg)" section header (kill — unit is on Y-axis, trend summary is first text row)
- [ ] Existing progress provider unit test — extend to cover new `workoutCount` distinction (4 cases per backlog acceptance #14)

### Acceptance (from `tasks/backlog.md` BL-3 — full list, must all ship)

1. e1RM primary metric + `e1RM / Weight` toggle (both over `isCompletedWorkingSet`)
2. Default window 30d; segments `30d / 90d / All time`; weekly-max when "All time" and N > 30
3. Y-axis: 36dp left space, 3 labeled ticks with unit (respect `weightUnit`), mid hairline @ 0.08, bounds @ 0.05, Y-range pad = `max(span × 0.15, maxValue × 0.10)`
4. X-axis always on: ≤8 points → first + last `MMM d`; >8 points → 3 evenly-spaced labels; N<10 → per-dot date labels
5. PR marker: hollow circle (2dp accent stroke) + `#FFD54F` outer ring on peak dot; no dashed line, no right-gutter label
6. Trend summary copy (state-dependent, uses `workoutCount` not `pointCount` — folds in BL-1)
7. Container chrome: `#232340` card + 1dp `onSurface @ 0.10` border + 12dp radius + 12dp horizontal internal padding; no shadow/glow
8. Density-aware height: 120dp when N<4, 200dp when N≥4
9. Kill "Progress (kg)" section header (unit lives on Y-axis, trend copy is first text row)
10. Toggle placement: single row, trend copy left + `SegmentedButton` right
11. PR ↔ chart integration: `ProgressChartSection({required exerciseId, double? prValue})` wired from `_ExerciseDetailBody`
12. Empty state: 100dp dashed-border container, centered copy — not a card with a gradient illustration
13. Widget tests: empty (0 pts), sparse (3 pts), mid (5 pts), rich (11 pts) + PR ring + metric toggle
14. Provider exposes `workoutCount` so trend copy can say "2 workouts logged" when 2 workouts aggregate to 1 point (BL-1 fix)

### Explicitly rejected (anti-generic-AI — do NOT add)

- Gradient area-fill under the line (`belowBarData.show = false` stays)
- Tap-to-drill interactivity
- Relative-intensity percentages ("78% of 1RM")
- Social/share overlays

### Build sequence (TDD)

1. **e1rm utility (pure Dart) — test-first.** Write `test/unit/.../e1rm_test.dart` covering Epley at 1/5/10 reps, unit conversions kg↔lb, edge cases (0 reps = 0 weight → 0, null weight guard). Then `lib/features/exercises/utils/e1rm.dart`.
2. **Provider extensions — test-first.** Extend existing `exercise_progress_provider_test.dart` with 4 BL-1 cases (0 workouts / 1 workout 1 day / 2 workouts same day / 2 workouts different days), + new `last30Days` window, + e1RM series derivation, + `peakPoint` + `trendDelta`. Then implement.
3. **Widget tests — sparse/mid/rich/empty cases.** Build `progress_chart_section_test.dart` covering each density + PR ring visibility + metric toggle + trend copy strings per acceptance #6.
4. **Widget reconfigure.** Rebuild `progress_chart_section.dart` to pass the tests. Follow UX spec container/axis/ring/trend layout.
5. **Detail screen wiring.** `_ExerciseDetailBody` threads `prValue`; remove "Progress (kg)" header.
6. **Visual check on device / Chrome.** Load caiolacerda88@gmail.com (rich Barbell Bench Press seeded data, 11 workouts 50→75 kg) for the rich state; Deadlift 3-point sparse state untouched.

### Verification fixture (already on hosted Supabase)

- 11 Barbell Bench Press workouts seeded on caiolacerda88@gmail.com, marker `notes='seed:bench-60d'`, progressive overload 50 → 75 kg over ~60 days, 4 working sets each.
- Deadlift 3-point sparse state untouched — contrasting test bed.
- Removal when work ships: `DELETE FROM public.workouts WHERE user_id = (SELECT id FROM auth.users WHERE email='caiolacerda88@gmail.com') AND notes='seed:bench-60d';`

### Gates

- [ ] `make ci` green (format + gen + analyze + test + android-debug-build)
- [ ] `ui-ux-critic` reviews implementation against converged spec — no generic-AI regressions
- [ ] `qa-engineer` reviews test coverage; runs E2E selector-impact assessment (exercise detail screen changes). If no nav/routing change → selector check only, no new E2E. If any nav change → full E2E run locally.
- [ ] `reviewer` pass: no new lint warnings, all 14 acceptance items covered in diff
- [ ] Verify against `tasks/backlog.md` BL-3 line-by-line before PR

---

## Session snapshot (for refresh)

**Completed this session:**
- W3b: PR #63 merged — input length limits, CHECK constraints applied to hosted Supabase.
- W3b docs: PR #64 merged — condensed W3b in PLAN.md.
- W3: PR #65 merged — stale workout timeout UX. Tests: 1103 total.
- W3 docs: PR #66 merged — condensed W3 in PLAN.md.
- W8 scoping (Apr 15): original perf refactor premise invalidated — HomeScreen has no long list. Re-scoped via product-owner + ui-ux-critic analysis to a full Home IA refresh.
- W8: PR #67 merged — four-state Home IA refresh. Tests: 1087 total.
- W8 docs: PR #68 merged — condensed W8 in PLAN.md.
- B6: PR #69 merged (commit `e605e77`) — ProGuard/R8 minify + resource shrinking on release. Narrow keep rules (attributes, JNI, Flutter embedding, Play Core `-dontwarn`, Sentry, OkHttp/Conscrypt/BouncyCastle/OpenJSSE TLS), no wildcards. `arm64-v8a` APK 25.83MB → 22.83MB (-11.6%); `classes.dex` -64.7%. 5-flow on-device smoke on Samsung S25 Ultra green. Reviewer findings (2 Important) closed in-cycle. Phase 13 Exit Criterion #5 + #6 MET. **Sprint C complete.**
- B6 docs: PR #70 merged (commit `91f8a3f`) — condensed B6 in PLAN.md, stripped the 360-line B6 scratchpad from WIP.md, and captured the converged PO + UX spec for BL-3 (exercise progress chart rebuild — e1RM primary metric, 30d default, PR gold ring, labeled Y-axis, trend copy row, density-aware rendering, container chrome). Admin-merged per docs-only policy.
- Backlog grooming: BL-2 deferred to Phase 15e in PLAN.md (observation captured — do not pre-design returning-lifter fill ahead of XP/streak/quest scope lock). BL-1 folded into BL-3 as acceptance #14 (workout-count vs point-count disambiguation).

**Sprint C Remaining:** none — all items merged.

**Phase 13 Exit Criteria still open:** #2 (image 404 walkthrough), #3 (new-user CTA E2E verification), #7 (full CI + 145/145 E2E + zero critical bugs). Remaining work is verification, not feature development.

**Backlog items after grooming:**
- BL-1: CLOSED — folded into BL-3 (acceptance #14).
- BL-2: DEFERRED — captured as Phase 15e design observation in PLAN.md.
- BL-3: ACTIVE — see top of this file.

**Local repo state:** on `main` at `91f8a3f`, working tree clean post-merge.

**Hosted Supabase:** up to date through `00021_input_length_limits.sql`. Seed data present on caiolacerda88@gmail.com: 11 Barbell Bench Press workouts for BL-3 rich-data verification, marker `notes='seed:bench-60d'`, removable via one DELETE (documented in BL-3).

**Next:** BL-3 implementation underway. Phase 13 wind-down is verification-only (exit criteria #2, #3, #7). Next feature sprint = Phase 14 (offline).
