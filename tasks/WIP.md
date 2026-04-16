# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## W8 — Home refresh (Sprint C)

**Status:** DISPATCHING `tech-lead`.
**Branch:** `feature/w8-home-refresh`
**Supersedes:** original W8 (HomeScreen perf refactor) — premise obsolete (no long list on home). This is a product-level information-architecture rewrite, with modest scoped-rebuild perf wins folded in.
**History virtualization:** not needed — `WorkoutHistoryScreen` already uses `ListView.builder` (virtualized by default) + cursor pagination (`_pageSize = 20`, `ScrollController` load-more at 200px). No ticket.

### Design direction (from product-owner + ui-ux-critic, respecting bucket model)

Respecting the **training bucket** model (ordered `BucketRoutine` list, no day-of-week assignment). The state machine already exists correctly; the information architecture around it is what's broken.

Principles:
- Home opens with **intent**, not a date.
- The "Up Next" routine is the hero — not buried inside a section 3 levels deep.
- Kill symmetric 2-col stat grids, generic `FilledButton.icon` primary CTA, same-weight section labels.
- Drive lapsed users (no plan + history) toward **planning the week**.
- Starter routines off home entirely — they belong in the routines browser.

### New skeleton

1. **Status line** — state-aware, replaces date/name hero:
   - Active plan, incomplete: `"X of Y this week"` (green count, muted total)
   - Week complete: `"Week complete — Y of Y done"`
   - No plan + history: `"No plan this week"`
   - Brand-new (no plan, no history): display name only (no noise)
2. **Action Hero** (~80dp banner CTA, one of):
   - Active plan → `"Start [Up Next routine name]"` — absorbs `_SuggestedNextCard`
   - Brand-new → existing `_BeginnerRoutineCta` (Full Body quick-start)
   - **Lapsed (no plan + history) → `"Plan your week"` primary + `"Quick workout"` secondary TextButton below** — primary drives toward planning
   - Week complete → `"Start new week"` primary (navigates to `/plan/week`)
3. **Week progress chips** — existing chip row, strip chrome:
   - Kill `THIS WEEK` label (absorbed by status line)
   - Kill `"X of Y"` counter (absorbed by status line)
   - Kill nested `_SuggestedNextCard` (absorbed by hero)
   - Chips only. Only shown when active plan exists.
4. **Last session line** — editorial, no card chrome:
   - `"Last: [Routine], [relative date]"` → tap → `/home/history`
   - Replaces both `ContextualStatCell`s (stat grid deleted entirely)
   - Hidden when no history
5. **My routines (utility)** — only when no active plan:
   - Truncate to top 3 + `"See all"` → `/routines`
   - Long-press action sheet unchanged
6. **Starter routines** — **off home entirely.** Moved into `routine_list_screen.dart` at `/routines`. Beginner CTA path still surfaces Full Body for first-run users.

### Kill list

- `widgets/contextual_stat_cell.dart` — **delete** (only caller is home)
- `contextual_stat_cell_test.dart` — **delete**
- `weekVolumeProvider` in `workout_history_providers.dart` — **delete** (only caller was the stat cell)
- `week_volume_provider_test.dart` — **delete**
- `_SuggestedNextCard` inside `week_bucket_section.dart` — **remove** (folded into Action Hero)
- `_ContextualStatCells` private widget in `home_screen.dart` — **remove**
- `home_screen_stat_cards_test.dart` — **rewrite** as `home_screen_last_session_test.dart` (new editorial line)
- `THIS WEEK` label + counter in `_ActiveBucketSection` — remove
- Date header + uppercase `EEE, MMM d` in `home_screen.dart` — replace with status-line

### Performance (scoped)

- Each home block → its own `ConsumerWidget` watching only its providers. Today `HomeScreen.build` watches 3 providers (profile, plan, routines) and rebuilds the entire tree on any change. After: status-line only rebuilds on plan/history deltas; chips only on plan; last-session only on history.
- Aggressive `const` on static sub-widgets.
- `RepaintBoundary` wrapping the chip row (its internal horizontal scroll shouldn't invalidate siblings).
- **Not** converting to `CustomScrollView` / slivers — no long list, would be theater.

### File plan

**Rewrite:**
- `lib/features/workouts/ui/home_screen.dart` — new skeleton, each section extracted
- `lib/features/weekly_plan/ui/widgets/week_bucket_section.dart` — keep the state-machine orchestrator (beginner CTA / empty / active / complete / confirm), but the `_ActiveBucketSection` internals collapse into just `_WeekProgressChips`. Action Hero extracted.

**New widgets (under `lib/features/workouts/ui/widgets/`):**
- `home_status_line.dart` — the state-aware single-line status
- `action_hero.dart` — the banner CTA with all 4 state modes
- `last_session_line.dart` — editorial last session one-liner

**Modify:**
- `lib/features/routines/ui/routine_list_screen.dart` — integrate default/starter routines (section for defaults if not already present)
- `lib/features/workouts/providers/workout_history_providers.dart` — remove `weekVolumeProvider`

**Delete:**
- `lib/features/workouts/ui/widgets/contextual_stat_cell.dart`
- `test/widget/features/workouts/ui/contextual_stat_cell_test.dart`
- `test/unit/features/workouts/providers/week_volume_provider_test.dart`

### Test matrix

**Widget (`test/widget/features/workouts/ui/`):**
- `home_screen_test.dart` — rewrite for new skeleton; asserts each block's existence in each state
- `home_screen_status_line_test.dart` (new) — all 4 states: brand-new (display name only) / lapsed (no plan) / active (X of Y) / complete (Y of Y done)
- `home_screen_action_hero_test.dart` (new) — all 4 states + correct CTA label + tap destinations
- `home_screen_last_session_test.dart` (new, replaces `_stat_cards_test`) — hidden when no history / shows routine + relative date / tap navigates to history
- `home_screen_navigation_test.dart` — update for new CTA paths
- `home_screen_routines_test.dart` — update: starter-routines section no longer present on home; user routines truncate at 3 with See all
- `home_screen_discard_test.dart` — unchanged (resume dialog unrelated)
- `week_bucket_section` tests — update for removed internal cards / counter; chips-only assertions
- `routine_list_screen_test.dart` — new: asserts starter routines section now appears on `/routines`

**Unit:**
- `suggested_next_provider_test.dart` — unchanged
- `weekly_plan_provider_test.dart` — unchanged
- Remove `week_volume_provider_test.dart`

**E2E (`test/e2e/`):**
- `helpers/selectors.ts` — add `HOME.statusLine`, `HOME.actionHero`, `HOME.lastSessionLine`; remove `HOME_STATS.lastSessionCell`, `HOME_STATS.weekVolumeCell`
- `specs/home.spec.ts` — update for new skeleton; add state-transition tests (lapsed → plan / brand-new → beginner CTA / active plan → start next / week complete → new week)
- `specs/routines.spec.ts` — add starter-routines-on-routines-screen assertion
- **Flow changed** — run full E2E suite after QA gate

### Decisions baked in (user-confirmed 2026-04-15)

1. Week-complete status line: `"Week complete — Y of Y done"` (celebratory redundancy OK)
2. Lapsed-state CTA: `"Plan your week"` primary, `"Quick workout"` secondary (drive toward planning)
3. No history virtualization ticket — `ListView.builder` + pagination already correct
4. Ticket: `W8 — Home refresh` (supersedes original W8 perf scope — mark obsolete in PLAN.md)

### Pipeline

1. `tech-lead` TDD implementation → widget tests first, then wire
2. `ui-ux-critic` review of running app after implementation — reject generic-M3 regressions
3. `qa-engineer` gate — test coverage, E2E update, full suite run (flow change)
4. Verify gate (`make ci` fresh) → PR
5. `reviewer` → fixes in-cycle → QA re-validate
6. Squash merge → condense PLAN.md → clear WIP

### Out of scope for this PR

- Streak/consistency mechanic (Phase 15 gamification)
- Sticky week/month headers on `WorkoutHistoryScreen` (separate product ticket if desired)
- PR detection badges on last-session line (follow-up once PR surfacing is polished)
- Any `CustomScrollView` / slivers work

---

## Session snapshot (for refresh)

**Completed this session:**
- W3b: PR #63 merged — input length limits, CHECK constraints applied to hosted Supabase.
- W3b docs: PR #64 merged — condensed W3b in PLAN.md.
- W3: PR #65 merged — stale workout timeout UX. Tests: 1103 total.
- W3 docs: PR #66 merged — condensed W3 in PLAN.md.
- W8 scoping (Apr 15): original perf refactor premise invalidated — HomeScreen has no long list. Re-scoped via product-owner + ui-ux-critic analysis to a full Home IA refresh. History virtualization analyzed and ruled out (already correct). Plan approved by user.

**Sprint C Remaining:** W8 (now Home refresh, in progress) + B6. After both merge, Phase 13 Exit Criterion #5 met.

**Local repo state:** on `main` at `f05d41d`, working tree clean (WIP.md edit pending commit with branch).

**Hosted Supabase:** up to date through `00021_input_length_limits.sql`.

**Next agent to dispatch:** `tech-lead` with W8 Home refresh (prompt composed in this session).
