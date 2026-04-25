-- Fixture: pt translations missing (fails check_exercise_translation_coverage.sh).
--
-- Same two default exercises as fixture_complete.sql, but ONLY the `'en'`
-- translation block is included. The script must report `fixture_a` and
-- `fixture_b` as missing pt translations and exit nonzero.

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

-- pt translations intentionally absent.

COMMIT;
