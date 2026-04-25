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

COMMIT;
