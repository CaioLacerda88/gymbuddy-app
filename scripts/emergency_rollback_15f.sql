-- Emergency rollback for Phase 15f cut-over. Run as superuser. See spec §16.
BEGIN;

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

-- Drop the trigger + function 00030 introduced. Pre-15f had neither. Once
-- slug column is dropped below, the function body's `NEW.slug := ...`
-- reference becomes invalid and any subsequent INSERT into exercises would
-- fail trigger execution. Removing both restores the genuine pre-15f state
-- and makes the rollback re-applyable from scratch.
DROP TRIGGER IF EXISTS exercises_derive_slug_trigger ON exercises;
DROP FUNCTION IF EXISTS public.exercises_derive_slug();

-- Drop the four 15f RPCs by full signature so this rollback survives the
-- introduction of any future overload sharing the same name. Signatures
-- match the GRANT EXECUTE / CREATE FUNCTION declarations in 00034.
DROP FUNCTION fn_exercises_localized(TEXT, UUID, TEXT, TEXT, UUID[], TEXT);
DROP FUNCTION fn_search_exercises_localized(TEXT, TEXT, UUID, TEXT, TEXT);
DROP FUNCTION fn_insert_user_exercise(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION fn_update_user_exercise(UUID, TEXT, TEXT, TEXT, TEXT, TEXT);

DROP TABLE exercise_translations CASCADE;
DROP INDEX exercises_slug_unique_default, exercises_slug_idx;
ALTER TABLE exercises DROP COLUMN slug;

-- Restore the legacy unique index + length CHECK constraints that 00034
-- STEP D dropped. Without these, the rolled-back schema silently allows
-- duplicate exercise names per user and accepts out-of-range text lengths
-- — the pre-15f invariants are not fully reinstated until both are back.
-- Definitions match the originals: index from 00006 (composite
-- user_id + LOWER(name) + muscle_group + equipment_type, scoped to
-- non-deleted rows), CHECK constraints from 00021 (name <=100,
-- description <=500, form_tips <=2000).
CREATE UNIQUE INDEX idx_exercises_unique_name
  ON exercises(user_id, LOWER(name), muscle_group, equipment_type)
  WHERE deleted_at IS NULL;

ALTER TABLE exercises
  ADD CONSTRAINT valid_exercises_name_length
    CHECK (char_length(name) <= 100),
  ADD CONSTRAINT valid_exercises_description_length
    CHECK (description IS NULL OR char_length(description) <= 500),
  ADD CONSTRAINT valid_exercises_form_tips_length
    CHECK (form_tips IS NULL OR char_length(form_tips) <= 2000);

COMMIT;
