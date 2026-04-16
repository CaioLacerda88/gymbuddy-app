# Backlog — product/UX follow-ups

Non-blocker items discovered outside of an active PLAN.md step. Each entry is a future ticket: small enough to scope in a single PR, big enough to not get lost. When pulled into active work, move the spec to PLAN.md and delete the backlog entry here.

---

## BL-1 — Progress chart "sessions logged" copy is misleading when user logs multiple workouts per day

**Context:** Found 2026-04-16 during B6 on-device smoke. User ran the same routine twice in one day (barbell curl logged in both). The exercise progress section showed `"1 session logged"`.

**Root cause:** `lib/features/exercises/providers/exercise_progress_provider.dart:80-121` (`buildProgressPoints`) groups by `(year, month, day)` local calendar-date and keeps the max-weight set per day. Two workouts same-day → one progress point. That aggregation is intentional for the weight-over-time chart, but the copy says `"session"` not `"day"`.

**Symptom:** User is confused about whether the second workout was persisted. They had to navigate to history to confirm. This breaks trust.

**Options (pick one during spec):**

- **A (cheap):** Rename copy to `"1 day logged"` / `"N days logged"`. One-line change + test copy update. Still accurate, matches aggregation.
- **B (right thing):** Distinguish two counts — `"2 workouts logged across 1 day"` or similar. Requires passing raw-row count through `buildProgressPoints` alongside the aggregated points. ~20 LoC + tests.
- **C (change aggregation):** Plot one point per workout (not per day). Rejected unless product-owner wants it — same-day workouts would stack visually, making the chart noisy for lifters who split AM/PM sessions.

**Recommendation:** B — precise, keeps the chart clean, and removes ambiguity. Effort: ~1h including widget + unit test.

**Acceptance:**
1. When user has 2+ completed sets for an exercise across 1 calendar day, copy reads `"2 workouts logged"` (or equivalent unambiguous phrasing).
2. When user has workouts spanning ≥2 days, the chart still renders the weight-over-time line as today.
3. Unit test for `buildProgressPoints` covers: `[1 workout in 1 day]`, `[2 workouts same day]`, `[2 workouts different days]` — asserts both the points count and the workout count.

**Files:** `lib/features/exercises/providers/exercise_progress_provider.dart`, `lib/features/exercises/ui/` (whichever widget renders the "N session(s) logged" text — likely the exercise detail / progress section), `test/unit/features/exercises/providers/exercise_progress_provider_test.dart`.

---

## BL-2 — Home `active-plan` state wastes ~900px below the fold; recent-activity surface is a single line

**Context:** Found 2026-04-16 during B6 on-device smoke on Samsung S25 Ultra. User completed a workout and looked at home expecting to see their activity. What's there:

- `2 of 4 this week` — plan counter
- `UP NEXT · Full Body Beginner · 6 exercises · ~40 min` — hero banner
- Week strip: ✓ ✓ 3 4
- `Last: Arms & Abs, Today` — one-line footnote

Everything above fits in the top ~30% of the screen. The bottom ~70% is empty dark surface down to the bottom nav.

**Observation:** W8 (PR #67) shipped a four-state Home IA with intentionally minimal chrome — scoped around onboarding, lapse recovery, and plan gating. Returning-lifter surfaces were explicitly out of scope at the time. The `Last:` footnote is a token gesture; it acknowledges history exists but carries no detail (no sets, no volume, no PR hits, no streak, no last-session heatmap).

**Why this matters:**
- **Dead screen real estate is product debt.** Users perceive "empty = nothing to do here" and bounce to another app. Especially bad immediately after a workout, when the app should be *most* rewarding to re-open.
- **Retention loop feedback:** the highest-dopamine moment in a training app is seeing your own work reflected back. `Last: Arms & Abs, Today` doesn't do that — it's text, not feedback.
- **Navigation cost:** 3 taps (Home tab → Profile → Workouts) to see "what did I actually do yesterday?". With 900px of free real estate on home, that's a self-inflicted wound.

**Needs framing (NOT a direct fix):** Start with a `product-owner` + `ui-ux-critic` pass before any code. Framing questions:
- What is the *right* fill for the bottom 70% of `active-plan` home? Candidates: last-session recap card (exercises + best set per exercise + total volume), trailing 7-day volume bar, PR-of-the-week, streak indicator, suggested-deload prompt, bodyweight trend micro-chart.
- Does this vary by state? (Probably — `brand-new` and `lapsed` states may keep the empty calm on purpose; this is a returning-lifter fix.)
- Is ANY of this valuable without gamification (Phase 15-16)? The XP/streak/quest surfaces are coming — don't pre-bake a design that will be redone in 3 months.
- Tap target: tap the recap card → `/home/history/:latestWorkoutId` (existing deep-link route).

**Do NOT just add a "Recent workouts" list** — that's generic AI fitness-app aesthetic. Whatever ships should feel like GymBuddy (dark, bold, data-forward, glance-first). Anti-generic-AI guidance: push `ui-ux-critic` before committing a design.

**Interim quick win (optional, 1h):** Promote `Last: Arms & Abs, Today` from one-line text to a tappable card with exercise count + total volume. Fills maybe 15% of the dead space; still ships today's nav fix. Not a substitute for the real redesign.

**Suggested PLAN.md home when promoted:** Post-Phase 13 polish, or a Sprint C tail item if we decide the dead-screen impression is launch-blocking. Defer framing until Phase 15 scope is locked so we don't build UI that gets ripped out for XP/streak/quest surfaces.

**Files (to be scoped):** `lib/features/home/ui/home_screen.dart`, new widget(s) under `lib/features/home/ui/`, likely a `recentWorkoutsProvider` under `lib/features/workouts/providers/` that reuses existing history query paths.

---

## BL-3 — Exercise progress chart fails at every data density; full rebuild (axes, PR marker, e1RM, trend summary)

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
6. **Trend summary copy:** above the plot, single `bodyMedium @ 0.70` line, state-dependent:
   - 0 sessions: `"Log your first set to start tracking"`
   - 1 session: `"1 session logged — keep going"`
   - 2+ up: `"Up {Δ} in {window}"` (green)
   - 2+ down: `"Down {Δ} in {window}"` (neutral, not red — don't punish deloads)
   - 2+ flat: `"Holding steady at {value}"`
7. **Container chrome:** chart inside `_cardColor` (`#232340`) surface with 1dp `onSurface @ 0.10` border, `BorderRadius.circular(12)`, 12dp horizontal internal padding. No drop shadow, no glow.
8. **Density-aware height:** chart height 120dp when N < 4, 200dp when N ≥ 4. Prevents a near-empty 200dp void for new users.
9. **Kill the "Progress (kg)" section header.** Unit lives on the Y-axis. The trend summary line IS the section's first text row.
10. **Toggle placement:** collapse into a single Row with trend summary copy left-aligned and `SegmentedButton` (`30d / 90d / All time`) right-aligned. Removes a redundant row; matches GymBuddy's density-first principle.
11. **PR ↔ chart integration:** thread `prValue` from `exercisePRsProvider` into `ProgressChartSection` as an optional parameter (`ProgressChartSection({required exerciseId, double? prValue})`). `_ExerciseDetailBody` owns the connection.
12. **Empty state:** when N == 0, render a 100dp dashed-border container (`onSurface @ 0.15` dash) with centered copy. Not a card with a gradient illustration.
13. **Widget tests cover:** empty (0 pts), sparse (3 pts), mid (5 pts), rich (11 pts) — each asserts density-appropriate elements appear / are suppressed.
14. No regression in BL-1 copy area (separate ticket).

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
