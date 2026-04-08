# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Step 12: Weekly Training Plan + Bug Fixes — `feature/step12-weekly-training-plan`

**Ref:** PLAN.md Step 12, BUGS.md

### Phase 1: Step 12 Core (new files — DONE)
- [x] Supabase migration `00011_create_weekly_plans.sql`
- [x] Freezed models: `WeeklyPlan`, `BucketRoutine`
- [x] `WeeklyPlanRepository` CRUD
- [x] `WeeklyPlanNotifier` + `suggestedNextProvider` + computed providers
- [x] `RoutineChip` widget (done/next/remaining states)
- [x] `WeekBucketSection` (home screen section)
- [x] `WeekReviewSection` (week complete state)
- [x] `PlanManagementScreen` + `AddRoutinesSheet`

### Phase 2: Step 12 Wiring (existing file mods — IN PROGRESS)
- [x] Profile model: add `trainingFrequencyPerWeek` field + `make gen`
- [x] Profile repository: add `trainingFrequencyPerWeek` to upsert + `updateTrainingFrequency`
- [x] Profile providers: update `saveOnboardingProfile` + `updateTrainingFrequency`
- [x] Onboarding screen: add frequency chips (2x-6x) on page 2
- [x] Profile screen: add "Weekly goal" row with bottom sheet
- [x] Home screen: add `WeekBucketSection` between stat cards and MY ROUTINES
- [x] App router: add `/plan/week` route
- [x] Active workout notifier: bucket completion hook in `finishWorkout()`
- [x] Fix test mocks for changed signatures
- [x] `dart format` + `dart analyze` + `flutter test`
- [ ] **COMMIT**: `feat(workouts): integrate weekly training plan into app`

### Phase 3: Bug Fixes (per BUGS.md — TODO)
- [ ] **BUG-1 (P0):** `context.go('/records')` → `context.push('/records')` in home_screen.dart. Audit all stat card navs
- [ ] **COMMIT**: `fix(core): use context.push for stat card navigation (BUG-1)`
- [ ] **BUG-4 (P0):** Guard null weight in `pr_detection_service.dart` bodyweight branch. Display PRs as `100 kg x 5`
- [ ] **COMMIT**: `fix(progress): guard null weight in PR detection, improve display (BUG-4)`
- [ ] **BUG-2 (P1):** Guard null weight copy in `active_workout_screen.dart` addSet chain. Always copy weight + reps from last set
- [ ] **COMMIT**: `fix(workouts): copy weight and reps when adding sets (BUG-2)`
- [ ] **BUG-3 (P2):** Hide Fill button when no fillable sets. Rename to "Fill remaining"
- [ ] **COMMIT**: `fix(workouts): hide Fill button when no fillable sets, rename (BUG-3)`

### Phase 4: Review + QA (TODO)
- [ ] Reviewer audits all commits against PLAN.md + BUGS.md
- [ ] QA engineer writes widget tests for new weekly plan widgets + bug fix coverage
- [ ] Final `make ci` pass
- [ ] Push + create PR
