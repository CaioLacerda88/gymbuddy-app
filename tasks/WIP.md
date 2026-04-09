# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Step 12.2c — Plan Management UX Polish

**Branch:** `feature/step12.2c-plan-ux-polish`
**Source:** Per PLAN.md Step 12.2c

### Checklist

- [ ] Auto-fill button visible in `_EmptyState` (plan_management_screen.dart)
- [ ] Inline "X/Y goal reached" text with actual numbers in `_AddRoutineRow`
- [ ] SuggestedNextPill elevated to prominent tappable card at top of THIS WEEK section
- [ ] Widget tests for all 3 changes
- [ ] `dart format . && dart analyze --fatal-infos && flutter test` passes

### Files to modify

- `lib/features/weekly_plan/ui/plan_management_screen.dart` — auto-fill in empty state, inline soft-cap numbers
- `lib/features/weekly_plan/ui/widgets/week_bucket_section.dart` — SuggestedNextPill → prominent card
- `test/widget/features/weekly_plan/` — new/updated widget tests
