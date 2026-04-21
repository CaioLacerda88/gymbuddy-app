# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 15e: QA + E2E + Overflow Polish

**Branch:** `feature/step15e-qa-e2e-overflow`
**Per:** PLAN.md Phase 15e

### Infrastructure
- [ ] `setLocale()` E2E helper in `test/e2e/helpers/app.ts`
- [ ] New test user `smokeLocalization` in `test/e2e/fixtures/test-users.ts` + `global-setup.ts`
- [ ] `profiles.locale = 'pt'` seeded for that user so app boots in Portuguese

### Overflow fixes (lib/)
- [ ] Bottom nav labels — `maxLines: 1` + `ellipsis`, validated at 320dp with pt-BR
- [ ] Weight Unit label → confirm pt-BR copy doesn't overflow; add `ellipsis`
- [ ] Any `_StatCard` labels still in use — `maxLines: 1` + `ellipsis`
- [ ] Locale-aware number formatting for weights (`NumberFormat` → `80,5 kg` in pt-BR)
- [ ] Locale-aware date formatting (`DateFormat` → `18/04/2026` in pt-BR)

### Widget tests
- [ ] Overflow regression test at 320dp width with pt-BR locale
- [ ] Number/date formatting unit tests for pt-BR

### E2E tests (`test/e2e/specs/localization.spec.ts`)
- [ ] Bottom nav labels render in pt-BR
- [ ] Profile screen shows pt-BR copy
- [ ] Language picker switches from en→pt and persists across reload
- [ ] Exercises screen pt-BR rendering
- [ ] Workout active pt-BR rendering
- [ ] Weight formatting shows `80,5 kg`
- [ ] Date formatting shows `dd/MM/yyyy`
- [ ] ~8 tests total, tagged @smoke where appropriate

### Verification
- [ ] `dart format .` — 0 changes
- [ ] `dart analyze --fatal-infos` — no issues
- [ ] `flutter test` — all pass (~1339)
- [ ] Full E2E suite — all pass including 8 new localization tests
