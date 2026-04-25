-- Fixture: complete coverage (passes check_exercise_translation_coverage.sh).
--
-- Two new default exercises (`fixture_a`, `fixture_b`) inserted with the
-- `slug` column present in the column list, paired with both `'en'` and
-- `'pt'` rows in `exercise_translations`. Mirrors the canonical 00033 shape
-- (VALUES + JOIN exercises e ON e.slug = v.slug). This is the pattern every
-- future default-exercise migration must follow.

BEGIN;

INSERT INTO exercises (slug, name, is_default, muscle_group)
VALUES
  ('fixture_a', 'Fixture A', true, 'chest'),
  ('fixture_b', 'Fixture B', true, 'back');

INSERT INTO exercise_translations (exercise_id, locale, name, description, form_tips)
SELECT e.id, 'en', v.name, v.description, v.form_tips
FROM (VALUES
  ('fixture_a', 'Fixture A', 'EN description for A.', 'EN tips for A.'),
  ('fixture_b', 'Fixture B', 'EN description for B.', 'EN tips for B.')
) AS v(slug, name, description, form_tips)
JOIN exercises e ON e.slug = v.slug;

INSERT INTO exercise_translations (exercise_id, locale, name, description, form_tips)
SELECT e.id, 'pt', v.name, v.description, v.form_tips
FROM (VALUES
  ('fixture_a', 'Fixture A (pt)', 'Descrição em pt para A.', 'Dicas em pt para A.'),
  ('fixture_b', 'Fixture B (pt)', 'Descrição em pt para B.', 'Dicas em pt para B.')
) AS v(slug, name, description, form_tips)
JOIN exercises e ON e.slug = v.slug;

COMMIT;
