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
