# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Step 12.3b — Copy Fix + Content Expansion

**Status:** In progress — tech-lead implementing
**Branch:** `feature/step12.3b-content-expansion`
**Source:** PLAN.md Step 12.3b

### Checklist

- [ ] Create branch `feature/step12.3b-content-expansion`
- [ ] **Copy fix**: Change "goal reached" → "planned" variants in `plan_management_screen.dart:527`
  - Below cap: `"$bucketCount/$trainingFrequency planned this week"`
  - At/above cap: `"$trainingFrequency/$trainingFrequency planned — ready to go"`
- [ ] **Dart enum**: Add `cardio` to `MuscleGroup` in `exercise.dart` (with icon + displayName)
- [ ] **Code gen**: Run `make gen` after enum change (freezed/json_serializable)
- [ ] **SQL migration** `00013_expand_exercises_and_routines.sql`:
  - `ALTER TYPE muscle_group ADD VALUE 'cardio'`
  - INSERT ~37 new exercises (idempotent pattern from 00007)
  - INSERT 5 new routine templates (Upper/Lower A&B, 5x5 Strength, Full Body Beginner, Arms & Abs)
- [ ] **Action sheet**: Update `routine_action_sheet.dart` for `isDefault` routines
  - Default routines: Start + Duplicate and Edit (no Edit/Delete)
  - User routines: keep current Edit/Delete
- [ ] **Routine list**: Add `onLongPress` to default routine cards in `routine_list_screen.dart`
- [ ] `dart format .` — clean
- [ ] `dart analyze --fatal-infos` — no issues
- [ ] `flutter test` — all pass
