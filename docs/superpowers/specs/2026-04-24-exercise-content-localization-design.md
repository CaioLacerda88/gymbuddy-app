# Phase 15f — Exercise Content Localization (Design Spec)

**Status:** design — awaiting user review
**Date:** 2026-04-24
**Scope:** localize exercise `name`, `description`, `form_tips` for the 150 default exercises in pt-BR, with a schema that scales to 3-5+ languages.
**Ship:** single atomic PR; no staged rollout.

---

## 1. Problem

Exercise content (`exercises.name`, `description`, `form_tips`) ships in English only. The 15c/e Dart helper `localizedExerciseName()` exists but is never called from `lib/`; the UI renders the raw English DB column. pt-BR users see English exercise names on the list, detail, active-workout, history, and PR screens.

Goal: end-to-end localization of the 150 default exercises without hard-coding locale into the schema, so adding es-ES / fr-FR later is a data migration, not a refactor.

## 2. Locked decisions (from brainstorming)

| # | Decision | Rationale |
|---|---|---|
| D1 | Scope: only `is_default = true` rows. User-created rows stay monolingual in the creator's locale. | Product intent: preset exercises are shared public content; user customs are private and typically single-language. |
| D2 | Pattern: dedicated `exercise_translations` table — **not** sibling columns (`name_en`, `name_pt`), **not** JSONB. | Translations table is the industry-standard i18n pattern; scales to N locales without schema changes. |
| D3 | Storage: **symmetric** (Option B). EN lives in `exercise_translations` alongside pt; `exercises.name/description/form_tips` columns are dropped. | No locale is privileged. Adding locales never means "add a sibling column." |
| D4 | Add `exercises.slug TEXT NOT NULL` — locale-independent semantic identifier. | Stable key for seeding, matching, and future locale additions; decouples migrations from display text. |
| D5 | Single atomic PR. No phased rollout. No feature flag. | User directive: "no deferral of steps, let's implement everything we need for a clean architecture." |
| D6 | Translation workflow: hybrid AI-drafted + human review (glossary-first pass, then full seed review). | Quality over quick fixes; 150 rows × ~30s skim = ~75 min human QA budget. |
| D7 | Unit of reuse for `Exercise` shape: keep the existing Freezed model; server-side RPC returns the same fields (name/description/form_tips), just resolved via fallback cascade. | Zero UI changes needed below the repository layer. |

## 3. Architecture overview

```
┌──────────────┐     locale-keyed cache keys       ┌──────────────────────┐
│     UI       │ ◀──────── provider layer ────────▶│  Riverpod providers  │
└──────────────┘                                    │  (read localeProvider)│
                                                   └──────────┬───────────┘
                                                              │ locale passed
                                                              ▼
                                                   ┌──────────────────────┐
                                                   │   Repositories       │
                                                   │  (locale as param)   │
                                                   └──────────┬───────────┘
                                                              │ RPC call
                                                              ▼
                                        ┌─────────────────────────────────────┐
                                        │  Supabase RPCs (4 total):           │
                                        │   fn_exercises_localized            │
                                        │   fn_search_exercises_localized     │
                                        │   fn_insert_user_exercise           │
                                        │   fn_update_user_exercise           │
                                        └─────────────────────┬───────────────┘
                                                              │
                                        ┌─────────────────────┴───────────────┐
                                        │                                     │
                                        ▼                                     ▼
                              ┌──────────────────┐                ┌────────────────────┐
                              │    exercises     │                │ exercise_translations│
                              │   (slug, meta)   │◀──FK CASCADE──▶│  (exercise_id, locale,│
                              │   NO name col    │                │   name, desc, tips) │
                              └──────────────────┘                └────────────────────┘
```

**Fallback cascade** inside every read RPC: resolve display name as `translation[p_locale]` → `translation['en']` → any available translation. EN sits second not because it is privileged storage (it isn't — D3), but because migration 00032 backfills EN for every row, making it a guaranteed-available safety net. The "any available" tier only matters for future locale additions where a partial translation exists.

**Two-query merge** at the caller layer: workout history / PR list / routines stop using Supabase embedded selects (`exercise:exercises(name)`). Instead they (1) fetch their primary rows, (2) collect distinct `exercise_id`s, (3) call `fn_exercises_localized` with `p_ids` batch. Merge in Dart. One extra round-trip (~20-40ms hosted); scalable API.

## 4. Migrations (five files, single PR)

| # | File | Purpose |
|---|---|---|
| 00030 | `add_exercise_slug.sql` | Add `exercises.slug TEXT` nullable → per-row UPDATE backfill from hardcoded name→slug map (matches `exerciseSlug()` in `lib/core/l10n/exercise_l10n.dart`) → hard assert no NULL → `SET NOT NULL` → partial unique index on defaults only + general lookup index. |
| 00031 | `create_exercise_translations.sql` | Create `exercise_translations` table (PK `(exercise_id, locale)`, CHECK `locale IN ('en','pt')`, CHECK length bounds on name/description/form_tips, FK `ON DELETE CASCADE`). Enable RLS + five policies (§5). Add `touch_updated_at` trigger. Index on `locale`. |
| 00032 | `backfill_exercise_translations_en.sql` | `INSERT ... SELECT` copies every `exercises.name/description/form_tips` into `exercise_translations` as `'en'` (covers defaults AND user-created rows). Hard assert `COUNT(exercises) = COUNT(translations WHERE locale='en')`. |
| 00033 | `seed_exercise_translations_pt.sql` | `INSERT ... SELECT` from `VALUES (slug, name, description, form_tips), ...` JOINed on `exercises.slug` for all 150 defaults with `locale = 'pt'`. Hard assert pt count equals default count. |
| 00034 | `drop_exercise_name_columns_and_add_rpcs.sql` | Create `pg_trgm` extension, all four RPCs (§6), trigram index on `exercise_translations.name`, drop old `exercises_name_idx`, drop columns `name/description/form_tips` from `exercises`, replace the user-created unique-name constraint with an RPC-level check. |

**Why five files not one:**
- Small transactions → Supabase runner handles cleanly; bisection on failure is trivial.
- CI pairing check scans each file separately.
- Review ergonomics: 00030 is pure structure, 00033 is pure pt content, 00034 is cut-over — reviewer can focus per-file.

**Transaction discipline:** each file wrapped in `BEGIN; ... COMMIT;`. All forward migrations are idempotent where possible (`CREATE OR REPLACE FUNCTION`, `CREATE INDEX IF NOT EXISTS`).

## 5. RLS policies (exercise_translations)

All `SECURITY INVOKER` — RPCs rely on row-level policies, not definer privileges.

| Policy | Operation | Predicate |
|---|---|---|
| `exercise_translations_select_defaults` | SELECT | Row belongs to a default exercise (`is_default = true AND deleted_at IS NULL`). Universally readable by authenticated users. |
| `exercise_translations_select_own` | SELECT | Row belongs to `auth.uid()`'s exercise. |
| `exercise_translations_insert_own` | INSERT | Caller owns the referenced `exercise_id`. Default translations written by migrations bypass RLS (postgres role). |
| `exercise_translations_update_own` | UPDATE | Same as insert — USING + WITH CHECK both. |
| `exercise_translations_delete_own` | DELETE | Same. CASCADE handles account-delete path; explicit policy covers direct delete. |

**`exercises` table:** no policy changes. Existing `is_default = true OR user_id = auth.uid()` SELECT + soft-delete policy continue to apply to the stripped-down schema.

**Audit step in staging:** `EXPLAIN SELECT * FROM exercise_translations WHERE exercise_id = '<another-user-custom-id>'` as a non-owner user → must return no rows.

## 6. RPCs (four functions)

### 6.1 `fn_exercises_localized`
- **Signature:** `(p_locale TEXT, p_user_id UUID, p_muscle_group TEXT DEFAULT NULL, p_equipment_type TEXT DEFAULT NULL, p_ids UUID[] DEFAULT NULL, p_order TEXT DEFAULT 'name') RETURNS TABLE(...localized exercise shape...)`.
- **Behavior:** one row per matching exercise; `name/description/form_tips` resolved via fallback cascade. Filters: `is_default = true OR user_id = p_user_id`, `deleted_at IS NULL`, optional muscle/equipment/id filters. Sort: by resolved `name` ASC (default) or `created_at DESC` (enum-constrained `p_order`).
- **Batch mode:** if `p_ids` is non-null and non-empty, other filters ignored except user/delete scope. Hard cap `array_length(p_ids, 1) <= 500`.
- **Used by:** `getExercises`, `getExerciseById`, `recentExercises`, `getExercisesByIds` (new).

### 6.2 `fn_search_exercises_localized`
- **Signature:** `(p_query TEXT, p_locale TEXT, p_user_id UUID, p_muscle_group TEXT DEFAULT NULL, p_equipment_type TEXT DEFAULT NULL) RETURNS TABLE(...same shape...)`.
- **Behavior:** trigram match against `exercise_translations.name` for the user's locale OR `'en'` (cross-locale discoverability). Sort by `similarity() DESC, name ASC`. Visibility enforced via join to `exercises`.
- **Used by:** `searchExercises`.

### 6.3 `fn_insert_user_exercise`
- **Signature:** `(p_user_id UUID, p_locale TEXT, p_name TEXT, p_muscle_group TEXT, p_equipment_type TEXT, p_description TEXT DEFAULT NULL, p_form_tips TEXT DEFAULT NULL) RETURNS TABLE(...)`.
- **Behavior:** asserts `auth.uid() = p_user_id`; duplicate-name check (`EXISTS` across the user's translations) → raises SQLSTATE `23505`; inserts `exercises` with derived slug; inserts one `exercise_translations` row at `p_locale`; returns localized view.
- **Used by:** `createExercise`.

### 6.4 `fn_update_user_exercise`
- **Signature:** `(p_exercise_id UUID, p_name TEXT DEFAULT NULL, p_muscle_group TEXT DEFAULT NULL, p_equipment_type TEXT DEFAULT NULL, p_description TEXT DEFAULT NULL, p_form_tips TEXT DEFAULT NULL) RETURNS TABLE(...)`.
- **Behavior:** verifies `user_id = auth.uid() AND is_default = false`; updates `exercises` for metadata; locates the exercise's **single existing translation row** (user-created rows have exactly one translation by invariant §10) and rewrites its `name/description/form_tips`. The row's `locale` column is preserved — editing does not re-tag content to the UI's current locale. Returns the localized view.
- **Used by:** `updateExercise` (net-new repo method; UI wiring is out of 15f scope — see §14).

### Why not per-screen RPCs (e.g. `fn_workout_history_localized`)
- Scalability: one RPC per screen would fragment the API surface, bloat RLS audit, and force a new RPC for every future feature that shows exercise names.
- Caching: two-query merge lets the exercise batch be cached separately from the primary workout/PR payload.
- Performance cost is acceptable: +20-40ms on hosted Supabase for the second call; <10ms warm.

## 7. Dart refactor (repositories)

### 7.1 `ExerciseRepository` (full rewrite)
| Method | Change |
|---|---|
| `getExercises({locale, muscleGroup, equipmentType})` | Replace `.from('exercises').select()` with `rpc('fn_exercises_localized')`. Locale is now a **required method parameter**. |
| `searchExercises({locale, query, ...})` | Replace `.ilike` with `rpc('fn_search_exercises_localized')`. Offline fallback filters against the locale-keyed cached list (already localized names). |
| `getExerciseById({locale, id})` | Call `rpc('fn_exercises_localized', p_ids: [id])`; pick first. |
| `recentExercises({locale, userId, limit})` | Call `rpc('fn_exercises_localized', p_order: 'created_at_desc')`; trim to `limit` client-side. |
| `createExercise({locale, ...})` | Replace `_exercises.insert(...)` with `rpc('fn_insert_user_exercise')`. Map SQLSTATE 23505 → `ValidationException('duplicate')` as today. |
| **NEW** `updateExercise({id, ...})` | Thin wrapper over `fn_update_user_exercise`. |
| **NEW** `getExercisesByIds({locale, ids})` | Batch fetch returning `Map<String, Exercise>`. Internal cache key `'$locale:batch:${sortedIds.join(',')}'`. Empty `ids` short-circuits. |
| `softDeleteExercise` | Unchanged. CASCADE handles translations. |

### 7.2 `WorkoutRepository`
- Constructor gains `ExerciseRepository` dependency; `workoutRepositoryProvider` updated.
- `getWorkoutHistory`: drop embedded `exercise:exercises(name)` from select → keep only `exercise_id`. After fetch, collect distinct `exercise_id`s → `exerciseRepo.getExercisesByIds(ids, locale)` → rebuild summary via `buildExerciseSummary(workoutExercises, exerciseNamesById)` (signature change).
- `getWorkoutDetail`: same pattern; `parseWorkoutDetail` gains `exercisesById` map param.
- Cache shape: stores raw workouts + `Map<String,String> exerciseNamesById` sidecar. Key gains locale: `'$userId:$locale'`.

### 7.3 `PRRepository`
- Constructor gains `ExerciseRepository` dependency.
- `getRecordsWithExercises` / `getRecentRecordsWithExercises`: drop embedded `exercises(name, equipment_type)` → two-query merge → zip with resolved exercise. Missing exercise falls back to `'Unknown Exercise'` (preserves current behavior for soft-deleted rows).

### 7.4 `RoutineRepository`
- Constructor gains `ExerciseRepository` dependency.
- `_fetchExerciseMap`: replace `.from('exercises').inFilter('id', ids)` with `exerciseRepo.getExercisesByIds(ids, locale)`.
- Cache keys gain locale prefix.

### 7.5 Dead code to remove in this PR
- `lib/core/l10n/exercise_l10n.dart`: delete `_exerciseNames` map, all `_ex*` getters, and `localizedExerciseName()` (grep-confirmed no callers in `lib/`).
- **Keep:** `exerciseSlug()` (tests + slug derivation docs) and `localizedRoutineName()` + `_routineNames` (routines stay ARB-localized — out of 15f scope).
- `lib/l10n/app_en.arb` + `app_pt.arb`: delete all `exerciseName_*` keys (~150 × 2 = 300 keys).
- `flutter gen-l10n` must run clean afterward.

### 7.6 Freezed `Exercise` model
Unchanged. RPC returns the same shape; the model doesn't care whether the fields come from embedded selects or RPC rows.

## 8. Locale plumbing

- **Source of truth:** `localeProvider` (existing, Hive + Supabase-synced).
- **Repository contract:** repos take `locale` as an **explicit method parameter**. They never read `localeProvider` internally.
- **Provider layer:** each provider does `final locale = ref.watch(localeProvider).languageCode;` and passes it to the repo call. This makes provider rebuilds on locale change automatic.
- **Hive cache keys gain locale prefix:**
  - `exerciseCache`: `'en:all'`, `'pt:muscle=chest'`, etc.
  - `routineCache`, `workoutHistoryCache`, `prCache`: `'$userId:$locale'`.
  - `lastSetsCache`, `userPrefs`: unchanged (no exercise text).
- **Locale switch handling:** `LocaleNotifier.setLocale()` clears the four locale-affected Hive boxes after flipping state. Riverpod rebuild naturally refetches under new locale.

## 9. Slug design

- **Format:** snake_case, ASCII `[a-z0-9_]+`. Derivation: `lowercase → replace /[^a-z0-9]+/ with '_' → strip edge underscores`. Matches `exerciseSlug()` in `exercise_l10n.dart:9` byte-for-byte (both Dart and SQL).
- **Uniqueness:** partial unique index `WHERE is_default = true`. User-created rows collide freely (duplicate-name prevention happens in `fn_insert_user_exercise` at the translations level per user).
- **Backfill for 150 defaults:** explicit per-row `UPDATE` in 00030 using a hardcoded map matching `_exerciseNames` keys. Not `regexp_replace` — we need byte-exact parity for the pt seed JOIN in 00033.

## 10. User-created exercise flow (post-15f)

- **Create:** UI → `createExercise(locale, ...)` → `fn_insert_user_exercise` writes one `exercises` row + one `exercise_translations` row at caller locale.
- **Read:** fallback cascade (pt → en → any) means pt user sees the en-created custom exercise in English; en user sees the pt-created custom exercise in Portuguese. Monolingual by design.
- **Update:** `updateExercise` → `fn_update_user_exercise` rewrites the single translation row regardless of current UI locale. Matches mental model: "I typed this in Portuguese; editing updates what I typed."
- **Delete:** unchanged soft-delete on `exercises.deleted_at`. CASCADE handles hard delete during account purge.
- **UI wiring for update:** out of 15f scope. Net-new repo method + RPC ship now (data layer complete); adding an "edit" button to `exercise_detail_screen` is a follow-up polish task.

## 11. E2E test plan (synthesized from qa-engineer assessment)

### 11.1 Breaking changes at boundaries
- **CRITICAL** `test/e2e/global-setup.ts`:
  - `seedPRData()` (~line 151): `.eq('name', 'Barbell Bench Press')` must switch to `.eq('slug', 'barbell_bench_press')`.
  - `seedExerciseProgressData()` (~line 440): same fix.
  - Both lookups currently query `from('exercises')` directly; after 15f the `name` column no longer exists, so these would crash setup. Must be fixed as part of this PR.
- **Selectors:** 12 assertions in `specs/*.spec.ts` compare against hardcoded English exercise names. Introduce `EXERCISE_NAMES` map in `test/e2e/fixtures/test-exercises.ts`: `{ barbell_bench_press: { en: 'Barbell Bench Press', pt: 'Supino Reto com Barra' }, ... }`. Tests read `EXERCISE_NAMES.barbell_bench_press[user.locale]`.

### 11.2 New test users (add to `fixtures/test-users.ts` + `global-setup.ts`)
| User | Locale | Purpose |
|---|---|---|
| `smokeLocalizationWorkout` | pt | Smoke: active-workout screen renders pt names. |
| `fullHistoryPt` | pt | Regression: workout history summary in pt. |
| `smokeLocalizationRoutines` | pt | Smoke: routine create/edit with pt exercise picker. |
| `fullPRPt` | pt | Regression: PR list + detail in pt. |

### 11.3 New test scenarios

| ID | Surface | Scenario | Tag |
|---|---|---|---|
| A1 | Exercise list | pt user sees list alphabetized in pt; spot-check 3 names | `@smoke` |
| A2 | Exercise detail | pt user opens detail → pt name/description/form_tips | `@smoke` |
| A3 | Exercise list | en user sees list in en | — |
| A4 | Exercise detail | en user sees en detail | `@smoke` |
| A5 | Muscle/equipment filters | pt user filters chest → pt chest exercises only | — |
| B1 | Search | pt user searches "supino" → finds pt-named bench press | — |
| B2 | Cross-locale search | pt user searches "bench" → finds via en-name fallback | — |
| C1 | Active workout | pt user starts workout from pt-picker → pt names in workout screen | `@smoke` |
| C2 | Active workout | Locale switch during workout → fetched exercises reflect new locale on refresh | — |
| D1 | History | pt user sees workout summary in pt (comma-separated pt names) | — |
| E1 | Routines | pt user creates routine with pt-picker → pt names in routine list | — |
| F1 | PRs | pt user sees PR list with pt exercise names | — |
| G1 | User-created | pt user creates "Meu Exercício" → visible with pt name on list; en user doesn't see it (RLS) | — |
| G2 | User-created | Accented chars round-trip correctly (name + description) | — |

### 11.4 Coverage thresholds
- Smoke suite (`@smoke`) adds ~4 tests — runs on every PR.
- Full regression covers all 14 scenarios; must stay 145+ green.
- Existing `localization.spec.ts` stays (tests settings-screen language toggle); new scenarios are feature-specific.

## 12. Unit + widget test strategy (synthesized from tech-lead)

### 12.1 Existing tests requiring rework
- `workout_repository_test.dart`, `workout_repository_cache_test.dart`: mock shapes change (no embedded exercise), signature of `buildExerciseSummary` changes, cache includes locale key + sidecar map.
- `pr_repository_test.dart`, `pr_repository_cache_test.dart`: same pattern.
- `routine_repository_test.dart`, `routine_repository_cache_test.dart`: mock `ExerciseRepository.getExercisesByIds` instead of `from('exercises')`; locale-keyed cache.
- `exercise_repository_test.dart`, `exercise_repository_cache_test.dart`: replace builder-chain fake (`select().eq().ilike().order()`) with RPC fake.
- `exercise_list_provider_test.dart`, `exercise_by_id_provider_test.dart`: `localeProvider` overrides.
- `exercise_l10n_test.dart`: delete `localizedExerciseName` group; keep `exerciseSlug` + routine groups.

### 12.2 New unit tests
1. `ExerciseRepository` × RPC fake: each method invokes the right RPC with the right params (including locale); SQLSTATE 23505 mapping; `getExercisesByIds([])` short-circuits.
2. Locale cache-key collision: `'en:all'` vs `'pt:all'` don't overwrite; locale switch clears all four boxes.
3. `WorkoutRepository` two-query merge: `getExercisesByIds` called once with distinct IDs regardless of workout count (N+1 protection); missing exercise is skipped/fallback.
4. `PRRepository` two-query merge: primary PR query → batch exercise fetch; `'Unknown Exercise'` fallback preserved.
5. `RoutineRepository._fetchExerciseMap`: locale plumbed through all three write paths (create/update/get).

### 12.3 New widget tests
- `exercise_list_screen_test.dart` with `localeProvider` override: pt names render.
- `exercise_detail_screen_test.dart`: description + form_tips populate from resolved Exercise regardless of locale.
- `create_exercise_screen_test.dart`: on submit, repo called with `locale: 'pt'` when user locale is pt.

### 12.4 New shared test infrastructure
- `test/fixtures/rpc_fakes.dart`: reusable `FakeRpcClient` modeled on `xp_repository_test.dart:35-70`. Exposes a per-RPC handler registration API. Becomes project-standard RPC fake.
- `test/fixtures/test_factories.dart`: `TestExerciseFactory.create` gains `slug` field default `'bench_press'`.

## 13. CI gates

- **Replace** `scripts/check_exercise_content_pairing.sh` → `scripts/check_exercise_translation_coverage.sh`.
- **New invariant:** every INSERT into `exercises (is_default = true)` in a PR must be paired with INSERTs into `exercise_translations` for BOTH `'en'` AND `'pt'` for the same slug.
- **Script fixtures:** `scripts/fixtures/fixture_pt_missing.sql` (fail case) + `fixture_complete.sql` (pass case) — script is self-testing.
- **Existing gates unchanged:** `make format`, `make analyze`, `make test`, `make build-android-debug`, Playwright E2E 145/145.
- **Optional healthcheck script** (`scripts/verify_prod_translation_invariants.sh`): psql queries for the four invariants in §14 acceptance criteria. Ships in this PR as a manual tool; not wired into GH Actions.

## 14. Acceptance criteria

All must hold before merge:

1. **Schema invariants** against hosted Supabase after migrations apply:
   - Every `exercises` row has an `'en'` translation (count match).
   - Every default exercise has a `'pt'` translation (count match).
   - Zero rows with `slug IS NULL OR slug = ''`.
   - `information_schema.columns` shows no `name/description/form_tips` on `exercises`.
2. **Dart:** `make ci` green.
3. **E2E:** all 145 Playwright tests pass locally (existing + new A1-G2).
4. **Manual locale smoke:**
   - EN user: list, detail, workout history, PR list, routine edit — all English.
   - PT user: all surfaces in Portuguese.
   - Locale switch EN → pt: surfaces repopulate in pt within one refresh.
   - RLS: en user can't see a pt user's custom exercise.
5. **Performance:** exercise list first paint <300ms p50; workout history first paint <600ms p50 (two-query merge acceptable).
6. **Staging verification:** six-step procedure (§15) executed; outputs pasted in PR body.
7. **Rollback script:** dry-run succeeded against staging.
8. **Translation QA:** pt-BR reviewer (human) skimmed all 150 rows on staging. Sign-off in PR body.
9. **Reviewer + QA agent gates passed** per CLAUDE.md pipeline.

## 15. Staging verification procedure (mandatory pre-merge)

1. Link CLI to staging: `npx supabase link --project-ref <staging>`.
2. `npx supabase db push` — apply 00030-00034 against staging.
3. Run the four invariant queries (§14.1); record outputs in PR description.
4. Build web from branch, deploy to preview bucket. Smoke-test with staging users in both locales.
5. Run full E2E suite against staging; record pass count + any failures in PR description.
6. pt-BR reviewer spot-checks ~10 random exercises on staging detail screens. Sign-off required.

Only after all six green: squash-merge to main + apply migrations to prod per CLAUDE.md step 10.

## 16. Rollback strategy

Single-PR ship → single rollback procedure.

- **Trigger:** bug surfaces within 24h post-merge window.
- **Forward data integrity:** every piece of English content recoverable from `exercise_translations WHERE locale='en'`. Zero EN loss on rollback. Only pt translations lost (regenerable from 00033).
- **Edge case:** user-created row written in pt-only during the live window. Rollback script uses `COALESCE` to pull any available translation into the re-added `name` column.
- **Script:** `scripts/emergency_rollback_15f.sql`, committed alongside forward migrations. Contents (each content column restored via the same COALESCE pattern — `'en'` first, then any available translation):
  ```sql
  ALTER TABLE exercises
    ADD COLUMN name TEXT,
    ADD COLUMN description TEXT,
    ADD COLUMN form_tips TEXT;

  UPDATE exercises e SET
    name = COALESCE(
      (SELECT t.name FROM exercise_translations t WHERE t.exercise_id = e.id AND t.locale = 'en'),
      (SELECT t.name FROM exercise_translations t WHERE t.exercise_id = e.id LIMIT 1)
    ),
    description = COALESCE(
      (SELECT t.description FROM exercise_translations t WHERE t.exercise_id = e.id AND t.locale = 'en'),
      (SELECT t.description FROM exercise_translations t WHERE t.exercise_id = e.id LIMIT 1)
    ),
    form_tips = COALESCE(
      (SELECT t.form_tips FROM exercise_translations t WHERE t.exercise_id = e.id AND t.locale = 'en'),
      (SELECT t.form_tips FROM exercise_translations t WHERE t.exercise_id = e.id LIMIT 1)
    );

  ALTER TABLE exercises ALTER COLUMN name SET NOT NULL;
  DROP FUNCTION fn_exercises_localized, fn_search_exercises_localized, fn_insert_user_exercise, fn_update_user_exercise;
  DROP TABLE exercise_translations CASCADE;
  DROP INDEX exercises_slug_unique_default, exercises_slug_idx;
  ALTER TABLE exercises DROP COLUMN slug;
  ```
- **Procedure:** apply reverse SQL to prod → `git revert <merge-sha>` → merge revert PR.
- **Downtime estimate:** 0-30 seconds per user session during the reverse-migration / revert-deploy window.
- **Must be dry-run against staging during §15 step 3.**

## 17. Risk register (top 5)

| Risk | Likelihood | Severity | Mitigation |
|---|---|---|---|
| Two-query merge adds perceived latency to history/PR screens | Med | Med | Profile on hosted Supabase during PR review; +20-40ms expected; revisit only if p95 > 1s. |
| N+1 regression from refactor | Low | High | Batch via `getExercisesByIds`; explicit unit test "exactly one batch call per invocation." |
| pt seed quality (AI-drafted phrasing errors) | Med | Med | Hybrid glossary-first workflow + mandatory 150-row human skim before merge. |
| Single-PR blast radius on regression | Med | High | Conscious tradeoff vs phased rollout. Mitigated by staging verification + rollback dry-run + 24h on-call window. |
| RLS misconfiguration exposing other users' customs | Low | High | Explicit policies § 5; E2E G1 test; psql `EXPLAIN` audit in staging. |

Full risk register (15 items) inventoried during tech-lead planning; above are the five highest-impact. Remaining 10 covered by existing mitigations (locale-keyed caches, explicit ordering, ARB cleanup sanity check, batch size cap, etc.).

## 18. Out of scope for 15f

- Routine content localization (routines stay ARB-mapped via `localizedRoutineName`).
- UI exposure of `fn_update_user_exercise` (repo method + RPC ship now; edit button in `exercise_detail_screen` is a follow-up polish task).
- Adding a third or fourth locale (es-ES, fr-FR). Schema and RPCs support it; data migration is a future phase.
- Multi-locale for user-created exercises (schema allows; product requirement deferred).
- Automated translation invariant healthcheck as a GH Action (script ships as manual tool).

## 19. Relevant files

**Modified / rewritten (lib):**
- `lib/features/exercises/data/exercise_repository.dart`
- `lib/features/exercises/providers/exercise_providers.dart`
- `lib/features/workouts/data/workout_repository.dart`
- `lib/features/personal_records/data/pr_repository.dart`
- `lib/features/routines/data/routine_repository.dart`
- `lib/core/l10n/exercise_l10n.dart` (trim dead code)
- `lib/core/l10n/locale_provider.dart` (cache-clear on switch)
- `lib/core/local_storage/cache_service.dart`, `hive_service.dart` (locale-keyed boxes)
- `lib/l10n/app_en.arb`, `app_pt.arb` (delete `exerciseName_*` keys)

**New (sql):**
- `supabase/migrations/00030_add_exercise_slug.sql`
- `supabase/migrations/00031_create_exercise_translations.sql`
- `supabase/migrations/00032_backfill_exercise_translations_en.sql`
- `supabase/migrations/00033_seed_exercise_translations_pt.sql`
- `supabase/migrations/00034_drop_exercise_name_columns_and_add_rpcs.sql`
- `scripts/emergency_rollback_15f.sql`

**New/modified (tests):**
- `test/fixtures/rpc_fakes.dart` (new)
- `test/fixtures/test_factories.dart` (slug field)
- `test/e2e/fixtures/test-exercises.ts` (new `EXERCISE_NAMES` map)
- `test/e2e/fixtures/test-users.ts` (+4 users)
- `test/e2e/global-setup.ts` (slug-based lookups + 4 user seed)
- `test/e2e/specs/exercises.spec.ts`, `workouts.spec.ts`, `routines.spec.ts`, `history.spec.ts`, `prs.spec.ts`, `localization.spec.ts` (scenarios A1-G2)
- All affected unit test files (§12.1)

**New/modified (scripts):**
- `scripts/check_exercise_translation_coverage.sh` (replaces pairing check)
- `scripts/verify_prod_translation_invariants.sh` (new manual healthcheck)
- `scripts/fixtures/fixture_pt_missing.sql`, `fixture_complete.sql` (script self-tests)

**Docs:**
- `PLAN.md` (add Phase 15f section; condense after merge)
- `CLAUDE.md` (update the "Exercise content pairing rule" section to reference the new coverage check)
