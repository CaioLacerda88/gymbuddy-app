# GymBuddy — UX Improvements (Pre-Production)

> Improvements to ship before the production readiness sprint ([`PROD-READINESS.md`](./PROD-READINESS.md)).
> Core implementation plan: [`PLAN.md`](./PLAN.md).

---

## 1. Exercise Description & Form Tips

### Problem

Exercises have no context beyond name, muscle group, and equipment type. A user who sees "Romanian Deadlift" in the library has no way to know what distinguishes it from a conventional deadlift, what muscles it emphasizes, or how to perform it safely. This is especially important for:
- Beginners who don't know the movement
- Intermediate lifters picking between similar exercises (e.g., Incline vs Flat Bench)
- Anyone reviewing form cues between sets

### What to add

Two new text fields on every exercise:

**Description** — 1-2 sentences explaining what the exercise is and what it targets.
> *Example:* "A hip-hinge movement that targets the hamstrings and glutes. Performed with a slight knee bend, lowering the barbell along the legs while keeping the back flat."

**Form Tips** — 2-4 bullet-point cues for safe and effective execution.
> *Example:*
> - Keep the bar close to your legs throughout the movement
> - Hinge at the hips, not the lower back
> - Feel the stretch in your hamstrings before reversing
> - Squeeze glutes at the top to lock out

### Data model changes

**Database migration (new):**
```sql
ALTER TABLE exercises ADD COLUMN description TEXT;
ALTER TABLE exercises ADD COLUMN form_tips TEXT;
```

No NOT NULL constraint — existing exercises get these populated via a seed update, custom exercises have them as optional.

**Freezed model update** (`lib/features/exercises/models/exercise.dart`):
```dart
String? description,
String? formTips,
```

**Repository** — no changes needed, fields come through automatically via `select('*')`.

### Default exercises — seed data

Write descriptions and form tips for all ~60 seeded default exercises. Format `form_tips` as newline-separated bullet points in the database (e.g., `"Keep bar close to legs\nHinge at hips, not lower back\nSqueeze glutes at top"`). The UI splits on `\n` and renders as a bulleted list.

This is the bulk of the effort — writing good, concise exercise content for 60 exercises.

### Custom exercises — user-authored

When a user creates a custom exercise, add two optional fields to the create exercise screen:

**Create Exercise screen changes** (`lib/features/exercises/ui/create_exercise_screen.dart`):
- Add **Description** text field below Equipment Type selector
  - Placeholder: "Brief description of the exercise (optional)"
  - `maxLength: 300`, `maxLines: 3`
  - Optional — can be left blank
- Add **Form Tips** text field below Description
  - Placeholder: "Form cues, one per line (optional)"
  - `maxLength: 500`, `maxLines: 5`
  - Helper text: "Enter each tip on a new line"
  - Optional — can be left blank

Both fields are saved to the database on create. No editing yet (editing custom exercises is a v1.1 feature per PLAN.md).

### Exercise detail screen changes

**Exercise detail screen** (`lib/features/exercises/ui/exercise_detail_screen.dart`):

Add two new sections to `_ExerciseDetailBody`, between the image gallery and the PR section:

**Description section** (if `description` is not null/empty):
- Section header: "ABOUT" (same style as existing section headers)
- Body text: `bodyMedium`, `onSurface` at 80% opacity
- No card wrapper — just text with 16dp horizontal padding

**Form Tips section** (if `formTips` is not null/empty):
- Section header: "FORM TIPS"
- Each tip rendered as a row: `Icons.check_circle_outline` (16dp, primary green at 60% opacity) + 8dp gap + tip text (`bodyMedium`)
- Split `formTips` on `\n`, trim each line, filter out empty lines
- 8dp vertical spacing between tips

**If both are null/empty:** sections are omitted entirely (no empty state, no placeholder). The detail screen looks identical to today.

### Exercise detail bottom sheet changes

The active workout bottom sheet (`_showExerciseDetail` in `active_workout_screen.dart`) already renders exercise detail content. It should also show description and form tips when available — same layout as the detail screen.

### Design specs

- Description text: `bodyMedium` (14sp), `onSurface.withValues(alpha: 0.8)`
- Form tip icon: `Icons.check_circle_outline`, 16dp, `primary.withValues(alpha: 0.6)`
- Form tip text: `bodyMedium` (14sp), `onSurface.withValues(alpha: 0.8)`
- Section headers: `bodySmall`, `onSurface.withValues(alpha: 0.55)`, uppercase — matches existing pattern
- Spacing: 24dp above each section header, 8dp below header, 8dp between tips

### Do NOT
- Show description/tips in the exercise list or picker — too much text for a scan-and-tap flow
- Make description/tips required on custom exercises — users creating mid-workout won't stop to write paragraphs
- Use a rich text editor — plain text with newline-separated tips is sufficient
- Add a separate "edit description" flow — that comes with the general "edit exercise" feature in v1.1

### Testing

**Widget tests:**
- Exercise detail screen: renders description when present, omits section when null
- Exercise detail screen: renders form tips as bulleted list, splits on newlines
- Exercise detail screen: handles exercises with description but no tips (and vice versa)
- Create exercise screen: description and form tips fields present, optional, respect maxLength
- Active workout bottom sheet: shows description/tips when available

**Unit tests:**
- Exercise model serialization with new fields
- Form tips parsing (split, trim, filter empty)

**Seed data:**
- Verify all 60 default exercises have description and form_tips after migration

---

## 2. Smart Set Defaults — Copy Previous Set

### Problem

When adding sets to an exercise during a workout, the current logic pre-fills weight/reps from the **previous session's matching set position** (via `lastWorkoutSetsProvider`). This works well for returning exercises. But:

- **First-time exercises** (no history): every set starts at 0kg / 0 reps — the user must manually input identical values 3-5 times for straight sets
- **Extra sets beyond last session** (e.g., 4th set when last session had 3): falls back to 0/0 instead of copying the set you just did
- **No equipment-type awareness**: a barbell exercise defaults to 0kg instead of 20kg (empty bar)

This is the most common friction point in workout logging. 70-80% of working sets use the same weight/reps as the previous set in the same exercise.

### Current state (what already works)

- `addSet()` accepts `defaultWeight` and `defaultReps` params — correct signature
- "Add Set" button pre-fills from `lastSets[position]` (previous session) — correct for returning exercises
- `copyLastSet()` exists (tap set number badge) — copies from previous set in current session
- `fillRemainingSets()` exists (long-press "Add Set") — fills all incomplete sets from last completed
- "Last: 60kg x 10" hint line shows previous session reference — good

### What to change

**Change the priority order in the "Add Set" button** (`active_workout_screen.dart` lines 668-679):

```
Priority 1: Previous session set at matching position (current behavior — keep)
Priority 2: Last set in current session (NEW — copy weight/reps from the set above)
Priority 3: Equipment-type smart defaults (NEW — for first-ever set)
Priority 4: 0/0 (last resort — should rarely be reached)
```

**Warmup → working transition guard:** If the previous set is `setType == warmup` and the new set would be `working` (default), skip the within-session copy. Don't carry warmup weights into working sets. Fall through to priority 1 (previous session) or priority 3 (equipment defaults).

### Equipment-type first-set defaults

Pure function `defaultSetValues(EquipmentType, WeightUnit)`:

| Equipment | Default Weight (kg) | Default Weight (lbs) | Default Reps |
|-----------|--------------------|--------------------|--------------|
| Barbell | 20 | 45 | 5 |
| Dumbbell | 10 | 20 | 10 |
| Cable | 20 | 45 | 10 |
| Machine | 20 | 45 | 10 |
| Bodyweight | 0 | 0 | 10 |
| Bands | 0 | 0 | 12 |
| Kettlebell | 16 | 35 | 10 |

These are pre-populated suggestions, not enforced. Users edit before completing. Low risk of annoying experienced lifters.

### UX safety: checkbox interaction lock

When a new set row appears with pre-filled values, the completion checkbox should be **non-tappable for 600ms** after the row first renders. This prevents accidental confirmation from thumb drift after tapping "Add Set". Below conscious perception — users won't notice the lock.

Implementation: `SetRow` accepts `bool isNew` param, uses a local timer in `initState` to flip it false after 600ms, ignores checkbox taps while true.

### Hint line optimization

When pre-filled values match the "Last: X" reference exactly and the set is not completed, **suppress the hint line** (it's redundant). Show it only when the user has diverged from the reference, making it a meaningful delta indicator instead of a repetitive echo.

### Friction reduction

**Before (first-time exercise, 3 straight sets):**
- Set 1: tap weight, type 80, tap reps, type 8 (4 actions)
- Set 2: tap Add Set, tap weight, type 80, tap reps, type 8 (5 actions)
- Set 3: tap Add Set, tap weight, type 80, tap reps, type 8 (5 actions)
- **Total: 14 actions**

**After:**
- Set 1: adjust from equipment default (2 actions)
- Set 2: tap Add Set — pre-filled from set 1 (1 action)
- Set 3: tap Add Set — pre-filled from set 2 (1 action)
- **Total: 4 actions (71% reduction)**

### Files to modify

1. **`lib/features/workouts/ui/active_workout_screen.dart`** (lines 668-679)
   - Replace `lastSets`-only lookup with the 4-priority fallback chain
   - Pass `isNew: true` to newly added `SetRow` widgets

2. **`lib/features/workouts/ui/widgets/set_row.dart`**
   - Add `bool isNew` parameter
   - 600ms checkbox interaction lock via timer in `initState`
   - Suppress "Last: X" hint when pre-filled values match exactly

3. **`lib/features/workouts/models/exercise.dart`** or new utility
   - `defaultSetValues(EquipmentType, WeightUnit)` pure function

### Do NOT

- Add a settings toggle for "copy from current vs last session" — the right behavior should just work
- Dim or ghost pre-filled values — the numbers are the hero content, dimming breaks visual hierarchy
- Add slide-in or scale animations on new rows — gym pace demands instant feedback
- Auto-copy across warmup → working set type boundaries
- Make equipment defaults user-configurable (v1.1 if ever)

### Testing

**Unit tests:**
- `defaultSetValues` returns correct weight/reps for each equipment type and weight unit
- Priority chain: current session copy > previous session > equipment default > 0/0
- Warmup → working transition skips within-session copy

**Widget tests:**
- New set row appears with copied values from previous set
- Checkbox non-responsive for 600ms after row creation
- Hint line hidden when pre-filled matches last session
- First-ever exercise uses equipment-type defaults

---

## 3. Home Screen Simplification — Enriched Stat Cards, Remove Sections

### Problem

The home screen has three ways to access history and PRs: stat cards (tap to navigate), RECENT section (2-3 rows of past workouts with "View All"), and RECENT RECORDS section (2-3 rows of latest PRs with "View All"). With the stat cards added in Step 10, the RECENT and RECENT RECORDS sections are largely redundant — they compete with the routine cards for attention and dilute the "launchpad" purpose of the home screen.

### What to change

**Remove** both RECENT and RECENT RECORDS sections from the home screen.

**Enrich** the stat cards with a single subtitle line that absorbs the key information those sections provided:
- Workouts card subtitle: relative date of last workout ("3 days ago", "Today", "Yesterday")
- Records card subtitle: most recent PR exercise name ("Bench Press")

**Do not** fill the freed vertical space. The breathing room focuses the screen on routines, which is the primary action.

### Before / After

```
BEFORE                                 AFTER
─────────────────────                  ─────────────────────
GymBuddy                               GymBuddy
Mon, Apr 6                             Mon, Apr 6

┌──────────┐ ┌──────────┐             ┌──────────┐ ┌──────────┐
│ 14       │ │ 3        │             │ 14       │ │ 3        │
│ Workouts │ │ Records  │             │ Workouts │ │ Records  │
└──────────┘ └──────────┘             │ 3 days ago│ │Bench Press│
                                      └──────────┘ └──────────┘
MY ROUTINES
[Push A  chest·shoulders·triceps]      MY ROUTINES
[Pull A  back·biceps            ]      [Push A  chest·shoulders·triceps]
[Legs A  quads·hamstrings       ]      [Pull A  back·biceps            ]
                                       [Legs A  quads·hamstrings       ]
RECENT                  View All
[Push A · 3 days ago · 52 min  ]            [Start Empty Workout]
[Pull A · 5 days ago · 48 min  ]

RECENT RECORDS          View All
[Bench Press · 100kg · Apr 3   ]
[Squat · 140kg · Apr 1         ]

     [Start Empty Workout]
```

### Card design

Keep 72dp height. Stack three lines with tightened spacing:

```
┌──────────────────────────┐
│  14                      │  ← headlineMedium (24sp w700) primary green
│  Workouts                │  ← bodySmall (12sp) onSurface 55% opacity
│  3 days ago              │  ← 11sp, primary green at 70% opacity
└──────────────────────────┘
```

- Subtitle: 11sp, `primary.withValues(alpha: 0.7)`, `maxLines: 1`, `overflow: TextOverflow.ellipsis`
- `mainAxisAlignment: MainAxisAlignment.start` with `padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)`
- If subtitle is null/empty, the slot collapses (no placeholder text)

### Data sources (zero new queries)

- **Workouts subtitle**: `workoutHistoryProvider.value?.firstOrNull?.finishedAt` → format as relative date via existing `WorkoutFormatters`. Already watched by the home screen.
- **Records subtitle**: `recentPRsProvider.value?.firstOrNull` → exercise name. Already loaded (previously consumed by the now-removed section).

### Edge cases

| State | Workouts card | Records card |
|-------|--------------|--------------|
| 0 workouts, 0 records | "0" / "Workouts" / no subtitle | "0" / "Records" / no subtitle |
| 3 workouts, 0 records | "3" / "Workouts" / "Yesterday" | "0" / "Records" / no subtitle |
| 14 workouts, 3 records | "14" / "Workouts" / "3 days ago" | "3" / "Records" / "Bench Press" |
| Loading | "--" / "Workouts" / no subtitle | "--" / "Records" / no subtitle |

### Files to modify

1. **`lib/features/workouts/ui/home_screen.dart`**
   - Remove RECENT section (`historyAsync.when(...)` block and `_RecentWorkoutRow`/`_RecentWorkoutsSkeleton` widgets)
   - Remove RECENT RECORDS section (the `RecentPRsSection` import and usage)
   - Update `_StatCard` to accept optional `String? subtitle` param
   - Update `_StatCardsRow` to derive subtitles from existing providers

2. **`lib/features/personal_records/ui/widgets/recent_prs_section.dart`**
   - Can be deleted (no longer used anywhere)
   - `recentPRsProvider` stays in `pr_providers.dart` — repurposed for card subtitle

### Do NOT
- Add a third stat card (streak, volume, etc.) — two at half-width is the right density
- Show a timestamp on the Records card subtitle — "Bench Press · 4d ago" won't fit at this width
- Render "No workouts yet" or "Start your first" as subtitle text — the "0" is honest enough
- Conditionally hide the Records card when count is 0 — layout shift is worse than showing "0"
- Fill the freed space with anything new — the breathing room is a feature

### Testing

**Widget tests:**
- Stat card renders subtitle when provided
- Stat card omits subtitle when null (no extra padding/gap)
- Home screen no longer renders RECENT or RECENT RECORDS sections
- Workouts card subtitle shows relative date from most recent workout
- Records card subtitle shows exercise name from most recent PR
- Subtitle text truncates with ellipsis on long exercise names
