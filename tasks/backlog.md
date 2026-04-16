# Backlog — product/UX follow-ups

Non-blocker items discovered outside of an active PLAN.md step. Each entry is a future ticket: small enough to scope in a single PR, big enough to not get lost. When pulled into active work, move the spec to PLAN.md and delete the backlog entry here.

---

## BL-3 — Exercise progress chart fails at every data density; full rebuild (axes, PR marker, e1RM, trend summary, workout-count disambiguation)

**Context:** Found 2026-04-16 during B6 on-device smoke and re-confirmed after seeding rich data. Two failing states:

- **Sparse state (3 points, Deadlift 25 → 20 → 25 kg):** A V-shape line floating on pure-black with two orphan grey numbers (`25`, `20`) as the only axis context. User: *"a graph that doesn't say anything"*.
- **Rich state (11 points, Barbell Bench Press 50 → 75 kg over 60 days, seeded on caiolacerda88@gmail.com's hosted account — marker `notes='seed:bench-60d'`):** Even with a clean progressive-overload line, rendering still strips temporal context. User: *"the graph still looks bad, with the data"* — confirms this is structural, not sparse-only.

**Product-owner + ui-ux-critic converged pass (2026-04-16):**

> *"The chart reads as a placeholder that accidentally shipped. The sibling PR card tells a cleaner story with less data. The chart underperforms its own sibling widget."* — UX
>
> *"Retention score 3/10 → ~7.5/10 with 1 day invested. The chart is already occupying 40% of screen real estate and returning nothing. Fixing it is not adding a feature — it is making an existing feature earn its space."* — PO

**Rendering / information gaps (ranked):**

1. **No X-axis temporal context.** Three dots with no dates is a shape, not a history. Cannot answer "when did I lift 25 kg?" — the question the chart must answer.
2. **PR peak unmarked on plot.** `Max Weight 25 kg` is shown 200px above in the PR card; the chart's peak is visually identical to every other dot. Proudest moment invisible.
3. **No trend interpretation.** Chart shows shape, draws no conclusion. "Up 5 kg since January" is the sentence users want; the chart forces them to compute it mentally.
4. **Orphaned Y-axis labels with no unit.** `25` and `20` as floating annotations, no `kg` suffix, no axis line. Look like indices on first glance.
5. **Vertical stretch on tiny Y-range.** 20-25 kg expanded to 200dp makes a 5 kg fluctuation look like a dramatic swing. Visually dishonest.
6. **X-axis labels gated at >12 weeks.** The common sparse state (90d filter, few sessions) gets the least context.
7. **No density-aware rendering.** Sparse (N≤4) and rich (N≥10) use the same renderer. Sparse needs labeled dots; rich needs axes + trend summary; neither gets either.
8. **No empty/near-empty state visual.** 0-1 points renders an empty axis with 40%-alpha text; looks like a missing widget.

**Primary product decision — switch metric from raw Max Weight to e1RM.** PO's key call: raw weight breaks when rep ranges change. A lifter going 5×5 → 3×10 sees the line drop even though they got stronger. Switch to **e1RM (Epley: `weight × (1 + reps/30)`)** as the primary metric — same normalization every serious lifting app uses (Strong, Hevy). Keep raw weight as a secondary toggle for purists. The PR card and the chart must both measure the same thing or trust erodes.

**Scope recommendation: Option B (full rebuild, ~1 day).**

Option A (2-3h annotation pass) was rejected — the user's "still looks bad, with the data" comment rules out any fix that leaves the Y-axis/PR-marker/trend-copy gaps untouched. Option C (sparkline + stat block) forfeits exploration affordance for rich data. Option B keeps `fl_chart` engine but reconfigures properly.

**Three personas this chart must serve (descending frequency):**
1. **Mid-session lifter** checking last top set before loading the bar → needs one number + direction.
2. **Post-workout reviewer** basking in a PR → needs celebratory visual (gold ring on peak + "+X kg in Y days" copy).
3. **Lapsed returner** deciding deload vs resume → needs dates on points to see recency.

**Explicitly rejected (anti-generic-AI stance):**
- Gradient area-fill under the line — most fitness apps ship this; it adds visual bulk and obscures low-range density. Keep `belowBarData.show = false`.
- Tap-to-drill interactivity — second-day feature, not v1.
- Relative-intensity percentages (Fitbod-style "78% of 1RM") — requires 1RM baseline most users don't have.
- Social/share overlays — Phase 15+ scope, not this ticket.

**Acceptance:**

1. **Primary metric switched to e1RM** (Epley). Raw weight available as a secondary segmented-button toggle (`e1RM / Weight`). Both compute from the same completed-working-set data source (`set_filters.isCompletedWorkingSet`).
2. **Default time window: 30d** (replacing current 90d default). Segments: `30d / 90d / All time`. For "All time" when N > 30, switch rendering to **weekly-max aggregation** to prevent squiggle.
3. **Y-axis:** left-side 36dp reserved space. Three labeled ticks (min / mid / max) with `kg` / `lb` unit (respect `weightUnit` from profile). Hairlines: mid at `onSurface @ 0.08`, bounds at `@ 0.05`. Y-range padding: `max(span × 0.15, maxValue × 0.10)` — prevents accordion distortion on tight ranges.
4. **X-axis:** always shown, regardless of span (remove the 12-week gate). ≤8 points → show first + last date as `MMM d`. >8 points → three evenly-spaced date labels. Per-dot date labels when N < 10 (sparse convergence).
5. **PR marker:** on the dot where `spot.y == prValue`, render a hollow circle (2dp accent stroke) with a `#FFD54F` outer ring. No dashed line, no right-gutter label — just the ring.
6. **Trend summary copy:** above the plot, single `bodyMedium @ 0.70` line, state-dependent. Use `workoutCount` (raw `workouts` rows in window) rather than `pointCount` (aggregated per-day points) in the copy — a user who logged 2 workouts same-day should see `"2 workouts logged"`, not `"1 session logged"` (BL-1 disambiguation, folded in):
   - 0 workouts: `"Log your first set to start tracking"`
   - 1 workout: `"1 workout logged — keep going"`
   - N workouts (N ≥ 2), pointCount == 1 (all on same day): `"N workouts logged — keep going"` (no trend direction since all aggregate to one point)
   - pointCount ≥ 2 up: `"Up {Δ} in {window}"` (green)
   - pointCount ≥ 2 down: `"Down {Δ} in {window}"` (neutral, not red — don't punish deloads)
   - pointCount ≥ 2 flat: `"Holding steady at {value}"`
7. **Container chrome:** chart inside `_cardColor` (`#232340`) surface with 1dp `onSurface @ 0.10` border, `BorderRadius.circular(12)`, 12dp horizontal internal padding. No drop shadow, no glow.
8. **Density-aware height:** chart height 120dp when N < 4, 200dp when N ≥ 4. Prevents a near-empty 200dp void for new users.
9. **Kill the "Progress (kg)" section header.** Unit lives on the Y-axis. The trend summary line IS the section's first text row.
10. **Toggle placement:** collapse into a single Row with trend summary copy left-aligned and `SegmentedButton` (`30d / 90d / All time`) right-aligned. Removes a redundant row; matches GymBuddy's density-first principle.
11. **PR ↔ chart integration:** thread `prValue` from `exercisePRsProvider` into `ProgressChartSection` as an optional parameter (`ProgressChartSection({required exerciseId, double? prValue})`). `_ExerciseDetailBody` owns the connection.
12. **Empty state:** when N == 0, render a 100dp dashed-border container (`onSurface @ 0.15` dash) with centered copy. Not a card with a gradient illustration.
13. **Widget tests cover:** empty (0 pts), sparse (3 pts), mid (5 pts), rich (11 pts) — each asserts density-appropriate elements appear / are suppressed.
14. **Provider surface:** `buildProgressPoints` (or a new sibling) exposes both the aggregated points AND the raw `workoutCount` in the window, so the widget's trend copy can distinguish "1 workout today" from "N workouts same day" (the old BL-1 bug — user logged 2 routines same day, copy said "1 session logged", they thought the second wasn't persisted). Unit tests assert pointCount + workoutCount for: `[1 workout / 1 day]`, `[2 workouts / same day]`, `[2 workouts / different days]`, `[0 workouts]`.

**Timebox fallback (half-day instead of full day):** drop the e1RM/Weight toggle (ship e1RM only, no raw-weight fallback) and drop the trend summary copy. Keep date labels, PR ring, 30d default, container chrome. PO's assessment: those three changes alone move retention score from 3 to 6.

**Phase-15 non-conflict note:** All changes are additive to the plot area. Axes + PR ring + trend copy do NOT occupy surrounding card real-estate where XP/streak/quest overlays are likely to live. If Phase 15 later moves progress visualization into a larger trend canvas, this work survives the move — only the container skin re-scopes.

**Suggested PLAN.md home when promoted:** D30 polish sprint or a dedicated "progress visualization" mini-phase. Not launch-blocking but high-leverage — fixes a trust deficit every downstream retention feature (BL-2 home recap, Phase 15 surfaces) would otherwise inherit.

**Files:**
- `lib/features/exercises/ui/widgets/progress_chart_section.dart` (primary — axis, chrome, density branch, PR ring, trend copy)
- `lib/features/exercises/ui/exercise_detail_screen.dart` (`_ExerciseDetailBody` threads `prValue` sibling-to-sibling, removes standalone `Progress (kg)` header)
- `lib/features/exercises/providers/exercise_progress_provider.dart` (may need to expose `e1RmSeries`, `peakPoint`, `trendDelta` helpers so the widget stays dumb)
- `lib/features/exercises/utils/e1rm.dart` (new — Epley formula + unit-conversion helpers, with pure-Dart unit tests)
- `test/unit/features/exercises/utils/e1rm_test.dart` (new)
- `test/widget/features/exercises/widgets/progress_chart_section_test.dart` (new — 4 density states + empty state + PR ring + metric toggle)

**Verification fixture already in place:** 11 Barbell Bench Press workouts seeded on caiolacerda88@gmail.com (hosted), marker `notes='seed:bench-60d'`, progressive overload 50 → 75 kg over ~60 days, 4 working sets each. Deadlift 3-point sparse case untouched as the contrasting test bed. Remove the seed when the work ships: `DELETE FROM public.workouts WHERE user_id = (SELECT id FROM auth.users WHERE email='caiolacerda88@gmail.com') AND notes='seed:bench-60d';` (cascades to workout_exercises + sets).
