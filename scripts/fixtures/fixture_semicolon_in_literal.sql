-- Fixture: complete coverage with semicolon in string literals (regression test for index(buf, ';') fix).
--
-- Same complete-coverage shape as fixture_complete.sql, but the pt
-- description literals contain `;` characters mid-sentence. This is the
-- adversarial case for the awk statement-terminator state machine: with
-- the buggy `index(line, ";")` check, the buffer would be flushed as soon
-- as the line carrying the literal arrived (semicolon detected on that
-- line), even though the SQL statement itself had not terminated. The
-- fixed `index(buf, ";")` check still flushes only when a semicolon has
-- been observed in the accumulated buffer, but combined with the
-- single-quote-aware emit_explicit_pairs walker (which already skips
-- semicolons inside string literals when extracting the FIRST quoted
-- string per tuple), coverage parsing remains correct. The script must
-- still recognize this fixture as completely covered for both en and pt.

BEGIN;

INSERT INTO exercises (slug, name, is_default, muscle_group)
VALUES
  ('fixture_a', 'Fixture A', true, 'chest'),
  ('fixture_b', 'Fixture B', true, 'back');

INSERT INTO exercise_translations (exercise_id, locale, name, description, form_tips)
SELECT e.id, 'en', v.name, v.description, v.form_tips
FROM (VALUES
  ('fixture_a', 'Fixture A', 'EN description for A; with semicolon mid-sentence.', 'EN tips for A; semicolon in tips too.'),
  ('fixture_b', 'Fixture B', 'EN description for B; another semicolon literal.', 'EN tips for B; and one more here.')
) AS v(slug, name, description, form_tips)
JOIN exercises e ON e.slug = v.slug;

INSERT INTO exercise_translations (exercise_id, locale, name, description, form_tips)
SELECT e.id, 'pt', v.name, v.description, v.form_tips
FROM (VALUES
  ('fixture_a', 'Fixture A (pt)', 'Descrição em pt para A; com ponto-e-vírgula no meio.', 'Dicas em pt para A; e mais ponto-e-vírgula.'),
  ('fixture_b', 'Fixture B (pt)', 'Descrição em pt para B; outro literal com ;.', 'Dicas em pt para B; e mais um aqui.')
) AS v(slug, name, description, form_tips)
JOIN exercises e ON e.slug = v.slug;

COMMIT;
