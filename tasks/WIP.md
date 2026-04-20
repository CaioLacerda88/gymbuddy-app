# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 15d: Language Picker UI + Persistence

**Branch:** `feature/step15d-language-picker`
**Per:** PLAN.md Phase 15d

### UI
- [ ] PREFERENCES section in ProfileScreen between Weekly Goal and DATA MANAGEMENT
- [ ] "Language" row showing current language name in its own language
- [ ] Bottom sheet modal on tap (same pattern as `_showFrequencySheet`)
- [ ] Immediate locale switch via `LocaleNotifier.setLocale()`

### Persistence
- [ ] Hive persistence (offline-safe) — already in LocaleNotifier from 15a
- [ ] Supabase sync (best-effort) — add to LocaleNotifier
- [ ] On startup: Hive first, reconcile with Supabase on login

### Tests
- [ ] Language picker widget tests
- [ ] Locale persistence unit tests (Supabase sync path)

### Verification
- [ ] `dart format .` — 0 changes
- [ ] `dart analyze --fatal-infos` — no issues
- [ ] `flutter test` — all pass
