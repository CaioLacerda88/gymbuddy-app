# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## P4 — Exercise images fix (Phase 13 Sprint B, slot 1)

**Branch:** `feature/phase13-sprintb-p4-images` (branched from `main` at `5662755`)
**Source spec:** `PLAN.md` → `## Phase 13: Launch` → `### Remaining — Sprint B: Retention` → row `P4` (lines ~571)
**Effort estimate:** 3-4h
**Status:** Planned, not yet started. Branch created, investigation done (findings below), implementation pending.

### Root cause (verified live 2026-04-13)

- All seeded exercise image URLs return genuine HTTP 404s (not CORS, not rate-limit, not TLS).
- Source repo `yuhonas/free-exercise-db` is healthy (`github.com/yuhonas/free-exercise-db` + `api.github.com/repos/yuhonas/free-exercise-db` both 200).
- **Name mismatch**: migration `supabase/migrations/00004_seed_exercise_images.sql` seeded abbreviated folder names like `Barbell_Bench_Press/0.jpg`, but the repo actually uses descriptive folder names from its exercise catalog like `Barbell_Bench_Press_-_Medium_Grip/0.jpg`. The descriptive path returns 200. Every seeded URL is a name-guess that never matched the source — images were never working, regardless of GitHub reliability.

### Decision: Supabase Storage rehost

- Matches `PLAN.md` spec ("Migrate to Supabase Storage or CDN").
- Bucket `exercise-media` **already provisioned** in migration `supabase/migrations/00003_exercise_images.sql` with public read + service-role write + 2 MB cap + `image/jpeg`, `image/png`, `image/webp` MIME types. No Supabase infra work needed.
- Removes external dependency on a third-party repo that could rename paths again.

### Scope

| | In scope | Out of scope |
|---|---|---|
| Exercises | ~57 default exercises with broken URLs (seeded by migration 00004) | ~35 exercises from migration 00014 with NULL URLs — belongs to P9 (content + images ship together) |
| UI | — | Image-loading stack works (`cached_network_image` + muscle-group icon fallback); only data is broken |
| Assets | Static JPGs (start + end frames) | Animated GIFs, videos, UI redesign |

### Checklist

- [x] **Step 1 — Build name → folder map.** Fetch `dist/exercises.json` from `yuhonas/free-exercise-db`. Build `{exercise name from migration 00004 → correct folder name in repo}` map. Manually curate any unmatched names. Commit mapping as `tools/exercise_image_mapping.json` (or similar) for audit trail.
- [x] **Step 2 — Download source images.** For each of the ~57 exercises, fetch `{correct_folder}/0.jpg` and `{correct_folder}/1.jpg` from `raw.githubusercontent.com` into a local staging dir. Validate each file is a non-empty JPEG.
- [x] **Step 3 — Upload to Supabase Storage.** One-off Dart script `tools/fix_exercise_images.dart` uses `SUPABASE_SERVICE_ROLE_KEY` (read from env, never committed) to push files into `exercise-media/` bucket. Filename convention: `{sanitized_exercise_name}_start.jpg` and `{sanitized_exercise_name}_end.jpg`. Sanitize: lowercase, spaces → underscores, strip non-alphanumeric. Collision check: error out if any target filename already exists. [LOCAL done, hosted in Step 6.]
- [x] **Step 4 — Write migration.** `supabase/migrations/00018_fix_exercise_images.sql`: `UPDATE exercises SET image_start_url = 'https://{project}.supabase.co/storage/v1/object/public/exercise-media/{slug}_start.jpg', image_end_url = '...' WHERE name = '{name}' AND is_default = true;` for each of the ~57 exercises. Use the project's hosted Supabase URL (read from `reference_supabase_project.md` memory file, or `.env`).
- [x] **Step 5 — Verify locally.** Run `npx supabase db reset` (applies all migrations including 00018 on local Supabase); run `flutter run -d chrome`; navigate Exercise List → detail for 3-5 seeded exercises → confirm images render. Check browser devtools Network tab — zero 404s on `exercise-media` requests. [db reset OK, 5/5 curl-sampled local URLs return 200, exit criteria query returns 0 non-supabase rows. Flutter smoke-run deferred to qa-engineer Step 7.]
- [x] **Step 6 — Apply migration to hosted.** `npx supabase db push --linked`. Verify in production via curl sampling 5-10 new URLs → all 200. [Hosted bucket populated with all 118 files, migration 00018 applied, 10/10 sampled URLs return 200, 59 rows in hosted `exercises` point at `supabase.co`, 0 violations of the exit-criteria query.]
- [x] **Step 7 — Add E2E regression test.** New test in existing `test/e2e/specs/exercises.spec.ts` under the `Exercise library` regression block (no `@smoke`): navigate to Barbell Bench Press detail, assert both semantic role=img nodes visible, intercept network responses with `page.waitForResponse` to assert both start/end image URLs return HTTP 200. Added `startImage`/`endImage` selector factories to `EXERCISE_DETAIL` in `helpers/selectors.ts`.
- [x] **Step 8 — Run verification gate.** Format clean (0 changes), analyze clean (no issues), flutter test 994 passed/0 failed, android-debug-build green. P4 regression test passes in isolated run (12.8s) and clean full-suite run (test #74, 12.8s). First full E2E run: 144 passing + 1 P4 failure (fixed) + 1 pre-existing EX-003 flake. BUG-001 Workout Restore flake appeared in post-build run due to system resource exhaustion, not a regression introduced by this change.
- [ ] **Step 9 — Open PR, reviewer + qa-engineer pass, merge.**

### Files to create

- `tools/fix_exercise_images.dart` — one-off upload script. Kept in repo for documentation + future re-run.
- `tools/exercise_image_mapping.json` (or `.csv`) — audit trail of name → folder → new URL mapping.
- `supabase/migrations/00018_fix_exercise_images.sql` — row-by-row URL update.
- Test case added to `test/e2e/specs/exercises.spec.ts` (not a new file).

### Files NOT to modify

- `lib/features/exercises/ui/exercise_detail_screen.dart` — image widget works correctly.
- `lib/features/workouts/ui/active_workout_screen.dart` — same widget, works correctly.
- `cached_network_image` handling — fallback logic is fine.
- Any existing migration — migrations are immutable once applied.

### Gotchas

- **`image_start` vs `image_end` are semantically distinct** — start-of-movement and end-of-movement frames displayed side-by-side. Cannot be collapsed to one image.
- **Per-exercise folder slugs** — no shared CDN prefix to find-replace. Each of the ~57 exercises has its own folder name in the source repo.
- **Service role key** — never commit. Script reads from `SUPABASE_SERVICE_ROLE_KEY` env var. Document in a script-level header comment how to obtain it (Supabase dashboard → Settings → API).
- **Idempotency** — the upload script should handle partial re-runs (skip files that already exist in bucket). The SQL migration is naturally idempotent (UPDATE with WHERE name=...).
- **Name collisions** — `sanitize("Row")` and `sanitize("row")` both collapse to `row`. Check for collisions before uploading.
- **Local vs hosted Supabase** — both need the bucket populated. Script must be runnable against either by swapping the `SUPABASE_URL` env var.

### Exit criteria (subset of Phase 13 exit criteria #2)

- `SELECT COUNT(*) FROM exercises WHERE is_default = true AND image_start_url IS NOT NULL AND image_start_url NOT LIKE '%supabase.co%'` returns `0` on hosted.
- Zero image 404s in browser devtools across Exercise List → Detail → Active Workout exercise sheet (QA walkthrough).
- New E2E regression test green. Existing 145 E2E tests still green.
- `make ci` green.

### Key references

- `supabase/migrations/00003_exercise_images.sql` — defines columns + bucket + policies
- `supabase/migrations/00004_seed_exercise_images.sql` — the migration with broken URLs
- `supabase/migrations/00007_seed_default_exercises.sql` — defines the ~60 exercises targeted
- `supabase/migrations/00014_expand_exercises_and_routines.sql` — adds ~32 exercises with NULL URLs (P9's scope, NOT P4)
- `lib/features/exercises/ui/exercise_detail_screen.dart:166-315` — `_ExerciseImageRow` / `_TappableImage` / `ExerciseImage`
- `lib/features/workouts/ui/active_workout_screen.dart:1043-1088` — second render site
- `~/.claude/projects/C--Users-caiol-Projects-gymbuddy-app/memory/reference_supabase_project.md` — hosted project ref
- `dist/exercises.json` at `github.com/yuhonas/free-exercise-db` — canonical exercise catalog with correct folder names

### Development flow per CLAUDE.md

1. (This WIP doc serves as Step 2 — checklist written before code.)
2. Dispatch `tech-lead` (Opus) for implementation. Agent should: read this WIP + key references, execute checklist Steps 1-6, check off each item.
3. Dispatch `qa-engineer` (Sonnet) for Step 7 (E2E regression test) + Step 8 (verification gate).
4. Orchestrator runs `make ci` fresh before PR.
5. Open PR, reviewer pass, squash-merge, apply migration to hosted if not already done in Step 6, remove this WIP section.

---

*Last merged: PR #52 (docs: Phase 13 restructured as 'Launch' — consolidated pre-launch spec).*
