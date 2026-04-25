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
DROP FUNCTION fn_exercises_localized, fn_search_exercises_localized, fn_insert_user_exercise, fn_update_user_exercise;
DROP TABLE exercise_translations CASCADE;
DROP INDEX exercises_slug_unique_default, exercises_slug_idx;
ALTER TABLE exercises DROP COLUMN slug;

COMMIT;
