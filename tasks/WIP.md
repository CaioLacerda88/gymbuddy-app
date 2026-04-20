# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 15b: Full String Extraction

**Branch:** `feature/step15b-string-extraction`
**Per:** PLAN.md Phase 15b

### Enum Refactoring
- [x] `MuscleGroup.localizedName(AppLocalizations l10n)` -- 7 values (already done in 15a)
- [x] `EquipmentType.localizedName(AppLocalizations l10n)` -- 7 values (already done in 15a)
- [x] `SetType.localizedName(AppLocalizations l10n)` -- 4 values (already done in 15a)
- [x] `RecordType.localizedName(AppLocalizations l10n)` -- 3 values (already done in 15a)
- [x] `WeightUnit.localizedName(AppLocalizations l10n)` -- 2 values (already done in 15a)
- [x] All call sites already use `.localizedName(l10n)` (confirmed ~26 usages)

### Formatter Localization
- [x] `WorkoutFormatters` -- added `l10n` and `locale` params for date/volume formatting
- [x] `AuthErrorMessages` -- already uses `AppLocalizations` (done in 15a)
- [x] `WorkoutFormatters.formatVolume` -- accepts `locale` param for NumberFormat
- [x] `WorkoutFormatters.formatWorkoutDate` -- accepts `l10n` + `locale` params
- [x] `WorkoutFormatters.formatRelativeDate` -- accepts `l10n` for Today/Yesterday/etc
- [x] `_formatRelativeDate` in workout_history_providers.dart -- delegates to WorkoutFormatters
- [x] `_generateWorkoutName` in active_workout_notifier.dart -- uses `DateFormat` instead of hardcoded weekday/month arrays

### Screen String Extraction
- [x] Auth screens -- already extracted in 15a
- [x] Home screens -- already extracted in 15a
- [x] Exercise screens -- extracted remaining semantics labels
- [x] Workout screens -- extracted tooltips, semantics, "Cancel" button, "No records yet"
- [x] Routine screens -- already extracted in 15a
- [x] Profile screens -- already extracted in 15a
- [x] Records screens -- already extracted in 15a
- [x] Weekly Plan screens -- already extracted in 15a

### Progress Chart Extraction (~12 strings)
- [x] "Could not load progress" -> `couldNotLoadProgress`
- [x] "Log your first set to start tracking" -> `logFirstSetToTrack`
- [x] "e1RM" / "Weight" metric labels -> `chartMetricE1rm` / `chartMetricWeight`
- [x] "30 days" / "90 days" / "all time" window labels -> `chartWindowDays30` / `chartWindowDays90` / `chartWindowAllTime`
- [x] Trend copy strings -> `oneWorkoutLoggedKeepGoing`, `workoutsLoggedKeepGoing`, `holdingSteadyAt`, `trendUp`, `trendDown`
- [x] PR ring semantics -> `prMarkerAt`
- [x] `_buildTrendCopy` now accepts `l10n` parameter

### Set Row / Active Workout Extraction (~15 strings)
- [x] Set number semantics -> `setNumberSemantics`, `setNumberCopySemantics`
- [x] Set tooltips -> `tooltipCopyLastSetAndChangeType`, `tooltipChangeType`
- [x] Set type abbreviations -> `setTypeAbbrWorking`, `setTypeAbbrWarmup`, `setTypeAbbrDropset`, `setTypeAbbrFailure`, `setTypeAbbrWarmupShort`
- [x] Checkbox semantics -> `setCompleted`, `markSetAsDone`
- [x] RPE indicator -> `rpeValue`, `setRpe`, `rpeLabel`, `rpeMenuItem`
- [x] Reorder tooltips -> `reorderExercisesTooltip`, `exitReorderModeTooltip`
- [x] Exercise card semantics -> `exerciseSemanticsLabel`
- [x] Fill remaining semantics -> `fillRemainingSetsSemantics`
- [x] Add exercise FAB semantics -> `addExerciseToWorkoutSemantics`
- [x] Exercise picker semantics -> `searchExercisesToAddSemantics`, `addExerciseSemantics`
- [x] "Cancel" button -> uses existing `cancel` key

### Other Extraction
- [x] splash_screen.dart "GymBuddy" -> `appName`
- [x] last_session_line.dart "Last: " -> `lastSessionPrefix` (existing key)
- [x] last_session_line.dart semantics -> `lastSessionSemantics`
- [x] exercise_list_screen.dart semantics -> `searchExercisesSemantics`, `exerciseItemSemantics`, `createNewExerciseSemantics`
- [x] create_exercise_screen.dart semantics prefixes -> `muscleGroupSemanticsPrefix`, `equipmentTypeSemanticsPrefix`
- [x] exercise_detail_screen.dart delete semantics -> `deleteExerciseSemantics`
- [x] workout_detail_screen.dart set type abbreviations -> localized
- [x] resume_workout_dialog.dart weekday/clock formatting -> uses `DateFormat` with locale param

### Shared Widgets
- [x] offline_banner.dart -- already uses l10n
- [x] pending_sync_badge.dart -- already uses l10n
- [x] sync_failure_card.dart -- already uses l10n
- [x] Other shared widgets -- checked, no remaining hardcoded strings

### ARB Files
- [x] `app_en.arb` -- 411 string keys (up from ~200)
- [x] `app_pt.arb` -- 411 keys matching (English copies as placeholders)

### Verification
- [x] `dart format .` -- 0 changes
- [x] `dart analyze --fatal-infos` -- no issues
- [x] `flutter test` -- all 1357 pass
- [ ] E2E regression -- pending QA

### Known Limitations (by design)
- Repository-layer error messages (exercise_repository.dart "An exercise with this name already exists") are not localized -- per architecture, l10n happens at UI layer
- Enum `displayName` getters remain as non-localized fallbacks (all UI call sites use `localizedName(l10n)`)
- `_generateWorkoutName()` in active_workout_notifier.dart uses `DateFormat` but no locale param since providers lack BuildContext; the workout name "Workout -- Mon Apr 15" is stored as data
