-- Phase 15f Stage 1 — create `exercise_translations` table.
--
-- Stores per-locale display text for every exercise (default and user-created)
-- using the standard i18n translation-table pattern. EN and pt live side by
-- side with no privileged locale; future locales (es, fr, etc.) add rows only.
--
-- The (exercise_id, locale) primary key + FK CASCADE keeps translations
-- tightly bound to their parent exercise: deleting an exercise (hard delete)
-- wipes its translations automatically. Soft-delete on `exercises.deleted_at`
-- is handled at the SELECT policy layer below.
--
-- Length bounds match the input-length limits introduced in migration 00021
-- for the original `exercises` columns, so translations can't exceed the same
-- UX budgets.

BEGIN;

CREATE TABLE exercise_translations (
  exercise_id  UUID        NOT NULL
                           REFERENCES exercises(id) ON DELETE CASCADE,
  locale       TEXT        NOT NULL
                           CHECK (locale IN ('en', 'pt')),
  name         TEXT        NOT NULL
                           CHECK (char_length(name) BETWEEN 1 AND 120),
  description  TEXT        CHECK (description IS NULL
                                  OR char_length(description) <= 2000),
  form_tips    TEXT        CHECK (form_tips IS NULL
                                  OR char_length(form_tips) <= 2000),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (exercise_id, locale)
);

-- Locale-only scans (e.g. "how many pt translations exist?") and the hot path
-- "SELECT where locale = $1" benefit from this secondary index. The PK
-- already covers (exercise_id, locale) lookups.
CREATE INDEX exercise_translations_locale_idx
  ON exercise_translations (locale);

-- Reuse the shared `public.set_updated_at()` function defined in
-- `00023_create_subscriptions.sql`. Do NOT redefine here — a single canonical
-- implementation across the schema.
CREATE TRIGGER exercise_translations_set_updated_at
  BEFORE UPDATE ON exercise_translations
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE exercise_translations ENABLE ROW LEVEL SECURITY;

-- SELECT — default exercises are universally readable by authenticated users,
-- but only while the parent exercise is not soft-deleted.
CREATE POLICY exercise_translations_select_defaults
  ON exercise_translations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM exercises e
      WHERE e.id = exercise_translations.exercise_id
        AND e.is_default = true
        AND e.deleted_at IS NULL
    )
  );

-- SELECT — user-created exercises readable only by their owner.
-- Mirrors `exercises_select_own` parent visibility — soft-deleted custom
-- exercises do not leak translations.
CREATE POLICY exercise_translations_select_own
  ON exercise_translations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM exercises e
      WHERE e.id = exercise_translations.exercise_id
        AND e.user_id = auth.uid()
        AND e.deleted_at IS NULL
    )
  );

-- INSERT — caller must own the parent exercise. Seed/backfill migrations run
-- as the `postgres` role and bypass RLS, so default translations are written
-- without hitting these policies.
CREATE POLICY exercise_translations_insert_own
  ON exercise_translations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM exercises e
      WHERE e.id = exercise_translations.exercise_id
        AND e.user_id = auth.uid()
    )
  );

-- UPDATE — same ownership predicate on both sides to prevent re-homing a
-- translation to a row the caller doesn't own.
CREATE POLICY exercise_translations_update_own
  ON exercise_translations
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM exercises e
      WHERE e.id = exercise_translations.exercise_id
        AND e.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM exercises e
      WHERE e.id = exercise_translations.exercise_id
        AND e.user_id = auth.uid()
    )
  );

-- DELETE — explicit policy for direct deletes; account-delete path still
-- relies on the FK CASCADE from `exercises`.
CREATE POLICY exercise_translations_delete_own
  ON exercise_translations
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM exercises e
      WHERE e.id = exercise_translations.exercise_id
        AND e.user_id = auth.uid()
    )
  );

COMMIT;
