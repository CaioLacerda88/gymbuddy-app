-- Phase 15f Stage 1 — add locale-independent semantic slug to `exercises`.
--
-- The slug is the stable identifier used to JOIN exercises ↔ locale-specific
-- translations (see 00031) without coupling either side to display text.
-- Defaults share a slug namespace (globally unique); user-created exercises
-- may collide slugs with each other or with defaults — hence the partial
-- unique index.
--
-- The backfill expression below MUST match `exerciseSlug()` in
-- `lib/core/l10n/exercise_l10n.dart` byte-for-byte:
--
--   englishName.toLowerCase()
--     .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
--     .replaceAll(RegExp(r'^_+|_+$'), '')
--
-- Postgres equivalent:
--
--   trim(both '_' from regexp_replace(lower(name), '[^a-z0-9]+', '_', 'g'))
--
-- Test anchors:
--   'Barbell Bench Press'   → 'barbell_bench_press'
--   "Farmer's Walk"         → 'farmer_s_walk'
--   'Push-Up'               → 'push_up'
--   'T-Bar Row'             → 't_bar_row'

BEGIN;

-- 1. Add column nullable so the backfill can run.
ALTER TABLE exercises
  ADD COLUMN slug TEXT;

-- 2. Backfill every row (defaults AND user-created) from current `name`.
--    This mirrors Dart `exerciseSlug()` exactly. Applied to all rows because
--    user-created exercises will also need a slug once 00034 drops the `name`
--    column and read RPCs start joining on slug/id.
UPDATE exercises
SET slug = trim(both '_' from regexp_replace(lower(name), '[^a-z0-9]+', '_', 'g'));

-- 3. Hard assert no NULL/empty slugs survived — fail loudly if the regex ever
--    produces an empty string (e.g. all-punctuation name). Matches the
--    architecture's invariant that every exercise has a slug.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM exercises WHERE slug IS NULL OR slug = '') THEN
    RAISE EXCEPTION 'slug backfill incomplete: found NULL or empty slug';
  END IF;
END
$$;

-- 4. Lock the invariant at the schema level.
ALTER TABLE exercises
  ALTER COLUMN slug SET NOT NULL;

-- 5. Default slugs must be globally unique — they're the join key for
--    translation seeds (00032/00033) and future locale additions.
--    User-created rows are intentionally excluded: two users may each create
--    "My Pushup" and both get slug `my_pushup` without colliding.
CREATE UNIQUE INDEX exercises_slug_unique_default
  ON exercises (slug)
  WHERE is_default = true;

-- 6. General lookup index for the hot path: RPCs resolving an exercise by
--    slug across defaults + user rows.
CREATE INDEX exercises_slug_idx
  ON exercises (slug);

-- 7. Structural guarantee: derive slug from name on INSERT when the caller
--    doesn't supply one. Mirrors Dart `exerciseSlug()` byte-for-byte, so a
--    Dart insert that only sets `name` still produces the identical slug the
--    application would compute client-side.
--
--    Why a trigger: Stage 1 introduces the `slug NOT NULL` invariant while
--    the rest of the system (Dart `ExerciseRepository.create`, `seed.sql`,
--    E2E fixtures) still inserts rows without a slug. Until Stage 4's RPCs
--    become the only insert path (Stage 6 client refactor), this trigger
--    bridges the gap without forcing every caller to know about slugs.
--    The NOT NULL check still fires if `name` is NULL or slug-derivable-to-
--    empty (all-punctuation), preserving the invariant.
--
--    INSERT-only: rename handling on UPDATE is deferred to the Stage 4
--    RPC contract, which will set slug explicitly. Auto-recomputing on
--    UPDATE is error-prone because `NEW.slug` inherits the old value when
--    not in the SET list, so a simple "NULL/empty" guard wouldn't catch a
--    stale-slug scenario after a rename. Explicit is safer.
--
--    Idempotent: explicit slugs are respected (e.g. tests, Stage 4 RPCs).
--    NULL or empty slug → derived.
CREATE OR REPLACE FUNCTION public.exercises_derive_slug()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.slug IS NULL OR NEW.slug = '' THEN
    NEW.slug := trim(both '_' from regexp_replace(lower(NEW.name), '[^a-z0-9]+', '_', 'g'));
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER exercises_derive_slug_trigger
  BEFORE INSERT ON exercises
  FOR EACH ROW
  EXECUTE FUNCTION public.exercises_derive_slug();

COMMIT;
