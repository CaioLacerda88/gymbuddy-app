# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 15c: Portuguese Translations + Exercise Content

**Branch:** `feature/step15c-portuguese-translations`
**Per:** PLAN.md Phase 15c

### Portuguese UI Translations
- [ ] Translate all ~396 ARB keys in `app_pt.arb` from English placeholders to proper pt-BR
- [ ] "PR" kept untranslated (Brazilian gym culture uses it)
- [ ] PT-BR strings shorter where overflow risk exists

### Exercise Content Translation
- [ ] Create `lib/core/l10n/exercise_l10n.dart` (slug helper + lookup)
- [ ] Translate exercise names keyed by slug (~60 exercises)
- [ ] Translate exercise descriptions + form_tips (~60 exercises)
- [ ] Translate default routine names

### Quality
- [ ] ARB completeness unit test (`test/unit/core/l10n/arb_completeness_test.dart`)
- [ ] All tests pass
- [ ] `dart format .` — 0 changes
- [ ] `dart analyze --fatal-infos` — no issues
