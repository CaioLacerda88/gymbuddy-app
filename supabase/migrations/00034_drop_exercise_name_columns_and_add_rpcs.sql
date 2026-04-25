-- Phase 15f Stage 4 — RPC layer + drop legacy name columns.
--
-- This is the cut-over migration of Phase 15f. It moves the system from a
-- monolingual `exercises.{name, description, form_tips}` model to a
-- locale-aware model where those three fields live exclusively in
-- `exercise_translations` (created in 00031, populated for `'en'` by 00032
-- and `'pt'` by 00033).
--
-- Order of operations matters (see README in PR for rationale):
--
--   A. Install pg_trgm + trigram GIN index on translations.name (search hot
--      path used by fn_search_exercises_localized).
--   B. Create the four read/write RPCs (§6.1-§6.4 of the design spec) that
--      become the only access path to localized exercise content. Each is
--      `SECURITY INVOKER` so RLS policies on `exercise_translations` (§5)
--      and `exercises` continue to apply.
--   C. Rewrite the slug-derivation trigger so it does not reference the
--      `name` column we are about to drop. Post-Stage-4 the only writer
--      against `exercises` is fn_insert_user_exercise (Stage 6 client
--      refactor); it always supplies an explicit slug. The trigger becomes a
--      strict guard: a NULL/empty slug at INSERT time is now a structural
--      bug, not something to paper over.
--   D. Drop the artifacts that referenced the columns being removed:
--      - `idx_exercises_unique_name` (functional index on lower(name))
--      - the three `valid_exercises_*_length` CHECK constraints from 00021
--      Then DROP the columns themselves.
--   E. Hard sanity checks: assert the four functions exist, the columns are
--      gone, and pg_trgm is installed. Migration aborts loudly on any
--      violation rather than leaving the schema in an ambiguous state.
--
-- Idempotency: extension and indexes use IF NOT EXISTS / OR REPLACE, so the
-- forward migration is safe to retry on a fresh database. Column DROPs and
-- constraint DROPs use IF EXISTS to survive partial-apply scenarios. The
-- final asserts are the structural backstop.
--
-- Rollback: scripts/emergency_rollback_15f.sql re-adds the dropped columns,
-- COALESCE-backfills from `exercise_translations` (en first, then any
-- available locale), drops the four functions and the translations table.
-- See spec §16 — round-trip dry-run is a release-gate item.

BEGIN;

-- =============================================================================
-- STEP A — pg_trgm extension + trigram GIN index for localized name search
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Trigram index on the translation name column — supports
-- `name % p_query` (similarity-based lookup) and `similarity()` ORDER BY in
-- fn_search_exercises_localized. Plain B-tree wouldn't help for substring or
-- fuzzy match.
CREATE INDEX IF NOT EXISTS exercise_translations_name_trgm_idx
  ON exercise_translations USING gin (name gin_trgm_ops);


-- =============================================================================
-- STEP B — the four localized RPCs
-- =============================================================================
--
-- Shared shape: every function returns the full `exercises` row (post-drop)
-- with `slug` plus three resolved text columns (`name`, `description`,
-- `form_tips`). Resolution cascade per spec §6: prefer the requested locale,
-- fall back to `'en'` (guaranteed-present for every row by 00032), then any
-- available translation. The third tier matters only when a row has a
-- partial set of locales (future expansion); within the 15f universe every
-- row has at least `'en'` so the third tier is dead branch — kept for
-- correctness against future locale additions.
--
-- Column order in RETURNS TABLE matches the Dart `Exercise` Freezed model
-- (`lib/features/exercises/models/exercise.dart`) using snake_case JSON
-- field names. Repository methods deserialize via `Exercise.fromJson` which
-- ignores extra keys, so adding `slug` at the end is forward-compatible.

-- -----------------------------------------------------------------------------
-- 6.1 fn_exercises_localized
-- -----------------------------------------------------------------------------
-- List/lookup RPC. Three modes:
--
--   * Default (p_ids NULL): list visible exercises with optional muscle/equipment
--     filters, ordered per p_order.
--   * Batch (p_ids non-empty): treat p_ids as a fixed set; ignore filters and
--     order. Used by getExerciseById, getExercisesByIds, two-query merge in
--     workouts/PRs/routines.
--
-- Visibility predicate is fixed: `is_default = true OR user_id = p_user_id`,
-- combined with `deleted_at IS NULL`. p_user_id is required (caller's UUID,
-- typically auth.uid()). RLS on `exercises` re-enforces the same rule, so
-- this is defense-in-depth for direct callers.
--
-- p_order: only 'name' and 'created_at_desc' are accepted. Anything else
-- raises SQLSTATE 22023 (invalid_parameter_value) so a typo at the caller
-- becomes a hard error, not a silent default.
--
-- p_ids cap (500) protects the planner: above ~500 IDs the RPC becomes a
-- materialization hazard and the caller should chunk client-side.
CREATE OR REPLACE FUNCTION public.fn_exercises_localized(
  p_locale         TEXT,
  p_user_id        UUID,
  p_muscle_group   TEXT  DEFAULT NULL,
  p_equipment_type TEXT  DEFAULT NULL,
  p_ids            UUID[] DEFAULT NULL,
  p_order          TEXT  DEFAULT 'name'
)
RETURNS TABLE (
  id              UUID,
  name            TEXT,
  muscle_group    muscle_group,
  equipment_type  equipment_type,
  is_default      BOOLEAN,
  description     TEXT,
  form_tips       TEXT,
  image_start_url TEXT,
  image_end_url   TEXT,
  user_id         UUID,
  deleted_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ,
  slug            TEXT
)
LANGUAGE plpgsql
SECURITY INVOKER
STABLE
AS $$
BEGIN
  -- Validate p_order up front so the SELECT body can branch safely.
  IF p_order IS NULL OR p_order NOT IN ('name', 'created_at_desc') THEN
    RAISE EXCEPTION 'invalid p_order: %, expected one of (name, created_at_desc)', p_order
      USING ERRCODE = '22023';
  END IF;

  -- Hard cap on batch size. array_length is NULL for empty arrays so we
  -- guard with COALESCE.
  IF p_ids IS NOT NULL AND COALESCE(array_length(p_ids, 1), 0) > 500 THEN
    RAISE EXCEPTION 'p_ids too large: %, max 500', array_length(p_ids, 1)
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT
    e.id,
    COALESCE(
      (SELECT t.name FROM exercise_translations t
       WHERE t.exercise_id = e.id AND t.locale = p_locale),
      (SELECT t.name FROM exercise_translations t
       WHERE t.exercise_id = e.id AND t.locale = 'en'),
      (SELECT t.name FROM exercise_translations t
       WHERE t.exercise_id = e.id LIMIT 1)
    ) AS name,
    e.muscle_group,
    e.equipment_type,
    e.is_default,
    COALESCE(
      (SELECT t.description FROM exercise_translations t
       WHERE t.exercise_id = e.id AND t.locale = p_locale),
      (SELECT t.description FROM exercise_translations t
       WHERE t.exercise_id = e.id AND t.locale = 'en'),
      (SELECT t.description FROM exercise_translations t
       WHERE t.exercise_id = e.id LIMIT 1)
    ) AS description,
    COALESCE(
      (SELECT t.form_tips FROM exercise_translations t
       WHERE t.exercise_id = e.id AND t.locale = p_locale),
      (SELECT t.form_tips FROM exercise_translations t
       WHERE t.exercise_id = e.id AND t.locale = 'en'),
      (SELECT t.form_tips FROM exercise_translations t
       WHERE t.exercise_id = e.id LIMIT 1)
    ) AS form_tips,
    e.image_start_url,
    e.image_end_url,
    e.user_id,
    e.deleted_at,
    e.created_at,
    e.slug
  FROM exercises e
  WHERE e.deleted_at IS NULL
    AND (e.is_default = true OR e.user_id = p_user_id)
    AND (
      -- Batch mode: filter by id set only, ignore muscle/equipment.
      (p_ids IS NOT NULL AND COALESCE(array_length(p_ids, 1), 0) > 0
        AND e.id = ANY(p_ids))
      OR
      -- Non-batch mode: optional muscle/equipment filters.
      (
        (p_ids IS NULL OR COALESCE(array_length(p_ids, 1), 0) = 0)
        AND (p_muscle_group IS NULL
             OR e.muscle_group::text = p_muscle_group)
        AND (p_equipment_type IS NULL
             OR e.equipment_type::text = p_equipment_type)
      )
    )
  -- Order: only applied in non-batch mode. In batch mode the caller is
  -- typically rebuilding a Map<id, Exercise> and order is irrelevant.
  ORDER BY
    CASE WHEN p_order = 'name'
              AND (p_ids IS NULL OR COALESCE(array_length(p_ids, 1), 0) = 0)
         THEN COALESCE(
           (SELECT t.name FROM exercise_translations t
            WHERE t.exercise_id = e.id AND t.locale = p_locale),
           (SELECT t.name FROM exercise_translations t
            WHERE t.exercise_id = e.id AND t.locale = 'en'),
           (SELECT t.name FROM exercise_translations t
            WHERE t.exercise_id = e.id LIMIT 1)
         )
    END ASC,
    CASE WHEN p_order = 'created_at_desc'
              AND (p_ids IS NULL OR COALESCE(array_length(p_ids, 1), 0) = 0)
         THEN e.created_at
    END DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_exercises_localized(
  TEXT, UUID, TEXT, TEXT, UUID[], TEXT
) TO authenticated;


-- -----------------------------------------------------------------------------
-- 6.2 fn_search_exercises_localized
-- -----------------------------------------------------------------------------
-- Trigram-similarity search over `exercise_translations.name`. Matches in the
-- caller's locale OR `'en'` for cross-locale discoverability ("a pt user can
-- search 'bench' and still find supino"). Returns one row per `exercises.id`
-- (collapses duplicate matches across locales) keeping the highest-similarity
-- score for ranking.
--
-- The returned name/description/form_tips use the standard cascade — the
-- locale that produced the match is irrelevant for display; the user always
-- sees the best available translation in their UI locale.
CREATE OR REPLACE FUNCTION public.fn_search_exercises_localized(
  p_query          TEXT,
  p_locale         TEXT,
  p_user_id        UUID,
  p_muscle_group   TEXT DEFAULT NULL,
  p_equipment_type TEXT DEFAULT NULL
)
RETURNS TABLE (
  id              UUID,
  name            TEXT,
  muscle_group    muscle_group,
  equipment_type  equipment_type,
  is_default      BOOLEAN,
  description     TEXT,
  form_tips       TEXT,
  image_start_url TEXT,
  image_end_url   TEXT,
  user_id         UUID,
  deleted_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ,
  slug            TEXT
)
LANGUAGE plpgsql
SECURITY INVOKER
STABLE
AS $$
BEGIN
  RETURN QUERY
  WITH matches AS (
    -- One row per exercise — collapse cross-locale duplicates by keeping the
    -- best similarity score across locales. DISTINCT ON requires ORDER BY
    -- prefix matching the DISTINCT key.
    SELECT DISTINCT ON (e.id)
      e.id,
      e.muscle_group,
      e.equipment_type,
      e.is_default,
      e.image_start_url,
      e.image_end_url,
      e.user_id,
      e.deleted_at,
      e.created_at,
      e.slug,
      similarity(t.name, p_query) AS score
    FROM exercises e
    JOIN exercise_translations t ON t.exercise_id = e.id
    WHERE e.deleted_at IS NULL
      AND (e.is_default = true OR e.user_id = p_user_id)
      AND t.locale IN (p_locale, 'en')
      AND t.name % p_query
      AND (p_muscle_group IS NULL
           OR e.muscle_group::text = p_muscle_group)
      AND (p_equipment_type IS NULL
           OR e.equipment_type::text = p_equipment_type)
    ORDER BY e.id, similarity(t.name, p_query) DESC
  )
  SELECT
    m.id,
    COALESCE(
      (SELECT t.name FROM exercise_translations t
       WHERE t.exercise_id = m.id AND t.locale = p_locale),
      (SELECT t.name FROM exercise_translations t
       WHERE t.exercise_id = m.id AND t.locale = 'en'),
      (SELECT t.name FROM exercise_translations t
       WHERE t.exercise_id = m.id LIMIT 1)
    ) AS name,
    m.muscle_group,
    m.equipment_type,
    m.is_default,
    COALESCE(
      (SELECT t.description FROM exercise_translations t
       WHERE t.exercise_id = m.id AND t.locale = p_locale),
      (SELECT t.description FROM exercise_translations t
       WHERE t.exercise_id = m.id AND t.locale = 'en'),
      (SELECT t.description FROM exercise_translations t
       WHERE t.exercise_id = m.id LIMIT 1)
    ) AS description,
    COALESCE(
      (SELECT t.form_tips FROM exercise_translations t
       WHERE t.exercise_id = m.id AND t.locale = p_locale),
      (SELECT t.form_tips FROM exercise_translations t
       WHERE t.exercise_id = m.id AND t.locale = 'en'),
      (SELECT t.form_tips FROM exercise_translations t
       WHERE t.exercise_id = m.id LIMIT 1)
    ) AS form_tips,
    m.image_start_url,
    m.image_end_url,
    m.user_id,
    m.deleted_at,
    m.created_at,
    m.slug
  FROM matches m
  ORDER BY m.score DESC,
           COALESCE(
             (SELECT t.name FROM exercise_translations t
              WHERE t.exercise_id = m.id AND t.locale = p_locale),
             (SELECT t.name FROM exercise_translations t
              WHERE t.exercise_id = m.id AND t.locale = 'en')
           ) ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_search_exercises_localized(
  TEXT, TEXT, UUID, TEXT, TEXT
) TO authenticated;


-- -----------------------------------------------------------------------------
-- 6.3 fn_insert_user_exercise
-- -----------------------------------------------------------------------------
-- Creates a user-owned exercise + its single translation row at the caller's
-- locale, atomically. Authorization: caller must be authenticated AND
-- `auth.uid() = p_user_id` (raises 42501 / insufficient_privilege otherwise).
--
-- Duplicate-name protection: replaces the dropped `idx_exercises_unique_name`
-- index. We check `EXISTS` against the user's existing translations at any
-- locale (case-insensitive), since the index it replaces was case-folded.
-- Raises SQLSTATE 23505 (unique_violation) so the existing Dart mapping in
-- ExerciseRepository (`PostgrestException.code == '23505'` →
-- `ValidationException`) keeps working without a code change.
--
-- Slug derivation: computed inline from p_name using the same regex as Dart
-- `exerciseSlug()` (`lib/core/l10n/exercise_l10n.dart:9-14`). Producing the
-- slug here means the BEFORE INSERT trigger does not need to re-derive from
-- `name` (which no longer exists post-Stage-4). The trigger now strictly
-- enforces "slug must be supplied"; we satisfy it explicitly.
--
-- Returns one row in the localized shape so the caller can update its cache
-- without a follow-up SELECT.
CREATE OR REPLACE FUNCTION public.fn_insert_user_exercise(
  p_user_id        UUID,
  p_locale         TEXT,
  p_name           TEXT,
  p_muscle_group   TEXT,
  p_equipment_type TEXT,
  p_description    TEXT DEFAULT NULL,
  p_form_tips      TEXT DEFAULT NULL
)
RETURNS TABLE (
  id              UUID,
  name            TEXT,
  muscle_group    muscle_group,
  equipment_type  equipment_type,
  is_default      BOOLEAN,
  description     TEXT,
  form_tips       TEXT,
  image_start_url TEXT,
  image_end_url   TEXT,
  user_id         UUID,
  deleted_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ,
  slug            TEXT
)
LANGUAGE plpgsql
SECURITY INVOKER
VOLATILE
AS $$
DECLARE
  v_new_id    UUID;
  v_new_slug  TEXT;
BEGIN
  -- Authorization. NULL auth.uid() means anonymous caller.
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'unauthorized: caller does not own p_user_id'
      USING ERRCODE = '42501';
  END IF;

  -- Duplicate-name check across the user's owned, non-deleted exercises in
  -- any locale. Replaces the dropped `idx_exercises_unique_name` functional
  -- index (which keyed on lower(name) for `exercises.name`).
  IF EXISTS (
    SELECT 1
    FROM exercise_translations t
    JOIN exercises e ON e.id = t.exercise_id
    WHERE e.user_id = p_user_id
      AND e.deleted_at IS NULL
      AND lower(t.name) = lower(p_name)
  ) THEN
    RAISE EXCEPTION 'duplicate exercise name for user: %', p_name
      USING ERRCODE = '23505';
  END IF;

  -- Compute slug inline (byte-for-byte parity with Dart `exerciseSlug()`):
  --   lower → replace non-alphanum with `_` → trim leading/trailing `_`.
  v_new_slug := trim(both '_' from regexp_replace(lower(p_name), '[^a-z0-9]+', '_', 'g'));

  -- A purely punctuation/whitespace name would slug to empty — reject loudly
  -- since the trigger would too, and a clearer message helps diagnosis.
  IF v_new_slug = '' THEN
    RAISE EXCEPTION 'exercise name produced empty slug: %', p_name
      USING ERRCODE = '22023';
  END IF;

  -- Insert exercise row. Cast text params to enum types — invalid values
  -- raise 22P02 (invalid_text_representation), surfaced to the caller.
  INSERT INTO exercises (
    user_id, is_default, muscle_group, equipment_type, slug
  )
  VALUES (
    p_user_id, false, p_muscle_group::muscle_group, p_equipment_type::equipment_type, v_new_slug
  )
  RETURNING exercises.id INTO v_new_id;

  -- Insert the single translation row. RLS policy
  -- `exercise_translations_insert_own` allows it because we just inserted
  -- the parent with `user_id = p_user_id = auth.uid()`.
  INSERT INTO exercise_translations (
    exercise_id, locale, name, description, form_tips
  )
  VALUES (
    v_new_id, p_locale, p_name, p_description, p_form_tips
  );

  -- Return the localized view. Single-row case: just call the list RPC with
  -- p_ids = ARRAY[v_new_id]. Avoids duplicating the cascade SELECT here.
  RETURN QUERY
  SELECT * FROM public.fn_exercises_localized(
    p_locale,
    p_user_id,
    NULL, NULL,
    ARRAY[v_new_id]::UUID[],
    'name'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_insert_user_exercise(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT
) TO authenticated;


-- -----------------------------------------------------------------------------
-- 6.4 fn_update_user_exercise
-- -----------------------------------------------------------------------------
-- Edits a user-owned exercise. Authorization: caller must own the row AND
-- the row must NOT be a default (defaults are immutable from the client).
--
-- Update semantics:
--   * muscle_group / equipment_type — updated only if their parameter is
--     non-NULL. NULL = "leave alone".
--   * name / description / form_tips — by spec §10 a user-created exercise
--     has exactly one `exercise_translations` row. We rewrite that single
--     row's text columns when the corresponding parameter is non-NULL.
--     The translation row's `locale` is preserved — editing does not
--     re-tag the row to the UI's current locale (matches the user's mental
--     model: "I typed this in pt; editing updates what I typed").
--   * Duplicate-name check fires when p_name is non-NULL and differs from
--     the row's current name (case-insensitive); same SQLSTATE 23505 path
--     as fn_insert_user_exercise.
--
-- Per spec §6.4 the function returns the localized view of the updated row;
-- since there is no `p_locale` parameter, the returned name/description/
-- form_tips come from the row's preserved translation locale. Documenting
-- here so callers don't expect a UI-locale-specific projection.
CREATE OR REPLACE FUNCTION public.fn_update_user_exercise(
  p_exercise_id    UUID,
  p_name           TEXT DEFAULT NULL,
  p_muscle_group   TEXT DEFAULT NULL,
  p_equipment_type TEXT DEFAULT NULL,
  p_description    TEXT DEFAULT NULL,
  p_form_tips      TEXT DEFAULT NULL
)
RETURNS TABLE (
  id              UUID,
  name            TEXT,
  muscle_group    muscle_group,
  equipment_type  equipment_type,
  is_default      BOOLEAN,
  description     TEXT,
  form_tips       TEXT,
  image_start_url TEXT,
  image_end_url   TEXT,
  user_id         UUID,
  deleted_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ,
  slug            TEXT
)
LANGUAGE plpgsql
SECURITY INVOKER
VOLATILE
AS $$
DECLARE
  v_owner_id   UUID;
  v_is_default BOOLEAN;
  v_locale     TEXT;
BEGIN
  -- Look up ownership + default flag in one shot. Single row by PK.
  SELECT e.user_id, e.is_default
    INTO v_owner_id, v_is_default
  FROM exercises e
  WHERE e.id = p_exercise_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'exercise not found: %', p_exercise_id
      USING ERRCODE = '42501';
  END IF;

  -- Authorization: caller must own AND target must not be a default.
  IF v_is_default OR v_owner_id IS NULL OR v_owner_id <> auth.uid() THEN
    RAISE EXCEPTION 'unauthorized: cannot edit default or non-owned exercise'
      USING ERRCODE = '42501';
  END IF;

  -- Locate the single translation row (§10 invariant: exactly one row per
  -- user-created exercise). Capture its locale so we update in place without
  -- changing the locale tag.
  SELECT t.locale INTO v_locale
  FROM exercise_translations t
  WHERE t.exercise_id = p_exercise_id
  LIMIT 1;

  IF v_locale IS NULL THEN
    RAISE EXCEPTION 'exercise has no translation row: %', p_exercise_id
      USING ERRCODE = '22023';
  END IF;

  -- Duplicate-name check. Only fires when p_name is non-NULL and does not
  -- match the current name (case-insensitive). Skipping the self-row keeps
  -- a no-op rename from spuriously raising 23505.
  IF p_name IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM exercise_translations t
      JOIN exercises e ON e.id = t.exercise_id
      WHERE e.user_id = v_owner_id
        AND e.deleted_at IS NULL
        AND e.id <> p_exercise_id
        AND lower(t.name) = lower(p_name)
    ) THEN
      RAISE EXCEPTION 'duplicate exercise name for user: %', p_name
        USING ERRCODE = '23505';
    END IF;
  END IF;

  -- Update metadata if any changed. COALESCE preserves the existing value
  -- when the parameter is NULL.
  UPDATE exercises e
  SET
    muscle_group   = COALESCE(p_muscle_group::muscle_group,   e.muscle_group),
    equipment_type = COALESCE(p_equipment_type::equipment_type, e.equipment_type)
  WHERE e.id = p_exercise_id;

  -- Update the single translation row in place. Each column updates only if
  -- its parameter is non-NULL.
  UPDATE exercise_translations t
  SET
    name        = COALESCE(p_name,        t.name),
    description = COALESCE(p_description, t.description),
    form_tips   = COALESCE(p_form_tips,   t.form_tips)
  WHERE t.exercise_id = p_exercise_id
    AND t.locale = v_locale;

  -- Return the localized view at the row's preserved locale.
  RETURN QUERY
  SELECT * FROM public.fn_exercises_localized(
    v_locale,
    v_owner_id,
    NULL, NULL,
    ARRAY[p_exercise_id]::UUID[],
    'name'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_update_user_exercise(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT
) TO authenticated;


-- =============================================================================
-- STEP C — Rewrite slug trigger to not reference `exercises.name`
-- =============================================================================
--
-- The original trigger from 00030 derived slug from NEW.name when slug was
-- NULL/empty. With name about to be dropped, that derivation is no longer
-- possible. Post-Stage-4 the only legitimate writer is fn_insert_user_exercise,
-- which always supplies an explicit slug. Direct INSERTs into `exercises`
-- without a slug are now a structural bug — the trigger raises loudly so the
-- caller fixes their code rather than silently inserting NULL (which would
-- fail the NOT NULL constraint anyway, just with a less actionable message).
--
-- CREATE OR REPLACE preserves the existing trigger binding from 00030; only
-- the function body changes.
CREATE OR REPLACE FUNCTION public.exercises_derive_slug()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.slug IS NULL OR NEW.slug = '' THEN
    RAISE EXCEPTION 'exercises.slug is required (Phase 15f Stage 4): callers must supply slug explicitly. Use fn_insert_user_exercise for user-created rows.'
      USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$$;


-- =============================================================================
-- STEP D — Drop legacy artifacts (constraints, index, columns)
-- =============================================================================

-- Drop the functional unique index on lower(name) — replaced by the
-- duplicate-name check inside fn_insert_user_exercise / fn_update_user_exercise.
DROP INDEX IF EXISTS public.idx_exercises_unique_name;

-- Drop the three CHECK constraints from 00021 — they reference the columns
-- about to be dropped. Equivalent length constraints already live on
-- `exercise_translations` (00031: name 1-120, description ≤2000, form_tips
-- ≤2000), which is now the canonical source of truth for these texts.
ALTER TABLE exercises
  DROP CONSTRAINT IF EXISTS valid_exercises_name_length,
  DROP CONSTRAINT IF EXISTS valid_exercises_description_length,
  DROP CONSTRAINT IF EXISTS valid_exercises_form_tips_length;

-- Drop the columns. After this point, the only place exercise display text
-- lives is `exercise_translations`. Reads must go through the four RPCs above.
ALTER TABLE exercises
  DROP COLUMN name,
  DROP COLUMN description,
  DROP COLUMN form_tips;


-- =============================================================================
-- STEP E — Hard sanity asserts
-- =============================================================================
--
-- These are migration-time invariants. If any fails the transaction aborts
-- and we don't ship a half-applied schema. The asserts are cheap (catalog
-- lookups) and run inside the BEGIN/COMMIT.

-- E1. Assert all four RPCs are present.
DO $$
DECLARE
  expected_fns TEXT[] := ARRAY[
    'fn_exercises_localized',
    'fn_search_exercises_localized',
    'fn_insert_user_exercise',
    'fn_update_user_exercise'
  ];
  fn TEXT;
BEGIN
  FOREACH fn IN ARRAY expected_fns LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = fn
    ) THEN
      RAISE EXCEPTION 'Stage 4 invariant violated: function public.% is missing', fn;
    END IF;
  END LOOP;
END
$$;

-- E2. Assert the dropped columns are gone from `exercises`. Anything still
-- referencing `name`/`description`/`form_tips` would fail catastrophically
-- at first query — better to fail at migration time.
DO $$
DECLARE
  bad_col TEXT;
BEGIN
  FOR bad_col IN
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'exercises'
      AND column_name IN ('name', 'description', 'form_tips')
  LOOP
    RAISE EXCEPTION 'Stage 4 invariant violated: exercises.% still exists', bad_col;
  END LOOP;
END
$$;

-- E3. Assert pg_trgm is present. The search RPC depends on it; a missing
-- extension would surface only at first search call.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm'
  ) THEN
    RAISE EXCEPTION 'Stage 4 invariant violated: pg_trgm extension is missing';
  END IF;
END
$$;

COMMIT;
