# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 15a: i18n Infrastructure + E2E Selector Migration

**Branch:** `feature/step15a-i18n-infrastructure`
**Per:** PLAN.md Phase 15a

### i18n Infrastructure
- [x] Add `flutter_localizations` to `pubspec.yaml`
- [x] Create `l10n.yaml` config
- [x] Create `lib/l10n/app_en.arb` (~50 core strings)
- [x] Create `lib/l10n/app_pt.arb` (~50 core strings, Portuguese)
- [x] Add `gen-l10n` target to Makefile, wire into `make gen` and `make ci`
- [x] Create `LocaleNotifier` provider (`lib/core/l10n/locale_provider.dart`)
- [x] Wire `MaterialApp.router()` with delegates, supportedLocales, locale
- [x] Add `locale` field to `Profile` Freezed model + run `make gen`
- [x] Add `updateLocale()` to `ProfileRepository`
- [x] Create Supabase migration `00022_add_locale_to_profiles.sql`

### Widget Test Harness
- [x] Create shared test helper (`test/helpers/localized_widget.dart`)
- [ ] Update ~56 widget test files to pin `locale: Locale('en')` + add delegates (deferred to 15b — no widgets use AppLocalizations yet)

### E2E Selector Migration
- [x] Spike: `Semantics(identifier: ...)` → `flt-semantics-identifier` DOM attr ✓
- [x] Batch 1: ~60 selectors migrated (AUTH, NAV, ONBOARDING, EXERCISES, WORKOUT, HOME partial)
- [x] Batch 2: ~75 selectors migrated (ROUTINE, PROFILE, MANAGE_DATA, WEEKLY_PLAN, OFFLINE, PR, etc.)
- [x] Total: ~135 selectors migrated to `[flt-semantics-identifier="xxx"]`
- [ ] Verify E2E tests pass with new selectors (requires flutter build web + Supabase)

### E2E Selector Fixes (post-initial implementation)
- [x] Root Cause 1: Add `Semantics(identifier: 'workout-add-exercise')` to `_EmptyWorkoutBody`'s FilledButton (was only on FAB shown when exercises exist)
- [x] Root Cause 2: Replace `page.fill()` → `flutterFill()` in auth edge case tests
- [x] Root Cause 3: Add `.toLowerCase()` to `equipmentFilter` selector function
- [x] Root Cause 4: Add `Semantics(container: true)` in onboarding `_WelcomePage` to prevent text merge
- [x] Root Cause 5: Add `container: true` to `_HeroBanner` and `home-quick-workout` Semantics wrappers
- [x] Fix 6: ActionHero headline text merge — wrap in `Semantics(container: true)` for separate AOM node
- [x] Fix 7: Profile manage-data click interception — identifier inside InkWell (no container)
- [x] Fix 8: Account deletion — explicit `context.go('/login')` redirect after deleteAccount()
- [x] Fix 9: PR exercise record card — add `Semantics(identifier: 'pr-exercise-card')`, update selector from broken `flt-semantics[role="button"]`
- [x] Fix 10: PR entry test — use `exerciseRecordCard` selector instead of `text=` (AOM text merge)
- [x] Fix 11: Weekly plan chip test — replace `thisWeekHeader` with `HOME.statusLine` (correct for active plan state)
- [x] Fix 12: NEW WEEK button — correct selector from `weekly-plan-new-week` to `home-start-new-week` (ActionHero, not WeekReviewSection)
- [x] Fix 13: WeekReviewSection — replace GestureDetector with InkWell for semantic accessibility
- [x] Fix 14: Push Day dumbbell test — scroll down before clicking (viewport culling)

### Verification
- [x] `dart format .` — 0 changes
- [x] `dart analyze --fatal-infos` — no issues
- [x] `flutter test` — 1339 pass
- [x] `flutter build web` — success
- [x] E2E round 6 — 151 passed, 4 failed (PR entry, weekly plan chip, NEW WEEK selector, Push Day scroll)
- [x] E2E fixes applied — all 4 previously failing tests pass in isolation
- [ ] E2E round 7 — full regression (running)
- [ ] QA review
- [ ] Code review
