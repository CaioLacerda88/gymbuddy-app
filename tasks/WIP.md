# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## P8 — New-user empty-state CTA + beginner routine recommendation

**Branch:** `feature/p8-new-user-cta`
**Source:** PLAN.md Phase 13 → Sprint B → Slot 1 (lines ~571-579)
**Owner:** tech-lead → qa-engineer → reviewer
**Effort target:** 2-3h

### Context (from product-owner + ui-ux-critic synthesis)

Today's first-run home screen pushes a brand-new user to "Plan your week" (`_EmptyBucketState` → `/plan/week`) — a configuration task before they ever lift. Below it sits a STARTER ROUTINES list of 4 default templates (Push Day / Pull Day / Leg Day / Full Body) — paradox of choice for someone who doesn't know what those splits mean. Stat cells say "No workouts yet / No volume yet". Net effect: dead-end.

P8 collapses the decision: hero card shows a single recommended beginner workout (Full Body), tap → straight into active workout. Stat cells hide while empty.

**Critical condition:** gate on `workoutCount == 0`, NOT a one-shot first-launch flag. Returning users who haven't lifted yet must still see the CTA (most signups don't lift in session 1).

### Spec

#### Behavior

- **Show beginner CTA when:** plan is null OR plan.routines empty AND user has zero finished workouts AND a default Full Body routine exists in `routineListProvider`.
- **Tap action:** call existing `startRoutineWorkout(context, ref, fullBodyRoutine)` — jumps straight into active workout. No detail screen, no modal, no "are you sure".
- **Fallback:** if Full Body routine not found, fall back to first available default routine. If no defaults at all, render `SizedBox.shrink()` (current behavior).
- **Once `workoutCount > 0`:** beginner CTA disappears, normal home behavior resumes (`_EmptyBucketState` "Plan your week" prompt OR active plan section).

#### Visual (extends existing `_SuggestedNextCard` pattern)

- Container: 80dp height (vs. 56dp for the regular suggested-next card — this is THE primary CTA for a brand-new user)
- Background: `_cardColor` (`0xFF232340`)
- Left border: 4px `_primaryGreen` (`0xFF00E676`)
- Right side: `Icon(Icons.play_arrow, color: _primaryGreen, size: 28)`
- Label (top, small caps): `YOUR FIRST WORKOUT` (use `labelSmall`, ~55% opacity)
- Headline: routine name (e.g. `Full Body`) — `titleMedium` / `FontWeight.w700` / full white
- Stats line: `6 exercises · ~45 min` — `bodySmall` / ~55% opacity
- Entire card is one tap target (no separate button)
- No gradient (the existing `_CreateRoutineCta` owns gradients; this card stays flat with accent border so hierarchy doesn't collapse)

#### Stat cell hide

- In `_ContextualStatCells` (`home_screen.dart`), when `lastSession == null && weekVolume.value == 0` → return `SizedBox.shrink()`. One guard at the top. Keep current behavior when either has data.

### Acceptance criteria

- [ ] Brand-new user (zero finished workouts) lands on Home → sees the beginner CTA in the THIS WEEK slot, NOT the "Plan your week" prompt
- [ ] CTA shows: `YOUR FIRST WORKOUT` label, routine name (Full Body), `6 exercises · ~45 min`
- [ ] Tap → enters active workout pre-filled from Full Body routine (no intermediate screen)
- [ ] User who has logged ≥1 workout sees the existing flow (no beginner CTA)
- [ ] Stat cells hidden when both are empty; visible when either has data
- [ ] If Full Body default routine is missing, fall back to first default routine
- [ ] If no default routines exist at all, render nothing (no broken card)
- [ ] No hardcoded colors/styles — uses `AppTheme` tokens / existing constants
- [ ] Widget test: renders CTA when condition met; no CTA when workoutCount > 0; no CTA when no defaults
- [ ] E2E test: new user signup → home shows CTA → tap → lands on `/workout/active` with Full Body routine loaded

### Files to modify / create

- `lib/features/weekly_plan/ui/widgets/week_bucket_section.dart` — add `_BeginnerRoutineCta` widget; new branch in `WeekBucketSection.build()` for `(plan == null || plan.routines.isEmpty) && workoutCount == 0 && hasDefault`; render before/instead of `_EmptyBucketState`
- `lib/features/workouts/ui/home_screen.dart` — `_ContextualStatCells`: hide when both empty
- `lib/features/workouts/providers/workout_history_providers.dart` — add `workoutCountProvider` if not present (or reuse an existing count signal — check `lastSessionProvider` neighbours first)
- `test/widget/weekly_plan/beginner_routine_cta_test.dart` — new widget tests
- `test/widget/workouts/contextual_stat_cells_test.dart` — add hide-when-empty case (or augment existing)
- `test/e2e/specs/onboarding.spec.ts` (or `auth.spec.ts` — wherever the new-user flow lives) — new E2E for first-run CTA + tap → active workout. Selectors added to `helpers/selectors.ts`.

### QA notes

- E2E flow change → full Playwright suite must pass (per CLAUDE.md "Navigation changes count as flow changes")
- New test user with `workoutCount == 0` may need a fresh fixture in `test/e2e/fixtures/test-users.ts` + `global-setup.ts`
- Selector convention: Playwright `role=button[name*=...]` not CSS `flt-semantics` (Flutter 3.41.6 AOM)
- SnackBar `.first()`, search inputs `.last()`, `flutterFill()` not `page.fill()`

### Out of scope (explicit)

- No picker (one routine, not three)
- No "Skip for now" / dismiss link on the card
- No motivational copy ("Let's go!" etc.) — headline = concrete routine name
- No multi-screen onboarding flow
- No new routine content (P9 owns content backfill)
- No modal/bottom sheet between tap and active workout
- No changes to STARTER ROUTINES list visibility (leave as-is for now; PO can re-test post-merge)

---

*Last merged: PR #53 (fix(exercises): rehost default exercise images to Supabase Storage — P4).*
